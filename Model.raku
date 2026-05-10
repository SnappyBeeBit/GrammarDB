role GrammarDB::Model {
    has Str $.id is required;
    has Bool $!dirty = False;

    method is-dirty () { $!dirty }
    method mark-clean () { $!dirty = False }

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

class Account does GrammarDB::Model {
    has Str $!name;
    has Str $!email;

    method name()  is rw { self.auto-track($!name)  }
    method email() is rw { self.auto-track($!email) }

    method render () { "$!name|$!email" }
}

my $chaz = Account.new(id => "0001-cj");

$chaz.name = "Chaz Jarman"; 
$chaz.email = "chazjarman03@gmail.com";

say "Record: " ~ $chaz.render;
say "Dirty? " ~ $chaz.is-dirty;
