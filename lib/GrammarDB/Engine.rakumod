unit class GrammarDB::Engine;
use GrammarDB::Metadata;

has Str $.file is required;
has $!grammar  is required is built; 
has $!actions  is required is built; 

has GrammarDB::Metadata $!metadata;

has %!store;
has %!offsets;
has %!index-counts;
has %!indices;

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
    my $pos = 0;
    
    for $content.decode('utf8').lines -> $line {
        my $from = $pos;
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
    for $!metadata.indices.keys -> $attr {
        self.build-index($attr);
    }
    return self;
}

method insert($obj) {
    %!store{$obj.id} = $obj;
    $obj.mark-dirty if $obj.can('mark-dirty');
    return self;
}

method find-by($class, $attr, $value) {
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
    my $fh = $.file.IO.open(:r+ :bin);

    for %!store.values -> $obj {
        next unless $obj.can('is-dirty') && $obj.is-dirty;

        my $id       = $obj.id.Str;
        my $rendered = $obj.render;
        my $encoded  = $rendered.encode('utf8');
        my $new-len  = $encoded.elems;

        # Use 'with' to ensure we have an entry and alias it to $_
        with %!offsets{$id} -> $meta-raw {
            # This is the "Nuclear Fix": 
            # We destructure the hash/pair into raw local variables.
            my Int $at     = $meta-raw<from>.Int;
            my Int $old-len = $meta-raw<length>.Int;

            if $new-len == $old-len {
                $fh.seek($at, 0);
                $fh.write($encoded);
            } else {
                # Tombstone
                $fh.seek($at, 0);
                $fh.write("#".encode('utf8') ~ (" ".encode('utf8') x ($old-len - 1)));
                
                # Use the private helper
                self!append-record($fh, $obj, $encoded);
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

method build-index($attr) {
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
    # Use a Map here; it's more rigid than a Hash
    %!offsets{$obj.id.Str} = Map.new((from => $from, length => $length));
    $obj.mark-clean if $obj.can('mark-clean');
}

# Private helper to ensure clean offset storage
method !append-record($fh, $obj, $encoded) {
    $fh.seek(0, 2);
    my $from = $fh.tell;
    $fh.write($encoded ~ "\n".encode('utf8'));
    # Update offsets with forced Ints
    %!offsets{$obj.id.Str} = { from => $from.Int, length => $encoded.elems.Int };
}