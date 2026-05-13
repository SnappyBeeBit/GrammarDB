unit module GrammarDB::Traits;

multi sub trait_mod:<is>(Attribute $attr, :$validates!) is export {
    $attr does role { has $.validation-type = $validates };
}

multi sub trait_mod:<is>(Attribute $attr, :$gdb-field!) is export {
    $attr does role { has $.validation-type = 'gdb-field' };
}