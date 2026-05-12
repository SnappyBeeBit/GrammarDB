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

#Tweak: Modify the Engine after initialization to set up actions and metadata
submethod TWEAK(:$grammar, :$actions) {
    # We just need to handle the logic for actions and metadata
    if $actions.can('new') {
        $!actions = $actions.new;
    }
    else {
        $!actions = $actions;
    }
    $!metadata = GrammarDB::Metadata.new(meta-path => $!file ~ '.meta');
}
#Read: Load all the data line by line (lazliy) from the database file into the store
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
#Read: Store an existing object and its offset metadata
method store-object(GrammarDB::Model $obj, Int $from, Int $length) {
    %!store{$obj.id.Str} = $obj;
    %!offsets{$obj.id.Str} = { from => $from, length => $length };
    $obj.mark-clean;
}

#Create: Insert a new dirty object into the store (no offset metadata yet)
method insert(GrammarDB::Model $obj) {
    %!store{$obj.id.Str} = $obj;
    $obj.mark-dirty;
    return self;
}

#Read: Find objects by class and attribute value, with auto-indexing
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

#Update: commit changes to the file handling new records, updates and tombstoning
method commit() {
    #First step find all dirty grammar db models
    my @to-process = %!store.values.grep({ $_ ~~ GrammarDB::Model && .is-dirty }).list;
    return unless @to-process;

    my $fh = $.file.IO.open(:update, :bin);

    for @to-process -> $obj {
        my $id       = $obj.id.Str;
        my $encoded  = $obj.render.encode('utf8');
        my $new-len  = $encoded.elems;

        #Does it exist within the file already
        if %!offsets{$id}:exists {
            #capture the metadata for the record
            my $meta    = %!offsets{$id};
            if $meta ~~ Hash {
                #pull data from the metadata 
                my Int $at     = $meta{'from'} // die "No 'from' key";
                my Int $old-len = $meta{'length'} // die "No 'length' key";

                #Did the record fit within the old length?
                if $new-len == $old-len {
                    $fh.seek($at);
                    $fh.write($encoded);
                } else {
                    # Tombstone - write # followed by spaces to fill the old length
                    $fh.seek($at);
                    my Blob $tombstone = "#".encode('utf8') ~ Blob.new(32 xx ($old-len - 1));
                    $fh.write($tombstone);
                    
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
#Read: index builder that creates a mapping of attribute values to objects for fast lookup
method build-index(Str $attr) {
    my  Array %index;
    for %!store.values -> $obj {
        next unless $obj.can($attr);
        my $key = $obj."$attr"();
        %index{$key} //= [];
        push %index{$key}, $obj;
    }
    %!indices{$attr} = %index;
}

#Create: Append a record by finding the end of a file and writing there, then updating offsets
method !append-record($fh, $obj, $encoded) {
    $fh.seek(0, SeekType::SeekFromEnd);
    my Int $from = $fh.tell.Int;
    $fh.write($encoded ~ "\n".encode('utf8'));
    %!offsets{$obj.id.Str} = { from => $from, length => $encoded.elems.Int };
}

method indices() {
    return %!indices;
}