# AGENTS.md - GrammarDB Instructions

## Overview
GrammarDB is a Raku-native, language-oriented database engine that uses Grammars as schemas and Raku objects as interfaces.

## Development Workflow

### Testing
- Run all tests: `for f in t/*.rakutest; do raku -Ilib "$f"; done`
- Run a specific test: `raku -Ilib t/01-model.rakutest`
- Ensure tests pass after any change, especially in `lib/GrammarDB/Engine.rakumod` or `lib/GrammarDB/Model.rakumod`.

### Key Directories
- `lib/GrammarDB/`: Core engine logic (Parser, Engine, Model, Metadata, Service, Traits, Utils).
- `examples/`: Demo grammar, models, and entry point.
- `t/`: Integration and unit tests.

### Implementation Quirks
- **Grammar-as-Schema:** Physical data layout is defined in Raku Grammars.
- **Surgical Updates:** The engine performs in-place byte-level updates using `seek` and file offsets. Avoid changing the file handling logic without understanding the tombstone/append mechanism.
- **Lazy Indexing:** Indexes are built in-memory after X lookups, and persisted in `.gdb.meta` files. If test data behaves strangely, check/clear the corresponding `.gdb.meta` files.
- **Auto-Dirty Tracking:** Uses `setup-accessors` and `is validates` trait for validated accessors with dirty tracking. The old `auto-track` / `Proxy` approach is deprecated.
- **Role Closure Capture:** The `is validates` trait uses `$attr does role { has $.validation-type is rw }` with post-set to avoid a Raku anonymous role punning bug. Do not revert to `$attr does role { has $.validation-type = $val }`.
