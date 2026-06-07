use lib 'lib';
use GrammarDB::Engine;
use lib 'examples';
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
my @software = $db.find-by(Product, 'category', 'Software');

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
