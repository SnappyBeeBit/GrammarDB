
unit module GrammarDB::Engine;

our class GrammarDB::Engine {
    use GrammarDB::Metadata;
    has Str $.file is required;
    has $!grammar is required;
    has $!actions is required;
    has GrammarDB::Metadata $!metadata;
    has %!store;
    has %!offsets;
    has %!index-counts;
    has %!indices;

    method BUILD(:$grammar, :$actions, :$file!) {
        $!grammar = $grammar;
        $!file = $file;
        if $actions.can('new') {
            $!actions = $actions.new;
        }
        else {
            $!actions = $actions;
        }
        $!metadata = GrammarDB::Metadata.new(meta-path => $file ~ '.meta');
    }

    method load(Str $path = $.file) {
        my $content = $path.IO.slurp(:bin);
        my $pos = 0;
        for $content.decode('utf8').lines -> $line {
            my $from = $pos;
            $pos += $line.encode('utf8').elems + 1;  # +1 for newline
            next if $line.trim eq '';

            my $match = $!grammar.parse($line, :actions($!actions));
            unless $match && $match.made {
                warn "Malformed line at byte $from: $line";
                next;
            }
            my $obj = $match.made;
            self.store-object($obj, $from, $line.encode('utf8').elems);
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
        if %!index-counts{$attr} >= 10 && !$!metadata.is-indexed($attr) {
            self.build-index($attr);
            $!metadata.mark-indexed($attr);
            $!metadata.save-meta;
        }

        if %!indices{$attr}:exists {
            return %!indices{$attr}{$value} // [];
        }

        return %!store.values.grep({
            .WHAT ~~ $class
            && .can($attr)
            && ."$attr"() eq $value
        });
    }

    method commit() {
        my $fh = $.file.IO.open(:r+ :bin);

        for %!store.values.grep(*.is-dirty) -> $obj {
            my $rendered = $obj.render;
            my $bytes    = $rendered.encode('utf8').elems;

            if %!offsets{$obj.id}:exists {
                my %meta = %!offsets{$obj.id};
                if $bytes == %meta<length> {
                    $fh.seek(%meta<from>, 0);
                    $fh.print($rendered);
                    $obj.mark-clean;
                    next;
                }

                $fh.seek(%meta<from>, 0);
                my $tomb = '#' ~ ' ' x (%meta<length> - 1);
                $fh.print($tomb);
            }

            $fh.seek(0, 2);
            my $from = $fh.tell;
            $fh.print($rendered ~ "\n");
            %!offsets{$obj.id} = { from => $from, length => $bytes };
            $obj.mark-clean;
        }
        return self;
    }

    method build-index($attr) {
        my %index;
        for %!store.values -> $obj {
            next unless $obj.can($attr);
            my $key = ."$attr"();
            %index{$key} //= [];
            push %index{$key}, $obj;
        }
        %!indices{$attr} = %index;
    }

    method store-object($obj, Int $from, Int $length) {
        %!store{$obj.id}    = $obj;
        %!offsets{$obj.id} = { from => $from, length => $length };
        $obj.mark-clean if $obj.can('mark-clean');
    }
}
