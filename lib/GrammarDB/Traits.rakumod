unit module GrammarDB::Traits;

multi sub trait_mod:<is>(Attribute $attr, :$validates!) is export {
    $attr does role { has $.validation-type is rw };
    $attr.validation-type = $validates;
}

# gdb-field is handled via validates<gdb-field> — no separate multi needed.