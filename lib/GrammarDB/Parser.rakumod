grammar GrammarDB::Grammar {
    rule TOP { ^ <record> $ }
    rule record { <v2> | <v1> }

    # Basic versioned record shapes. Application grammars may extend or override.
    rule v2 { <record-v2> }
    rule v1 { <record-v1> }

    rule record-v2 { <id> ':' <type> ':' <value> }
    rule record-v1 { <id> ':' <type> }

    rule type { <int-type> | <varchar-type> | <date-type> | <boolean-type> }

    rule int-type { 'INT' }
    rule varchar-type { 'VARCHAR' <ws>? '(' <digits> ')' }
    rule date-type { 'DATE' }
    rule boolean-type { 'BOOLEAN' | 'BOOL' }

    rule id { <alpha> <alnum>* }
    rule value { <quoted-string> | <unquoted-string> }

    token quoted-string { '"' <-[">]>* '"' }
    token unquoted-string { <-[\s]>+ }
    token digits { \d+ }
    token alpha { [a..zA..Z] }
    token alnum { [a..zA..Z0..9] }
}

role GrammarDB::Action {
    method record-v2($/) {
        make {
            version => 2,
            id      => $<id>.made,
            type    => $<type>.made,
            value   => ~$<value>
        };
    }

    method record-v1($/) {
        make {
            version => 1,
            id      => $<id>.made,
            type    => $<type>.made,
        };
    }

    method int-type($/) {
        make { name => 'INT' };
    }

    method varchar-type($/) {
        make {
            name   => 'VARCHAR',
            length => +$<digits>.Str
        };
    }

    method date-type($/) {
        make { name => 'DATE' };
    }

    method boolean-type($/) {
        make { name => 'BOOLEAN' };
    }

    method id($/) {
        make ~$/.Str;
    }

    method value($/) {
        make ~$/.Str;
    }
}
