unit module MarketplaceModels;

use GrammarDB::Model;
use GrammarDB::Traits;

class Vendor does GrammarDB::Model is export {
    has Str $!name     is built is validates<gdb-field>;
    has Str $!email    is built is validates<gdb-field>;

    submethod TWEAK { self.setup-accessors }
    method render() { "VND|{self.id}|$!name|$!email" }
}

class Product does GrammarDB::Model is export {
    has Str $!name     is built is validates<gdb-field>;
    has Rat $!price    is built is validates<gdb-field>;
    has Str $!category is built is validates<gdb-field>;

    submethod TWEAK { self.setup-accessors }
    method render() { "PRD|{self.id}|$!name|$!price|$!category" }
}

class Listing does GrammarDB::Model is export {
    has Str $!vendor-id  is built is validates<gdb-field>;
    has Str $!product-id is built is validates<gdb-field>;
    has Int $!qty        is built is validates<gdb-field>;

    submethod TWEAK { self.setup-accessors }
    method render() { "LST|{self.id}|$!vendor-id|$!product-id|$!qty" }
}
