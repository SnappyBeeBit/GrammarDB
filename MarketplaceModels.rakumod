unit module MarketplaceModels;

use GrammarDB::Model;

class Vendor does GrammarDB::Model is export {
    has Str $.name;
    has Str $.email;

    method render() { "VND|{self.id}|$.name|$.email" }
}

class Product does GrammarDB::Model is export {
    has Str $.name;
    has Rat $.price;
    has Str $.category;

    method render() { "PRD|{self.id}|$.name|$.price|$.category" }
}

class Listing does GrammarDB::Model is export {
    has Str $.vendor-id;
    has Str $.product-id;
    has Int $.qty;

    method render() { "LST|{self.id}|$.vendor-id|$.product-id|$.qty" }
}
