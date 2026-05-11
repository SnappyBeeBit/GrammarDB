# GrammarDB: The Language-Oriented Raku Database

**GrammarDB** is a self-managed, language-oriented, and Raku-native database engine. Unlike traditional databases that require rigid schemas and external SQL drivers, GrammarDB uses **Raku Grammars** as its physical schema and **Raku Objects** as its native interface.

---

## 1. Core Philosophy

* **Grammar as Schema:** The physical layout of the data on disk is defined by a standard Raku Grammar.
* **Hybrid Evolution:** Supports multiple versions of a record in the same file simultaneously through ordered alternation.
* **Zero-Migration:** Data "heals" or upgrades as it is accessed, eliminating the need for expensive "stop-the-world" migrations.
* **Raku Native:** No external dependencies. Leverages Raku's Meta-Object Protocol (MOP) for indexing and tracking.

---

## 2. Architecture Overview

### The Storage Layer (The Grammar)

Data is stored in plain text files. Each line is parsed independently.

```raku
grammar MarketplaceGrammar {
    rule TOP { <record> }
    rule record { <product_v2> | <product_v1> | <vendor> }
    
    # Version 2 adds a category field
    rule product_v2 { 'PROD' <id> '[' <name> ',' <price> ',' <cat> ']' }
    rule product_v1 { 'PROD' <id> '[' <name> ',' <price> ']' }
}

```

### The Model Layer (Native Raku Roles)

Models are standard Raku classes that consume the `GrammarDB::Model` role.

* **Auto-Tracking:** Uses a `Proxy` container to automatically mark a record as `$!dirty` when an attribute is modified via an assignment.
* **Identity Map:** Ensures the engine maintains a single source of truth for a specific ID in memory.

### The Performance Engine (Lazy Indexing)

GrammarDB avoids unnecessary memory overhead by using **Lazy Indexing**:

1. **Learning Phase:** New attributes are searched via $O(n)$ full-file scans.
2. **Threshold Promotion:** Once an attribute is searched $X$ times, the engine automatically builds an in-memory hash map.
3. **Instruction Persistence:** The intent to index is saved in a `.gdb.meta` sidecar file so indexes are rebuilt instantly on startup.

---

## 3. Technical Implementation

### Automatic Dirty Tracking

The `GrammarDB::Model` role uses a `Proxy` to intercept assignments, removing the need for manual `update()` calls:

```raku
method auto-track(\var) is rw {
    Proxy.new(
        FETCH => -> $ { var },
        STORE => -> $, $val {
            var = $val;
            $!dirty = True; 
        }
    );
}

```

---

## 4. Key Features

* **Surgical Updates:** Instead of rewriting the entire database for a single change, the engine utilizes **Match Offsets**. When a dirty record is committed, the engine uses `seek` to go to the exact byte position and replaces only the affected string.
* **Persistent Metadata Sidecar:** The `.gdb.meta` file tracks index status, search frequency, and version mapping without bloating the main data file.
* **Type-Safe Actions:** Raku Action classes "promote" raw text matches into type-safe Raku objects during the parse phase.

