unit role GrammarDB::Model;
use GrammarDB::Utils;

has Str $.id is rw;
has Bool $.is-dirty is rw = False;

my %accessors-installed;

method mark-clean { $!is-dirty = False }
method mark-dirty { $!is-dirty = True  }

# Ensure the engine can check dirty status
method is-dirty { $!is-dirty }

method setup-accessors {
    my $class-id = self.^name;
    return if %accessors-installed{$class-id};
    %accessors-installed{$class-id} = True;
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
                    $attr.set_value(self, $attr.type ~~ Str ?? escape($val.Str) !! $val);
                    self.mark-dirty;
                }
            } else {
                my $raw = $attr.get_value(self) // "";
                return $attr.type ~~ Str ?? unescape($raw) !! $raw;
            }
        });
    }
}