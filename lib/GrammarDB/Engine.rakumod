unit class GrammarDB::Engine;
use GrammarDB::Metadata;
use GrammarDB::Model;

has Str $.file is required;
has $!grammar  is required is built; 
has $!actions  is required is built; 

has GrammarDB::Metadata $!metadata;

has %!store of Mu;                           # Maps object IDs to objects
has %!offsets of Hash;                       # Maps object IDs to {from=>Int, length=>Int}
has %!index-counts of Int;                   # Tracks lookup counts per attribute
has %!indices of Hash[Array];                # Maps attribute=>value=>Array of objects

submethod TWEAK(:$grammar, :$actions) {
    if $actions.can('new') {
        $!actions = $actions.new;
    }
    else {
        $!actions = $actions;
    }
    $!metadata = GrammarDB::Metadata.new(meta-path => $!file ~ '.meta');
}

method load(Str $path = $.file) {
    return self unless $path.IO.e;

    my Int $pos = 0;
    for $path.IO.lines -> Str $line {
        my Int $from = $pos;
        my $encoded = $line.encode('utf8');
        
        $pos += $encoded.elems + 1; 

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

method store-object(GrammarDB::Model $obj, Int $from, Int $length) {
    %!store{$obj.id.Str} = $obj;
    %!offsets{$obj.id.Str} = { from => $from, length => $length };
    # Rely on the Model's internal state management
    $obj.mark-clean;
}

method insert(GrammarDB::Model $obj) {
    %!store{$obj.id.Str} = $obj;
    # Ensure new objects are caught by the next commit
    $obj.mark-dirty;
    return self;
}

method find-by($class, Str $attr, Str $value) {
    %!index-counts{$attr} //= 0;
    %!index-counts{$attr}++;
    
    if %!index-counts{$attr} >= 10 && !$!metadata.is-indexed($attr) {
        self.build-index($attr);
        $!metadata.mark-indexed($attr);
        $!metadata.save-meta;
    }

    if %!indices{$attr}:exists {
        return %!indices{$attr}{$value} // [];
    }

    # Use the dynamic accessor (calling it with no args acts as a getter)
    return %!store.values.grep({
        .WHAT ~~ $class && .can($attr) && ."$attr"() eq $value
    });
}

method commit() {
    # Find all objects that do the Model role and are marked dirty
    my @to-process = %!store.values.grep({ $_ ~~ GrammarDB::Model && .is-dirty }).list;
    return unless @to-process;

    my $fh = $.file.IO.open(:update, :bin);

    for @to-process -> $obj {
        my $id       = $obj.id.Str;
        my $encoded  = $obj.render.encode('utf8');
        my $new-len  = $encoded.elems;

        if %!offsets{$id}:exists {
            my $meta = %!offsets{$id};
            if $meta ~~ Hash {
                my Int $at      = $meta{'from'};
                my Int $old-len = $meta{'length'};

                if $new-len == $old-len {
                    $fh.seek($at);
                    $fh.write($encoded);
                } else {
                    $fh.seek($at);
                    my Blob $tombstone = "#".encode('utf8') ~ Blob.new(32 xx ($old-len - 1));
                    $fh.write($tombstone);
                    self!append-record($fh, $obj, $encoded);
                }
            }
        } 
        else {
            self!append-record($fh, $obj, $encoded);
        }
        $obj.mark-clean;
    }
    $fh.close;
    return self;
}

method build-index(Str $attr) {
    my Array %index;
    for %!store.values -> $obj {
        # Check for the dynamic accessor generated in Model's setup-accessors
        next unless $obj.can($attr);
        my $key = $obj."$attr"();
        %index{$key} //= [];
        push %index{$key}, $obj;
    }
    %!indices{$attr} = %index;
}

method !append-record($fh, $obj, $encoded) {
    $fh.seek(0, SeekType::SeekFromEnd);
    my Int $from = $fh.tell.Int;
    $fh.write($encoded ~ "\n".encode('utf8'));
    %!offsets{$obj.id.Str} = { from => $from, length => $encoded.elems.Int };
}

method indices() {
    return %!indices;
}