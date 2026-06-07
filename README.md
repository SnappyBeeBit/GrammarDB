# GrammarDB

A Raku-native, language-oriented database engine that uses Grammars as schemas and Raku objects as interfaces.

```raku
use GrammarDB::Engine;
use GrammarDB::Model;

# Grammar defines the on-disk format
grammar MySchema {
    token TOP { <user> }
    token user { 'USR|' <id> '|' <name> '|' <email> }
}

# Model defines the in-memory object
class User does GrammarDB::Model {
    has $!name  is built is validates<no-whitespace>;
    has $!email is built is validates<no-whitespace>;
    submethod TWEAK { self.setup-accessors }
    method render() { "USR|{self.id}|{self.name}|{self.email}" }
}

# Engine ties them together
my $db = GrammarDB::Engine.new(
    file    => 'data.gdb',
    grammar => MySchema,
    actions => MyActions
);
$db.load;
$db.insert(User.new(id => 'u1', name => 'Alice', email => 'a@b.com'));
$db.commit;
```

## Installation

```bash
zef install https://github.com/SnappyBeeBit/GrammarDB.git
```

Or from a local clone:

```bash
git clone https://github.com/SnappyBeeBit/GrammarDB.git
cd GrammarDB
zef install .
```

## Architecture

### Grammar-as-Schema

Data files are plain text. A Raku Grammar defines every byte: tokens describe field delimiters, record separators, and type markers. Multiple schema versions coexist via ordered alternation (`<v2> | <v1>`).

### Raku Objects as Interface

Model classes consume the `GrammarDB::Model` role and receive dirty-tracking, auto-generated validated accessors, and rendering. Changes are detected automatically — no manual `mark-dirty()` calls needed.

### Surgical Updates

`commit()` performs byte-level in-place edits using `seek` + `write`. If a record grows, a tombstone (`#`) marks the old location and the new version is appended. Full rewrites are avoided.

### Lazy Indexing

The engine tracks per-attribute lookup frequency. After 10 lookups on the same attribute, an in-memory hash index is automatically built. Index intent is persisted in a `.gdb.meta` sidecar file.

## Modules

| Module | Purpose |
|---|---|
| `GrammarDB::Model` | Role with dirty tracking, setup-accessors, `is-dirty`/`mark-clean`/`mark-dirty` |
| `GrammarDB::Engine` | Load, insert, find-by, commit, build-index |
| `GrammarDB::Parser` | `Grammar` base grammar and `Action` base role |
| `GrammarDB::Service` | Thread-safe wrapper with auto-commit janitor |
| `GrammarDB::Metadata` | `.gdb.meta` sidecar for index persistence |
| `GrammarDB::Traits` | `is validates<...>` trait for attribute validation |
| `GrammarDB::Utils` | `escape` / `unescape` functions for pipe-delimited storage |

## Usage

### Defining a Model

```raku
use GrammarDB::Model;
use GrammarDB::Traits;

class Product does GrammarDB::Model {
    has $!name     is built is validates<no-whitespace>;
    has $!price    is built is validates( -> $v { $v ~~ Numeric });
    has $!category is built is validates<no-whitespace>;

    submethod TWEAK { self.setup-accessors }
    method render() { "PRD|{self.id}|{self.name}|{self.price}|{self.category}" }
}
```

Key points:
- Attributes use `$!` (private) to avoid collision with auto-generated accessors.
- `is built` allows `Product.new(...)` to initialize private attributes.
- `is validates<no-whitespace>` hooks into the validation engine.
- `self.setup-accessors` in `TWEAK` generates getter/setter methods with validation.
- `render()` produces the text format for disk persistence.

### Using a Grammar + Action

```raku
use GrammarDB::Parser;

grammar MySchema is GrammarDB::Parser::Grammar {
    token record { <product> }
    token product { 'PRD|' <id> '|' <name> '|' <price> '|' <cat> }
}

class MyActions does GrammarDB::Parser::Action {
    method product($/) {
        make Product.new(id => ~$<id>, name => ~$<name>,
                         price => +$<price>, category => ~$<cat>);
    }
}
```

### Running the Engine

```raku
use GrammarDB::Engine;

my $db = GrammarDB::Engine.new(
    file    => 'products.gdb',
    grammar => MySchema,
    actions => MyActions
);
$db.load;

# Query
my @results = $db.find-by(Product, 'category', 'Software');

# Insert
$db.insert(Product.new(id => 'P99', name => 'New Item',
                        price => 29.99, category => 'Hardware'));

# Commit
$db.commit;
```

### Validation Rules

Built-in validation rules for `is validates<...>`:

| Rule | Behavior |
|---|---|
| `'no-whitespace'` | Rejects values containing spaces or control characters |
| `'contains-whitespace'` | Allows spaces and newlines but rejects other control characters |
| `'gdb-field'` | Accepts any valid field (escape-pipe only) |
| `Callable` | Custom validator `-> $v { ... }` — return truthy to accept |

## Examples

The `examples/` directory contains a working Marketplace demo:

- `MarketplaceGrammar.rakumod` — grammar and actions for VND/PRD/LST records
- `MarketplaceModels.rakumod` — Vendor, Product, Listing model classes
- `main.raku` — end-to-end demo: load, query, insert, commit

Run it:

```bash
raku -Ilib -Iexamples examples/main.raku
```

## Development

### Running Tests

```bash
for f in t/*.rakutest; do raku -Ilib "$f"; done
```

### Adding a Model Class

1. Create a class that `does GrammarDB::Model`.
2. Declare private attributes (`$!`) with `is built` and `is validates<...>`.
3. Call `self.setup-accessors` in `submethod TWEAK`.
4. Implement `method render()` returning the pipe-delimited text format.

## License

MIT
