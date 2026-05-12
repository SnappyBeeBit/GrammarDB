unit role GrammarDB::Model;

has Str $.id is required;
has Bool $!dirty = False;

method is-dirty (--> Bool) { $!dirty }
method mark-clean (--> Bool) { $!dirty = False; $!dirty }
method mark-dirty (--> Bool) { $!dirty = True; $!dirty }

method auto-track(\var) is rw {
    Proxy.new(
        FETCH => -> $ { var },
        STORE => -> $, $val {
            var = $val;
            $!dirty = True;
        }
    );
}
