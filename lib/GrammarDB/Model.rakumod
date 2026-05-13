unit role GrammarDB::Model;
use GrammarDB::Utils;

has Str $.id is rw;
has Bool $.is-dirty is rw = False;

method mark-clean { $!is-dirty = False }
method mark-dirty { $!is-dirty = True  }

# Ensure the engine can check dirty status
method is-dirty { $!is-dirty }

method setup-accessors {
    for self.^attributes -> $attr {
        next unless $attr.^can('validation-type');
        
        my $rule = $attr.validation-type;
        my $name = $attr.name.substr(2); # strip '$!'

        self.^add_method($name, method ($val?) {
            if $val.defined {
                my $ok = do if $rule ~~ Callable { $rule($val) }
                else {
                    given $rule {
                        when 'no-whitespace'       { !($val ~~ /\s | <:Cc>/) }
                        when 'contains-whitespace' { !($val ~~ /<:Cc - [\n]>/) }
                        default                    { True }
                    }
                }
                if $ok {
                    $attr.set_value(self, escape($val.Str));
                    self.mark-dirty;
                }
            } else {
                return unescape($attr.get_value(self) // "");
            }
        });
    }
}