# GrammarDB Development Progress

## Project Overview
GrammarDB is a Raku-native flat-file database engine that uses Raku Grammars as schema and Raku Objects as the native interface. It supports hybrid evolution (multiple schema versions in one file) and surgical updates (byte-patching for performance).

## Completed Work

### 1. Repository Structure & Organization
- **Reorganized repo layout**: Core library in `lib/GrammarDB/`, demo files in root directory
- **Created module skeletons**: `Model.rakumod`, `Parser.rakumod`, `Engine.rakumod`, `Metadata.rakumod` in `lib/GrammarDB/`
- **Added entry point**: `main.raku` for demos and testing (root level)
- **Demo files**: `MarketplaceGrammar.rakumod` and `MarketplaceModels.rakumod` in root (not library code)
- **Updated documentation**: `README.md` with repo layout, `testplan.md` with comprehensive test cases

### 2. Model Layer (`lib/GrammarDB/Model.rakumod`)
- **Implemented `GrammarDB::Model` role** with required `$.id` attribute
- **Added dirty tracking**: `$!dirty` flag with `is-dirty()`, `mark-clean()`, `mark-dirty()` methods
- **Proxy-based auto-tracking**: `auto-track(\var)` returns a `Proxy` that sets `$!dirty = True` on assignment
- **Cleaned up**: Removed demo code to keep module pure library code

### 3. Parser Layer (`lib/GrammarDB/Parser.rakumod`)
- **Template grammar**: `GrammarDB::Grammar` with extensible `TOP`, `record`, `v1`/`v2` rules
- **Basic type parsing**: Rules for `INT`, `VARCHAR(x)`, `DATE`, `BOOLEAN`
- **Template actions**: `GrammarDB::Action` role with placeholder methods for instantiation
- **Extensible design**: Application grammars can inherit and override rules

### 4. Engine Layer (`lib/GrammarDB/Engine.rakumod`)
- **Core engine class**: `GrammarDB::Engine` with file, grammar, actions attributes
- **Load functionality**: Line-by-line parsing with offset tracking and error handling
- **Query support**: `find-by()` with lazy indexing (promotes to hash map after 10 searches)
- **Mutation support**: `insert()` for new objects, automatic dirty marking
- **Surgical commit**: `commit()` with byte-level patching for same-length updates, tombstoning for length changes

### 5. Testing Framework
- **Test files**: `t/01-model.rakutest`, `t/02-parser.rakutest`, `t/03-engine.rakutest`
- **Model tests**: Verify proxy dirty-tracking, render methods, role composition
- **Parser tests**: Validate grammar parsing of versioned records and type annotations
- **Engine tests**: Test load, query, mutation, and commit cycles with fixture data

## Current Status
- **Modules compile**: All library modules (`Model`, `Parser`, `Engine`, `Metadata`) compile successfully
- **Model tests pass**: Dirty-tracking proxy behavior works correctly  
- **Parser tests pass**: Grammar template parses basic records and type annotations
- **Engine implementation complete**: Load, query, insert, commit methods implemented with metadata integration
- **Metadata layer implemented**: Lazy indexing with sidecar persistence (`indices()` method added)
- **Repository reorganized**: Marketplace demo files moved to root directory (not in lib/)
- **Engine test partially working**: Loading and querying works, encountering immutability issue with price update
- **Key issues resolved**: 
  - Removed `unit` from grammar and role declarations in Parser
  - Fixed `find-by` method signature to use three parameters instead of Pair
  - Changed model attributes from private `$!` with `auto-track` to public `$.` for proper initialization
  - Added lib path for demo files in tests and main.raku
  - Fixed MarketplaceActions to include TOP and record methods

## Next Steps
1. **Make attributes writable**: Add `is rw` to model attributes to allow price/quantity updates
2. **Complete engine test**: Get all 4 tests passing
3. **Run full demo**: Execute `main.raku` to verify end-to-end functionality
4. **Integration testing**: Validate load/modify/commit cycles
5. **Performance tuning**: Optimize offset tracking and commit logic

## Technical Debt / Known Issues
- Model attributes are currently public and immutable - need `is rw` for mutation
- Dirty tracking is deferred until we make attributes writable
- Engine commit cycle needs testing after mutation works

## Architecture Alignment
The implementation closely follows the sample usage in `sampleusercode.raku`:
- Engine constructor takes `file`, `grammar`, `actions` parameters
- `load()` method parses file line-by-line
- `find-by(Class, attr => value)` queries with lazy indexing
- `insert()` adds new objects and marks them dirty
- `commit()` performs surgical updates with seek/patch logic

The codebase is now ready for the constructor fix and metadata implementation to complete Phase 3 and move to Phase 4.