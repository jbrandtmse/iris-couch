# Story 6.1: Mango Index Management

Status: done

## Story

As a client,
I want to create, list, and delete Mango indexes on document fields,
So that I can optimize query performance for my access patterns.

## Acceptance Criteria

1. `POST /iris-couch/{db}/_index` with `{"index":{"fields":["type","date"]},"name":"idx-type-date","ddoc":"my-indexes"}` returns 200 with `{"result":"created","id":"_design/my-indexes","name":"idx-type-date"}` and creates a persistent MangoIndexDef record
2. Posting the same index definition again returns `{"result":"exists"}` with no duplicate created
3. `GET /iris-couch/{db}/_index` returns 200 with `{"total_rows":N,"indexes":[...]}` listing all indexes including the built-in `_all_docs` special index and all user-created indexes with their fields, ddoc, name, type, and partial_filter_selector
4. `DELETE /iris-couch/{db}/_index/{ddoc}/json/{name}` returns 200 with `{"ok":true}` and removes the index definition and all associated MangoIndex rows
5. Creating an index with `partial_filter_selector` stores the selector with the index definition; queries not using `use_index` do NOT auto-select partial indexes (per CouchDB behavior)
6. Auto-generated index names use SHA-1 hash of the definition when `name` is omitted; auto-generated ddoc names use SHA-1 when `ddoc` is omitted
7. Validation returns 400 for: empty fields array, non-string field names, invalid type (only "json" supported), empty name/ddoc strings, unknown top-level keys
8. `Projection.Winners` %Persistent class created and populated synchronously inside `DocumentEngine.Save/SaveDeleted/SaveWithHistory` transactions — winning rev body available for Mango reads with zero staleness (NFR-P7)
9. `Projection.MangoIndex` %Persistent class created and populated synchronously inside the same write transactions — for each active index, field values extracted from winning rev and upserted as MangoIndex rows
10. No DDL or class recompilation occurs at runtime when indexes are created or deleted
11. All 220 existing tests pass with zero regressions
12. New unit and HTTP integration tests cover index CRUD, validation, idempotency, Winners projection, and MangoIndex population

## Tasks / Subtasks

- [x] Task 1: Create Projection.Winners %Persistent class (AC: #8)
  - [x] 1.1 Create `src/IRISCouch/Projection/Winners.cls` extending `%Persistent`
    - Properties: `DbName As %String`, `DocId As %String`, `WinningRev As %String`, `Deleted As %Boolean`, `Body As %String(MAXLEN="")`
    - Unique index on `(DbName, DocId)` for upsert lookups
    - Index on `(DbName, Deleted)` for _all_docs-style queries
  - [x] 1.2 Add class methods:
    - `ClassMethod Upsert(pDB, pDocId, pRev, pBody, pDeleted) As %Status` — find existing by (DbName, DocId), update or insert
    - `ClassMethod Delete(pDB, pDocId) As %Status` — remove row (for database deletion)
    - `ClassMethod DeleteAll(pDB) As %Status` — remove all rows for a database
    - `ClassMethod GetBody(pDB, pDocId) As %String` — retrieve winning body by DB+DocId
  - [x] 1.3 Compile and verify

- [x] Task 2: Create Projection.MangoIndexDef metadata class (AC: #1, #6, #10)
  - [x] 2.1 Create `src/IRISCouch/Projection/MangoIndexDef.cls` extending `%Persistent`
    - Properties:
      - `DbName As %String` — database name
      - `DDoc As %String` — design document ID (e.g., "_design/my-indexes")
      - `Name As %String` — index name
      - `Type As %String` — always "json" for now
      - `Fields As %String(MAXLEN="")` — JSON array of field objects, e.g., `[{"type":"asc"},{"date":"asc"}]`
      - `PartialFilterSelector As %String(MAXLEN="")` — JSON selector string or empty
    - Unique index on `(DbName, DDoc, Name)` for duplicate detection
    - Index on `(DbName)` for listing all indexes in a database
  - [x] 2.2 Add class methods:
    - `ClassMethod Create(pDB, pDDoc, pName, pType, pFields, pPartialFilter) As %Status` — insert new definition
    - `ClassMethod Exists(pDB, pDDoc, pName) As %Boolean` — check if index exists
    - `ClassMethod ExistsByDefinition(pDB, pFields, pPartialFilter) As %Boolean` — check if identical definition exists (for idempotency)
    - `ClassMethod FindByDefinition(pDB, pFields, pPartialFilter, Output pDDoc, Output pName) As %Boolean` — find existing identical index
    - `ClassMethod List(pDB) As %DynamicArray` — return all index definitions for a database as JSON array
    - `ClassMethod Delete(pDB, pDDoc, pName) As %Status` — delete one index definition
    - `ClassMethod DeleteAll(pDB) As %Status` — delete all index definitions for a database
    - `ClassMethod GetActiveIndexes(pDB) As %DynamicArray` — return active index definitions (for MangoIndex population during writes)
    - `ClassMethod GenerateName(pFields, pPartialFilter) As %String` — SHA-1 hash of definition for auto-generated names
    - `ClassMethod GenerateDDoc(pFields, pPartialFilter) As %String` — SHA-1 hash prefixed with "_design/" for auto-generated ddoc
  - [x] 2.3 Compile and verify

- [x] Task 3: Create Projection.MangoIndex %Persistent class (AC: #9)
  - [x] 3.1 Create `src/IRISCouch/Projection/MangoIndex.cls` extending `%Persistent`
    - Properties:
      - `DbName As %String`
      - `IndexName As %String` — matches MangoIndexDef.Name
      - `DDoc As %String` — matches MangoIndexDef.DDoc
      - `DocId As %String`
      - `FieldPath As %String` — dot-notation field path (e.g., "type", "address.city")
      - `FieldValue As %String(MAXLEN="")` — extracted field value as JSON-encoded string
      - `FieldType As %String` — JSON type: "null", "boolean", "number", "string", "array", "object"
    - Primary lookup index on `(DbName, DDoc, IndexName, FieldPath, FieldValue, DocId)` for range queries
    - Reverse index on `(DbName, DocId, DDoc, IndexName)` for efficient cleanup when document is updated/deleted
  - [x] 3.2 Add class methods:
    - `ClassMethod UpsertForDocument(pDB, pDocId, pBody As %DynamicObject, pIndexDefs As %DynamicArray) As %Status` — for each active index, extract field values from body and upsert rows
    - `ClassMethod DeleteForDocument(pDB, pDocId) As %Status` — remove all MangoIndex rows for a document (called before re-indexing on update)
    - `ClassMethod DeleteForIndex(pDB, pDDoc, pName) As %Status` — remove all rows for a specific index (called when index is deleted)
    - `ClassMethod DeleteAll(pDB) As %Status` — remove all rows for a database
    - `ClassMethod ExtractFieldValue(pBody As %DynamicObject, pFieldPath As %String) As %String` — traverse dot-notation path to extract value; return "" if not found
    - `ClassMethod GetJsonType(pValue) As %String` — determine JSON type of a value
  - [x] 3.3 Compile and verify

- [x] Task 4: Create API.MangoHandler REST handler (AC: #1, #2, #3, #4, #5, #6, #7)
  - [x] 4.1 Create `src/IRISCouch/API/MangoHandler.cls`
  - [x] 4.2 Implement `ClassMethod HandleCreateIndex(pDB As %String) As %Status`:
    - Read request body as JSON
    - Validate required field `"index"` with `"fields"` array
    - Validate optional fields: `"name"` (string, non-empty), `"ddoc"` (string, non-empty), `"type"` (must be "json"), `"partial_filter_selector"` (valid object)
    - Reject unknown top-level keys with 400
    - Normalize fields: ensure each field is `{"fieldname": "asc"|"desc"}` format; bare strings default to `"asc"`
    - Normalize ddoc: prepend `"_design/"` if not present
    - Auto-generate name via SHA-1 hash if omitted
    - Auto-generate ddoc via SHA-1 hash if omitted
    - Check idempotency: if identical definition exists, return `{"result":"exists","id":"...","name":"..."}`
    - Otherwise create via `MangoIndexDef.Create()`, backfill MangoIndex rows for existing documents, return `{"result":"created","id":"...","name":"..."}`
    - Response status: 200 OK (both created and exists)
  - [x] 4.3 Implement `ClassMethod HandleListIndexes(pDB As %String) As %Status`:
    - Call `MangoIndexDef.List(pDB)` to get user-created indexes
    - Prepend the built-in `_all_docs` special index: `{"ddoc":null,"name":"_all_docs","type":"special","def":{"fields":[{"_id":"asc"}]}}`
    - Return `{"total_rows":N,"indexes":[...]}`
    - Response status: 200 OK
  - [x] 4.4 Implement `ClassMethod HandleDeleteIndex(pDB, pDDoc, pType, pName) As %Status`:
    - Normalize pDDoc (prepend `_design/` if needed)
    - Validate pType is "json" (only supported type)
    - Check index exists via `MangoIndexDef.Exists()`; return 404 if not found
    - Delete index definition via `MangoIndexDef.Delete()`
    - Delete associated MangoIndex rows via `MangoIndex.DeleteForIndex()`
    - Return `{"ok":true}`
    - Response status: 200 OK
  - [x] 4.5 Compile and verify

- [x] Task 5: Add routes to Router (AC: #1, #3, #4)
  - [x] 5.1 Add to Router.cls UrlMap (BEFORE the `/:db/:docid` routes to avoid conflicts):
    ```
    <Route Url="/:db/_index/:ddoc/:type/:name" Method="DELETE" Call="HandleMangoIndexDelete" />
    <Route Url="/:db/_index" Method="POST" Call="HandleMangoIndexCreate" />
    <Route Url="/:db/_index" Method="GET" Call="HandleMangoIndexList" />
    ```
  - [x] 5.2 Add router wrapper methods that delegate to MangoHandler (per project pattern):
    ```objectscript
    ClassMethod HandleMangoIndexCreate(pDB) As %Status
    {
        Quit ##class(IRISCouch.API.MangoHandler).HandleCreateIndex(pDB)
    }
    ClassMethod HandleMangoIndexList(pDB) As %Status
    {
        Quit ##class(IRISCouch.API.MangoHandler).HandleListIndexes(pDB)
    }
    ClassMethod HandleMangoIndexDelete(pDB, pDDoc, pType, pName) As %Status
    {
        Quit ##class(IRISCouch.API.MangoHandler).HandleDeleteIndex(pDB, pDDoc, pType, pName)
    }
    ```
  - [x] 5.3 Compile Router

- [x] Task 6: Integrate projection updates into DocumentEngine write path (AC: #8, #9)
  - [x] 6.1 In `DocumentEngine.Save()`, inside the TSTART/TCOMMIT block, after existing Storage calls and before event signaling:
    - Call `##class(IRISCouch.Projection.Winners).Upsert(pDB, pDocId, tNewRev, pBody, 0)`
    - Call `##class(IRISCouch.Projection.MangoIndex).DeleteForDocument(pDB, pDocId)` (clear old rows)
    - Get active indexes: `Set tIndexDefs = ##class(IRISCouch.Projection.MangoIndexDef).GetActiveIndexes(pDB)`
    - If indexes exist: `Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument(pDB, pDocId, pBodyObj, tIndexDefs)`
  - [x] 6.2 In `DocumentEngine.SaveDeleted()`, inside the TSTART/TCOMMIT block:
    - Call `##class(IRISCouch.Projection.Winners).Upsert(pDB, pDocId, tNewRev, "", 1)` (empty body, deleted=true)
    - Call `##class(IRISCouch.Projection.MangoIndex).DeleteForDocument(pDB, pDocId)` (remove from all indexes)
  - [x] 6.3 In `DocumentEngine.SaveWithHistory()`, inside the TSTART/TCOMMIT block:
    - Determine winning rev after graft; if this document's winning rev changed, update Winners and MangoIndex
    - Call Winners.Upsert and MangoIndex.DeleteForDocument + UpsertForDocument
  - [x] 6.4 In `Storage.Database.Delete()` (or wherever database deletion is handled), add cleanup:
    - Call `##class(IRISCouch.Projection.Winners).DeleteAll(pDB)`
    - Call `##class(IRISCouch.Projection.MangoIndex).DeleteAll(pDB)`
    - Call `##class(IRISCouch.Projection.MangoIndexDef).DeleteAll(pDB)`
  - [x] 6.5 Compile all modified classes

- [x] Task 7: Index backfill on creation (AC: #1)
  - [x] 7.1 In `MangoHandler.HandleCreateIndex()`, after creating the index definition, iterate all existing documents in the database:
    - Use `Storage.Document.ListDocIds(pDB)` or equivalent to iterate all documents
    - For each document, get the winning rev body from Winners projection (or from Storage.Document)
    - Call `MangoIndex.UpsertForDocument()` for the new index only
  - [x] 7.2 For large databases, this could be slow — document this as a known limitation (CouchDB also builds indexes synchronously on first query, but we build on create)

- [x] Task 8: Unit tests for Projection classes (AC: #11, #12)
  - [x] 8.1 Create `src/IRISCouch/Test/ProjectionTest.cls`:
    - TestWinnersUpsertAndGet: create, verify body retrieval, update, verify new body
    - TestWinnersDelete: create then delete, verify gone
    - TestWinnersDeleteAll: create multiple, delete all for one DB, verify
    - TestMangoIndexDefCreate: create index def, verify persistence
    - TestMangoIndexDefIdempotency: create same def twice, ExistsByDefinition returns true
    - TestMangoIndexDefList: create multiple, list returns all
    - TestMangoIndexDefDelete: create then delete, verify gone
    - TestMangoIndexDefAutoName: verify SHA-1 hash generation is deterministic
    - TestMangoIndexUpsert: create index rows for a document, verify field extraction
    - TestMangoIndexDeleteForDocument: create rows, delete for doc, verify gone
    - TestMangoIndexDeleteForIndex: create rows, delete for index, verify gone
    - TestMangoIndexFieldExtraction: test dot-notation path traversal, nested objects, missing fields
    - TestMangoIndexJsonTypeDetection: verify correct type for null, boolean, number, string, array, object

- [x] Task 9: Unit tests for MangoHandler (AC: #11, #12)
  - [x] 9.1 Create `src/IRISCouch/Test/MangoHandlerTest.cls`:
    - TestCreateIndexBasic: create index, verify response format
    - TestCreateIndexIdempotent: create same index twice, verify "exists"
    - TestCreateIndexAutoName: omit name, verify auto-generated SHA-1
    - TestCreateIndexAutoDDoc: omit ddoc, verify auto-generated
    - TestCreateIndexWithPartialFilter: create with partial_filter_selector, verify stored
    - TestCreateIndexValidation: empty fields, non-string fields, unknown keys, empty name, invalid type → 400
    - TestListIndexesIncludesAllDocs: list always includes _all_docs special index first
    - TestListIndexesShowsUserIndexes: create indexes, list shows them
    - TestDeleteIndex: create then delete, verify removed from list
    - TestDeleteIndexNotFound: delete non-existent → 404

- [x] Task 10: HTTP integration tests (AC: #11, #12)
  - [x] 10.1 Create `src/IRISCouch/Test/MangoIndexHttpTest.cls` extending HttpIntegrationTest:
    - TestPostIndex: POST /{db}/_index, verify 200 + created response
    - TestPostIndexIdempotent: POST same index twice, verify "exists"
    - TestGetIndexes: GET /{db}/_index, verify _all_docs + user indexes
    - TestDeleteIndex: DELETE /{db}/_index/{ddoc}/json/{name}, verify 200
    - TestDeleteIndexNotFound: DELETE non-existent, verify 404
    - TestPostIndexValidationErrors: various invalid payloads → 400
    - TestIndexBackfillOnCreate: create documents first, then create index, verify MangoIndex rows populated
    - TestProjectionUpdatedOnDocWrite: create index, then write document, verify MangoIndex row exists
    - TestProjectionCleanedOnDocDelete: write doc, delete doc, verify MangoIndex row removed

- [x] Task 11: Run full test suite (AC: #11)
  - [x] 11.1 Compile all new and modified classes
  - [x] 11.2 Run full test suite
  - [x] 11.3 Verify zero regressions on existing 220 tests
  - [x] 11.4 Verify new tests bring total to 251 (220 existing + 31 new)

## Dev Notes

### Architecture Overview

Story 6.1 introduces three new `%Persistent` projection classes and one new API handler, following the architecture's CQRS hybrid design. The key architectural principle is:

- **Writes** go to raw globals (existing Storage.* layer)
- **Reads for Mango** go through %Persistent SQL projections (new Projection.* layer)
- **Projections are maintained synchronously** inside the same TSTART/TCOMMIT as the write — zero staleness (NFR-P7)
- **No DDL at runtime** — MangoIndex uses a fixed schema with key-value rows; new user-defined indexes only create MangoIndexDef metadata + MangoIndex data rows

### CouchDB Compatibility Notes (from source code research)

**Index Creation (`POST /_index`):**
- Request fields: `index` (required), `name`, `ddoc`, `type`, `partial_filter_selector`
- `index.fields` can be array of strings (`["foo","bar"]`) OR objects (`[{"foo":"asc"},{"bar":"desc"}]`)
- Bare string fields default to `"asc"` sort direction
- `ddoc` is normalized: "my-indexes" → "_design/my-indexes"
- Auto-generated names use SHA-1 hash: `crypto:hash(sha, term_to_binary({Definition, Options}))` — we use `$System.Encryption.SHA1Hash()` on the JSON representation
- Response always 200 (not 201) with `result` = "created" or "exists"
- CouchDB stores indexes as views inside design documents with `"language":"query"` — we store in MangoIndexDef instead (simpler, same API)

**Index Listing (`GET /_index`):**
- Always includes `_all_docs` special index first: `{"ddoc":null,"name":"_all_docs","type":"special","def":{"fields":[{"_id":"asc"}]}}`
- Each user index: `{"ddoc":"_design/...","name":"...","type":"json","def":{"fields":[...],"partial_filter_selector":{...}}}`
- Response: `{"total_rows":N,"indexes":[...]}`

**Index Deletion (`DELETE /_index/{ddoc}/{type}/{name}`):**
- `ddoc` can be with or without `_design/` prefix
- Only `json` type supported
- Returns `{"ok":true}` on success, 404 if not found

**Partial Filter Selectors:**
- Stored with index definition
- NOT auto-selected by query planner (Story 6.2) unless explicitly specified via `use_index`
- Only evaluated during index population: documents not matching the filter are not indexed

**Validation Rules (from CouchDB source):**
- `fields` must be non-empty array
- Each field must be string or object with single key mapping to "asc"/"desc"
- `type` must be string, only "json" supported (we don't implement "text" or "nouveau")
- `name` must be non-empty string if provided
- `ddoc` must be non-empty string if provided, not just "_design/"
- Unknown top-level keys return 400 `invalid_key` error

### Key Implementation Patterns

**SHA-1 Name Generation:**
```objectscript
ClassMethod GenerateName(pFields As %String, pPartialFilter As %String = "") As %String
{
    Set tInput = pFields
    If pPartialFilter '= "" Set tInput = tInput _ "|" _ pPartialFilter
    Set tHash = $System.Encryption.SHA1Hash(tInput)
    Set tHex = ##class(%xsd.hexBinary).LogicalToXSD(tHash)
    Quit $ZConvert(tHex, "L")
}
```

**Field Value Extraction (dot-notation):**
```objectscript
ClassMethod ExtractFieldValue(pBody As %DynamicObject, pFieldPath As %String) As %String
{
    Set tObj = pBody
    Set tParts = $Length(pFieldPath, ".")
    For i = 1:1:tParts {
        Set tPart = $Piece(pFieldPath, ".", i)
        If '$IsObject(tObj) Quit
        If i = tParts {
            ; Return the value (JSON-encoded for non-primitives)
            Quit tObj.%Get(tPart)
        }
        Set tObj = tObj.%Get(tPart)
    }
    Quit tObj
}
```

**MangoIndex Row Structure:**
For an index on `["type","date"]` and document `{"type":"order","date":"2024-01-15","total":42}`:
- Row 1: DbName="testdb", DDoc="_design/abc", IndexName="idx1", DocId="doc1", FieldPath="type", FieldValue="order", FieldType="string"
- Row 2: DbName="testdb", DDoc="_design/abc", IndexName="idx1", DocId="doc1", FieldPath="date", FieldValue="2024-01-15", FieldType="string"

**Winners Row Structure:**
For document "doc1" in database "testdb" with winning rev "3-abc":
- DbName="testdb", DocId="doc1", WinningRev="3-abc", Deleted=0, Body=`{"type":"order",...}`

### Integration Points with DocumentEngine

The architecture specifies that `DocumentEngine.Save()` is the single write orchestrator. Steps 4 and 5 from the architecture are:
```
4. Projection.UpdateWinners(db, docId, newRev, body, deleted)
5. Projection.UpdateMangoIndexes(db, docId, body) → for each active index
```

These calls go inside the existing TSTART/TCOMMIT block, after Storage calls but before event signaling. This ensures atomicity with the document write.

**CRITICAL: The body parameter in DocumentEngine.Save() is a %String (JSON). Parse to %DynamicObject for field extraction:**
```objectscript
Set tBodyObj = ##class(%DynamicObject).%FromJSON(pBody)
```

### Route Ordering in Router

The `_index` routes MUST be placed BEFORE the `/:db/:docid` catch-all routes in UrlMap. Otherwise `_index` would be captured as a docid. Place them in the `/:db/_*` block alongside `_all_docs`, `_bulk_docs`, `_changes`, etc.

The DELETE route pattern is `/:db/_index/:ddoc/:type/:name` — this captures 3 path segments after `_index`. CouchDB also accepts `/:db/_index/_design/:ddoc/:type/:name` (with explicit `_design/` prefix) — handle this by checking if pDDoc starts with `_design/` and normalizing.

### Storage Encapsulation

Per project memory (`feedback_storage_encapsulation.md`): No code outside `Storage.*` classes may reference `^IRISCouch.*` globals directly. The Projection classes use `%Persistent` (IRIS SQL), not globals — this is fine. The only global access is through existing Storage.* methods.

### Files to Create

| File | Class | Purpose |
|------|-------|---------|
| `src/IRISCouch/Projection/Winners.cls` | `IRISCouch.Projection.Winners` | %Persistent — winning rev SQL projection |
| `src/IRISCouch/Projection/MangoIndexDef.cls` | `IRISCouch.Projection.MangoIndexDef` | %Persistent — index definition metadata |
| `src/IRISCouch/Projection/MangoIndex.cls` | `IRISCouch.Projection.MangoIndex` | %Persistent — key-value index table |
| `src/IRISCouch/API/MangoHandler.cls` | `IRISCouch.API.MangoHandler` | REST handler for _index endpoints |
| `src/IRISCouch/Test/ProjectionTest.cls` | `IRISCouch.Test.ProjectionTest` | Unit tests for all 3 Projection classes |
| `src/IRISCouch/Test/MangoHandlerTest.cls` | `IRISCouch.Test.MangoHandlerTest` | Unit tests for MangoHandler |
| `src/IRISCouch/Test/MangoIndexHttpTest.cls` | `IRISCouch.Test.MangoIndexHttpTest` | HTTP integration tests |

### Files to Modify

| File | Changes |
|------|---------|
| `src/IRISCouch/API/Router.cls` | Add _index routes + wrapper methods |
| `src/IRISCouch/Core/DocumentEngine.cls` | Add Projection.Winners and MangoIndex calls in Save/SaveDeleted/SaveWithHistory |
| `src/IRISCouch/API/DatabaseHandler.cls` | Add Projection cleanup on database delete (if delete handler is here) |

### Previous Story Intelligence (Story 6.0)

- Code review caught stream.Read() truncation for >32KB attachments — always loop reads
- `$System.Encryption.HexEncode()` doesn't exist in IRIS — use `##class(%xsd.hexBinary).LogicalToXSD()` instead
- `%Stream.GlobalBinary.%DeleteId()` doesn't work for custom-location streams — use Open+Clear+Save
- HttpIntegrationTest.MakeRequest now supports custom content-type and binary body parameters

### CouchDB Type Comparison Ordering

For future reference in Story 6.2, CouchDB orders types as:
```
null < false < true < numbers < strings < arrays < objects
```

This affects range queries and sort ordering. Store `FieldType` in MangoIndex so Story 6.2 can implement correct cross-type comparisons.

### Project Structure Notes

- All source files in `src/IRISCouch/` with auto-sync to IRIS
- Compile via MCP tools with `ck` flags after edits
- New `Projection/` directory needs to be created under `src/IRISCouch/`
- Test classes go in `src/IRISCouch/Test/`
- Follow existing naming: `ClassMethod` with camelCase, `p` prefix for parameters, `t` prefix for locals
- %Persistent classes: NEVER manually edit Storage sections — let the compiler manage them

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Winners Projection]
- [Source: _bmad-output/planning-artifacts/architecture.md#Transaction Orchestration]
- [Source: _bmad-output/planning-artifacts/prd.md#Mango query and indexing]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.1]
- [Source: sources/couchdb/src/mango/src/mango_idx.erl — index types, validation, storage]
- [Source: sources/couchdb/src/mango/src/mango_idx_view.erl — JSON index definition, columns, usability]
- [Source: sources/couchdb/src/mango/src/mango_httpd.erl — HTTP request/response formats]
- [Source: sources/couchdb/src/mango/src/mango_crud.erl — CRUD operations]
- [Source: sources/couchdb/src/mango/src/mango_opts.erl — validation rules]
- [Source: sources/couchdb/test/elixir/test/mango/01_index_crud_test.exs — expected behaviors]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed `FindByDefinition` SQL: empty string vs NULL comparison required IS NULL check
- Fixed `Quit` with arguments inside For loops in `ExtractFieldValue` — used flag variable pattern
- Fixed `Quit` with arguments inside Try/Catch in `MatchesPartialFilter` — used result variable pattern
- Projection calls added to all 5 DocumentEngine write methods: Save, SaveAttachment, DeleteAttachment, SaveDeleted, SaveWithHistory

### Completion Notes List

- All 11 tasks completed successfully with 0 regressions on existing 220 tests
- 31 new test methods created (13 ProjectionTest + 9 MangoHandlerTest + 9 MangoIndexHttpTest), total 251
- Three %Persistent projection classes created: Winners, MangoIndexDef, MangoIndex
- MangoHandler implements full CouchDB-compatible index CRUD: create, list, delete
- Index backfill works via Winners projection first, falls back to raw Storage+RevTree
- Projections integrated synchronously into all DocumentEngine write paths (NFR-P7 zero staleness)
- Database deletion cleanup added to Storage.Database.Delete
- No DDL or class recompilation at runtime (AC #10)

### Review Findings

- [x] [Review][Patch] BackfillFromStorage accesses ^IRISCouch.Docs global directly, violating storage encapsulation [MangoHandler.cls:318] -- FIXED: Added Storage.Document.ListDocIds() method and updated BackfillFromStorage to use it
- [x] [Review][Patch] GetJsonType conflates empty string with null and misidentifies boolean/string types [MangoIndex.cls:209-222] -- FIXED: ExtractFieldValue now returns %GetTypeOf() hint; GetJsonType accepts type hint for accurate detection
- [x] [Review][Patch] Backfill logic skips documents when Winners is only partially populated [MangoHandler.cls:283-301] -- FIXED: BackfillFromStorage now receives set of already-indexed docs and skips only those
- [x] [Review][Patch] Field name validation accepts numeric bare values in fields array [MangoHandler.cls:68-80] -- FIXED: Simplified to use %GetTypeOf() for reliable string/number distinction
- [x] [Review][Defer] GetJsonType treats string values "true"/"false" as boolean type [MangoIndex.cls:219] -- deferred, requires upstream %DynamicObject type hint to distinguish (partially addressed by type hint fix)
- [x] [Review][Defer] MatchesPartialFilter only handles top-level equality selectors [MangoIndex.cls:244-265] -- deferred, full selector evaluation planned for Story 6.2
- [x] [Review][Defer] FindByDefinition-to-Create race condition under concurrency [MangoHandler.cls:131-140] -- deferred, extremely unlikely in current single-process architecture
- [x] [Review][Defer] ExtractFieldValue cannot distinguish missing field from field with empty string value [MangoIndex.cls:172-202] -- deferred, not reachable in current index population path

### Change Log

- 2026-04-13: Story 6.1 implementation complete — Mango index management with projection infrastructure

### File List

**New files:**
- `src/IRISCouch/Projection/Winners.cls` — %Persistent winning revision projection
- `src/IRISCouch/Projection/MangoIndexDef.cls` — %Persistent index definition metadata
- `src/IRISCouch/Projection/MangoIndex.cls` — %Persistent key-value index table
- `src/IRISCouch/API/MangoHandler.cls` — REST handler for /_index endpoints
- `src/IRISCouch/Test/ProjectionTest.cls` — Unit tests for all 3 Projection classes (13 tests)
- `src/IRISCouch/Test/MangoHandlerTest.cls` — Unit tests for MangoHandler (9 tests)
- `src/IRISCouch/Test/MangoIndexHttpTest.cls` — HTTP integration tests (9 tests)

**Modified files:**
- `src/IRISCouch/API/Router.cls` — Added _index routes + wrapper methods
- `src/IRISCouch/Core/DocumentEngine.cls` — Added Projection.Winners and MangoIndex calls in Save/SaveAttachment/DeleteAttachment/SaveDeleted/SaveWithHistory
- `src/IRISCouch/Storage/Database.cls` — Added Projection cleanup on database delete
