unit module GrammarDB::Utils;

my $DANGER-ZONE = rx/ <[ : \n \\ \| ]> | ^ '#' /;

sub escape(Str $val is copy, :@custom) is export {
    return "" unless $val.defined;

    my $target = @custom ?? rx/ <{ @custom }> / !! $DANGER-ZONE;

    $val.subst($target, -> $m {
        given $m.Str {
            when "\n" { '\n' }
            when '#'  { $m.pos == 0 ?? '\#' !! '#' }
            when '|'  { '||' }
            default   { '\\' ~ $_ }
        }
    }, :g);
}

sub unescape(Str $val is copy) is export {
    return "" unless $val.defined;
    # First unescape pipes
    $val .= subst('||', '|', :g);
    # Then handle backslash escapes
    $val.subst(/ '\\' (.) /, -> $m {
        given $m[0].Str {
            when 'n' { "\n" }
            default  { $_ }
        }
    }, :g);
}