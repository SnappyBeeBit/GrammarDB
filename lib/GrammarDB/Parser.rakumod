unit module GrammarDB::Parser;
our grammar Grammar {
    token TOP { ^ <record> $ }
    token record { <v2> | <v1> }

    token v2 { <record-v2> }
    token v1 { <record-v1> }

    token record-v2 { <id> ':' <type> ':' <value> }
    token record-v1 { <id> ':' <type> }

    token type { <int-type> | <varchar-type> | <date-type> | <boolean-type> }

    token int-type     { 'INT' }
    token varchar-type { 'VARCHAR' <.ws>? '(' <digits> ')' }
    token date-type    { 'DATE' }
    token boolean-type { 'BOOLEAN' | 'BOOL' }

    token id    { <[a..zA..Z]> <[a..zA..Z0..9]>* }
    token value { <quoted-string> | <unquoted-string> }

    token quoted-string   { '"' <-[">]>* '"' }
    token unquoted-string { <-[\s:]>+ } # Added : to the exclusion list
    token digits { \d+ }
}

our role Action {
    method TOP($/)    { make $<record>.made }
    method record($/) { make ($<v2> // $<v1>).made }
    method v2($/)     { make $<record-v2>.made }
    method v1($/)     { make $<record-v1>.made }
    
    method type($/) { 
        make ($<int-type> // $<varchar-type> // $<date-type> // $<boolean-type>).made 
    }

    method record-v2($/) {
        make {
            version => 2,
            id      => $<id>.made,
            type    => $<type>.made,
            value   => $<value>.made
        };
    }

    method int-type($/)     { make { name => 'INT' }; }
    method date-type($/)    { make { name => 'DATE' }; }
    method boolean-type($/) { make { name => 'BOOLEAN' }; }
    method varchar-type($/) { 
        make { name => 'VARCHAR', length => +$<digits>.Str }; 
    }

    method id($/)    { make ~$/; }
    method value($/) { make ~$/; }
}


