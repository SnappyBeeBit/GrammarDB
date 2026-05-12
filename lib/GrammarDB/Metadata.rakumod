unit class GrammarDB::Metadata;
has Str $.meta-path;
has %!indices of Hash;                 # Maps attribute names to empty hashes
has %!search-counts of Int;            # Tracks search count per attribute

method load-meta(--> GrammarDB::Metadata) {
    if $.meta-path.IO.e {
        for $.meta-path.IO.lines -> Str $line {
            if $line ~~ /^ 'index:' $<attr>=(.*) $/ {
                %!indices{$<attr>.Str} = {};
            }
        }
    }
    return self;
}

method save-meta(--> GrammarDB::Metadata) {
    my Str $content = %!indices.keys.map({ "index:$_" }).join("\n");
    $.meta-path.IO.spurt($content);
    return self;
}

method is-indexed(Str $attr --> Bool) {
    %!indices{$attr}:exists;
}

method mark-indexed(Str $attr) {
    %!indices{$attr} = {};
}

method indices(--> Hash) {
    %!indices;
}