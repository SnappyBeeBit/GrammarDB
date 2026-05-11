role GrammarDB::Model {
    has Str $.id is required;
    has Bool $!dirty = False;

    method is-dirty () { $!dirty }
    method mark-clean () { $!dirty = False }
    method mark-dirty () { $!dirty = True }

    method auto-track(\var) is rw {
        Proxy.new(
            FETCH => -> $ { var },
            STORE => -> $, $val {
                var = $val;
                $!dirty = True;
            }
        );
    }
}
