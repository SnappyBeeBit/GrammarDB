# GrammarDB Test Plan

## Purpose
Validate GrammarDB's core architecture, parsing, model dirty tracking, storage loader, indexing, and surgical commit behavior.

## Scope
- `GrammarDB::Model` role
- `GrammarDB::Grammar` and `GrammarDB::Action`
- `GrammarDB::Engine` loader and offset tracking
- `GrammarDB::Metadata` indexing and persistence
- `commit()` surgical update logic
- Demo scenario: Marketplace with Vendors, Products, Listings

## Test Cases

### 1. Model Layer
- Verify `GrammarDB::Model` defines `has Str $.id is required`.
- Verify dirty flag exists: `has Bool $!dirty = False`.
- Verify `auto-track(	erm)` returns a `Proxy`.
- Verify the proxy `STORE` sets `$!dirty = True` when a field changes.
- Verify `render()` returns the correct string representation.

### 2. Grammar and Actions
- Parse versioned records using ordered alternation (`<v2> | <v1>`).
- Verify malformed lines are reported and skipped.
- Verify action methods instantiate correct model classes with `make`.
- Verify multiple schema versions can coexist in one file.

### 3. Engine Loading
- Load a `.gdb` file line by line.
- Verify `%!store` contains objects keyed by `id`.
- Verify offsets are tracked for each parsed record.
- Verify invalid lines do not stop loading.

### 4. Metadata and Indexing
- Verify `.gdb.meta` sidecar file is created and read.
- Verify `find-by` scans `%!store` when no index exists.
- Verify search frequency is tracked per attribute.
- Verify indexes are promoted after 10 searches.
- Verify index instructions are persisted and rebuilt on load.

### 5. Surgical Committer
- Modify a loaded object and mark it dirty.
- Verify `commit()` overwrites same-length records in place.
- Verify `commit()` tombstones old records and appends new ones when length changes.
- Verify file contents remain valid Raku Grammar records.

### 6. Demo Scenario
- Create a `main.raku` script with Vendors, Products, Listings.
- Verify load, modify, and commit cycles work end-to-end.
- Verify Marketplace records can be queried and updated.

## Execution Notes
- Use explicit file fixtures for versioned and malformed records.
- Prefer unit tests for model, parser, and engine behaviors.
- Prefer integration tests for full load/commit scenario.
- Record expected vs actual file offsets after parsing.

## Acceptance Criteria
- All model and grammar invariants are satisfied.
- Dirty-tracking proxy behavior works correctly.
- Loader handles hybrid evolution and malformed input.
- Search promotion and metadata persistence function correctly.
- Commit logic updates files surgically without full rewrite.
