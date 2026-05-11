unit class GrammarDB::Metadata;
has Str $.meta-path;
has %!indices;
has %!search-counts;

method load-meta() {
    if $.meta-path.IO.e {
        for $.meta-path.IO.lines -> $line {
            if $line ~~ /^ 'index:' $<attr>=(.*) $/ {
                %!indices{$<attr>.Str} = {};
            }
        }
    }
    return self;
}

method save-meta() {
    my $content = %!indices.keys.map({ "index:$_" }).join("\n");
    $.meta-path.IO.spurt($content);
    return self;
}

method is-indexed($attr) {
    %!indices{$attr}:exists;
}

method mark-indexed($attr) {
    %!indices{$attr} = {};
}

method indices() {
    %!indices;
}