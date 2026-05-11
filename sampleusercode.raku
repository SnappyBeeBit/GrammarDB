use GrammarDB::Model;

class Vendor does GrammarDB::Model {
    has Str $!name;
    has Str $!email;

    method name()  is rw { self.auto-track($!name)  }
    method email() is rw { self.auto-track($!email) }

    method render() { "VND|{self.id}|$!name|$!email" }
}

class Product does GrammarDB::Model {
    has Str $!name;
    has Rat $!price;
    has Str $!category;

    method name()     is rw { self.auto-track($!name)     }
    method price()    is rw { self.auto-track($!price)    }
    method category() is rw { self.auto-track($!category) }

    method render() { "PRD|{self.id}|$!name|$!price|$!category" }
}

class Listing does GrammarDB::Model {
    has Str $.vendor-id;
    has Str $.product-id;
    has Int $!qty;

    method qty() is rw { self.auto-track($!qty) }

    method render() { "LST|{self.id}|$.vendor-id|$.product-id|$!qty" }
}


use MarketplaceModels;

grammar MarketplaceGrammar {
    token TOP { <vendor> | <product> | <listing> }

    token vendor  { 'VND|' <id> '|' <name=(.*?)>  '|' <email=(.*)> }
    token product { 'PRD|' <id> '|' <name=(.*?)>  '|' <price=(.*?)> '|' <cat=(.*)> }
    token listing { 'LST|' <id> '|' <v_id=(.*?)> '|' <p_id=(.*?)> '|' <qty=(.*)> }
    
    token id { \w+ [ \- \w+ ]* }
}

class MarketplaceActions {
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

use lib 'lib';
use GrammarDB::Engine;
use MarketplaceModels;
use MarketplaceGrammar;

# 1. Initialize the Engine
my $db = GrammarDB::Engine.new(
    file    => "marketplace.gdb",
    grammar => MarketplaceGrammar,
    actions => MarketplaceActions
);

# 2. Load the data (Line-by-line parsing happens here)
$db.load;

# 3. Query: Find all Software products
# (If this is the 10th time, the engine will automatically index 'category')
my @software = $db.find-by(Product, category => "Software");

say "--- Software Catalog ---";
for @software -> $p {
    say "{$p.id}: {$p.name} - \${$p.price}";
}

# 4. Update: The 'Proxy' magic at work
if @software -> $item {
    say "Price update for {$item.name}...";
    
    # This assignment automatically triggers $item.is-dirty = True
    $item.price = 14.99; 
}

# 5. Create: Adding a new listing
my $new-listing = Listing.new(
    id         => "LST-999",
    vendor-id  => "VND-001",
    product-id => "PRD-123",
    qty        => 50
);
$db.insert($new-listing);

# 6. Commit: The 'Surgical Update'
# The engine scans for dirty objects and patches the file
$db.commit;

say "Marketplace state synchronized to disk.";