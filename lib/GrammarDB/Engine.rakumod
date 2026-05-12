unit class GrammarDB::Engine;
use GrammarDB::Metadata;

has Str $.file is required;
has $!grammar  is required is built; 
has $!actions  is required is built; 

has GrammarDB::Metadata $!metadata;

has %!store of Mu;                           # Maps object IDs to objects
has %!offsets of Hash;                       # Maps object IDs to {from=>Int, length=>Int}
has %!index-counts of Int;                   # Tracks lookup counts per attribute
has %!indices of Hash[Array];                # Maps attribute=>value=>Array of objects

submethod TWEAK(:$grammar, :$actions) {
    # Attributes like $!file and $!grammar are already set by Raku here!
    
    # We just need to handle the logic for actions and metadata
    if $actions.can('new') {
        $!actions = $actions.new;
    }
    else {
        $!actions = $actions;
    }

    # Use $!file (the private attribute) because the object is still being built
    $!metadata = GrammarDB::Metadata.new(meta-path => $!file ~ '.meta');
}

method load(Str $path = $.file) {
    return self unless $path.IO.e;
    my $content = $path.IO.slurp(:bin);
    my Int $pos = 0;
    Model 
    for $content.decode('utf8').lines -> Str $line {
        my Int $from = $pos;
        my $encoded = $line.encode('utf8');
        $pos += $encoded.elems + 1; # +1 for newline
        
        next if $line.trim eq '' || $line.starts-with('#');

        my $match = $!grammar.parse($line, :actions($!actions));
        if $match && $match.made {
            self.store-object($match.made, $from, $encoded.elems);
        } else {
            warn "Malformed line at byte $from: $line";
        }
    }
    
    $!metadata.load-meta;
    for $!metadata.indices.keys -> Str $attr {
        self.build-index($attr);
    }
    return self;
}

method insert($obj) {
    %!store{$obj.id} = $obj;
    $obj.mark-dirty if $obj.can('mark-dirty');
    return self;
}

method find-by($class, Str $attr, Str $value) {
    %!index-counts{$attr} //= 0;
    %!index-counts{$attr}++;
    
    # Auto-index after 10 lookups
    if %!index-counts{$attr} >= 10 && !$!metadata.is-indexed($attr) {
        self.build-index($attr);
        $!metadata.mark-indexed($attr);
        $!metadata.save-meta;
    }

    if %!indices{$attr}:exists {
        return %!indices{$attr}{$value} // [];
    }

    return %!store.values.grep({
        .WHAT ~~ $class && .can($attr) && ."$attr"() eq $value
    });
}

method commit() {
    my $fh = $.file.IO.open(:update, :bin);

    for %!store.values -> $obj {
        next unless $obj.can('is-dirty') && $obj.is-dirty;

        my $id       = $obj.id.Str;
        my $rendered = $obj.render;
        my $encoded  = $rendered.encode('utf8');
        my $new-len  = $encoded.elems;

        if %!offsets{$id}:exists {
            my $meta    = %!offsets{$id};
            if $meta ~~ Hash {
                my Int $at     = $meta{'from'} // die "No 'from' key";
                my Int $old-len = $meta{'length'} // die "No 'length' key";

                if $new-len == $old-len {
                    $fh.seek($at);
                    $fh.write($encoded);
                } else {
                    # Tombstone - write # followed by spaces to fill the old length
                    $fh.seek($at);
                    my Blob $tombstone = "#".encode('utf8') ~ Blob.new(32 xx ($old-len - 1));
                    $fh.write($tombstone);
                    
                    # Use the private helper
                    self!append-record($fh, $obj, $encoded);
                }
            } else {
                die "Expected Hash but got { $meta.gist }";
            }
        } 
        else {
            # Offset didn't exist, just append
            self!append-record($fh, $obj, $encoded);
        }
        $obj.mark-clean;
    }
    $fh.close;
    return self;
}

method build-index(Str $attr) {
    my %index;
    for %!store.values -> $obj {
        next unless $obj.can($attr);
        my $key = $obj."$attr"();
        %index{$key} //= [];
        push %index{$key}, $obj;
    }
    %!indices{$attr} = %index;
}

method store-object($obj, Int $from, Int $length) {
    %!store{$obj.id.Str} = $obj;
    # Store as a regular Hash for consistent access
    %!offsets{$obj.id.Str} = { from => $from, length => $length };
    $obj.mark-clean if $obj.can('mark-clean');
}

# Private helper to ensure clean offset storage
method !append-record($fh, $obj, $encoded) {
    $fh.seek(0, SeekType::SeekFromEnd);
    my Int $from = $fh.tell.Int;
    $fh.write($encoded ~ "\n".encode('utf8'));
    # Update offsets with forced Ints
    %!offsets{$obj.id.Str} = { from => $from, length => $encoded.elems.Int };
}