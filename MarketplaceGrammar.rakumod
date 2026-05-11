use GrammarDB::Parser;
use MarketplaceModels;

grammar MarketplaceGrammar is export {
    token TOP { <vendor> | <product> | <listing> }

    token vendor  { 'VND|' <id> '|' <name> '|' <email> }
    token product { 'PRD|' <id> '|' <name> '|' <price> '|' <cat> }
    token listing { 'LST|' <id> '|' <v_id> '|' <p_id> '|' <qty> }

    token id { \w+ [ \- \w+ ]* }
    token name { <-[|]>+ }
    token email { <-[\n]>+ }
    token price { <-[|]>+ }
    token cat { <-[|]>+ }
    token v_id { <-[|]>+ }
    token p_id { <-[|]>+ }
    token qty { <-[\n]>+ }
}

class MarketplaceActions does GrammarDB::Action is export {
    method TOP($/) { make $/<vendor>.made // $/<product>.made // $/<listing>.made }
    method vendor($/)  { make Vendor.new(id => ~$<id>, name => ~$<name>, email => ~$<email>) }
    method product($/) { make Product.new(id => ~$<id>, name => ~$<name>, price => +$<price>, category => ~$<cat>) }
    method listing($/) { 
        make Listing.new(
            id         => ~$<id>, 
            vendor-id  => ~$<v_id>, 
            product-id => ~$<p_id>, 
            qty        => +$<qty>
        ) 
    }
}

