# Deferred Work Log

## Deferred from: code review of 1-1-configuration-system-and-package-scaffold (2026-04-12)

- **Config.Get() silently returns "" for invalid/misspelled keys** [Config.cls:36] -- $Parameter() returns empty string for non-existent parameter names. No error signaling for typos like Get("JSRUNTIM"). Consider adding key validation when the API layer is built.
- **Config.GetAll() numeric parameters serialize as strings in JSON** [Config.cls:73-78] -- $Parameter() always returns strings. Values like JSRUNTIMETIMEOUT=5000 and METRICSENABLED=1 will serialize as "5000" and "1" in JSON rather than numeric 5000 and 1. Will matter when config is returned via HTTP API. Address during Story 1.2 or when API endpoints consume config values.
- **Config.Set() accepts arbitrary key names without validation** [Config.cls:57] -- No check that pKey matches a known class parameter. Allows setting phantom keys in the global. Low risk currently but could cause confusion. Consider validating against known parameter list.
- **Request.ReadBody() has no size limit on body read** [Request.cls:17] -- %request.Content.Read() has no explicit size limit. Very large request bodies could consume excessive memory. Address as part of NFR/security hardening work.
- **Config.GetAll() requires manual update when parameters are added** [Config.cls:72-79] -- Each new parameter must be manually added to GetAll(). Consider using ObjectScript introspection to dynamically enumerate class parameters if the parameter count grows significantly.

## Deferred from: code review of 1-4-error-envelope-and-consistent-error-responses (2026-04-12)

- **ServerHandler catch blocks use Render() instead of RenderInternal()** [ServerHandler.cls:23,50] -- HandleWelcome and HandleUUIDs catch blocks call Error.Render(500,...) directly, so exceptions are silently swallowed and not logged to IRIS console. Should use RenderInternal() to satisfy NFR-S8. Fix when ServerHandler is next modified.
- **ServerHandler catch block reasons do not name the subsystem** [ServerHandler.cls:23,50] -- Both catch blocks use generic "Internal Server Error" as reason, violating NFR-O4 which requires the reason field to name the subsystem and specific failure mode. Should be e.g. "server: welcome endpoint error".
- **TestRenderEnvelopeFormat does not test Error.Render() method** [ErrorEnvelopeTest.cls:40-54] -- Test constructs %DynamicObject manually to verify JSON structure but never calls Error.Render(). Requires HTTP response mock or integration test harness to properly test.
- **TestRenderInternalHidesTrace does not test RenderInternal() method** [ErrorEnvelopeTest.cls:57-81] -- Test verifies hardcoded string "Internal Server Error" doesn't contain stack trace info but never calls RenderInternal(). Requires HTTP response mock to properly test.
- **Error.Render() has no error handling for missing %response** [Error.cls:56-61] -- If %response is not available (e.g. non-HTTP context), Render() will throw an UNDEFINED error. Pre-existing from Story 1.1.

## Deferred from: code review of 2-0-epic-1-deferred-cleanup (2026-04-12)

- **Hardcoded credentials (_SYSTEM/SYS) in HttpIntegrationTest.MakeRequest** [HttpIntegrationTest.cls:35-36] -- Security-sensitive values in source code. Matches IRIS dev defaults and is documented in story spec. Consider reading from environment or config when test infra matures.
- **Hardcoded server/port (localhost:52773) in HttpIntegrationTest.MakeRequest** [HttpIntegrationTest.cls:33-34] -- Not configurable for different environments. Consider reading from IRIS config or environment variables.
- **No early-return guard after MakeRequest failure in test methods** [HttpIntegrationTest.cls:69-117] -- If MakeRequest returns error status, subsequent assertions on tBody properties would cause INVALID OREF. Test framework catches this as test error, but diagnostic info is lost. Consider adding guard pattern when test count grows.

## Deferred from: code review of 1-2-http-router-and-couchdb-welcome-endpoint (2026-04-12)

- **Missing metrics dispatch wrapper structure in Router** [Router.cls] -- Story 1.2 dev notes specify adding metrics wrapping structure (OnPreDispatch or dispatch wrapper) with a no-op stub. This was not implemented because IRISCouch.Metrics classes do not exist yet. Add the metrics dispatch wrapper when Story 9.1 (Prometheus/OTEL Metrics Endpoint) is implemented.

## Deferred from: code review of 2-1-create-and-delete-databases (2026-04-12)

- **Race condition between Exists() and Create() in HandleCreate** [DatabaseHandler.cls:25-28] -- Between the Exists() check in HandleCreate and the Create() call, another concurrent request could create the same database. Create() does its own internal Exists() check, but if that second check fails, it returns an error status which triggers a 500 RenderInternal instead of the expected 412. Extremely unlikely in practice; address if concurrency requirements increase.
- **No maximum database name length validation** [Storage/Database.cls:88-136] -- CouchDB enforces a maximum database name length. Not specified in story AC but could cause issues with very long names hitting global subscript limits. Address when hardening database lifecycle operations.

## Deferred from: code review of 3-1-single-document-create-and-read (2026-04-12)

- **RevTree.AddChild does not verify parent revision exists in leaf index** [RevTree.cls:55] -- If pParentRev is not in the leaf index, $Get returns "" coercing to 0, resulting in incorrect depth calculation. Not reachable in Story 3.1 (create-only uses Init), but should be validated when update path (Story 3.2) is implemented.
- **No underscore-prefix validation on document IDs in HandlePut** [DocumentHandler.cls:74] -- CouchDB reserves document IDs starting with underscore for system documents (_design/, _local/). No validation prevents clients from creating documents with reserved ID prefixes. Address when system document handling is implemented (Epic 5+).

## Deferred from: code review of 3-2-document-update-delete-and-optimistic-concurrency (2026-04-12)

- **doc_count can go negative on double-delete via engine API** [DocumentEngine.cls:SaveDeleted] -- If SaveDeleted is called on a document that has already been deleted (e.g., via direct engine call bypassing handler), doc_count is decremented again, potentially going negative. The handler layer prevents this via exists + rev match checks, but the engine has no internal guard. Low risk since the API layer blocks this path. Address if engine methods are exposed to other callers.

## Deferred from: code review of 3-3-revision-tree-and-conflict-management (2026-04-12)

- **No unit test for `deleted` or `missing` status in GetRevsInfo** [RevTreeTest.cls] -- TestGetRevsInfo only covers the `available` status path. The `deleted` and `missing` status branches in GetRevsInfo are not exercised by unit tests. Add test cases that create a deleted revision and a pruned/missing revision to verify all three status paths. Not a code bug, but incomplete test coverage.

## Deferred from: code review of 3-4-bulk-document-operations (2026-04-12)

- **HandleBulkGet silently skips docs with empty id** [DocumentHandler.cls:596] -- When a `_bulk_get` request contains a doc entry with no `id` field or an empty `id`, the code silently skips it with `Continue`. The response array will have fewer entries than the request array. Not in AC and CouchDB behavior for this edge case is unspecified. Consider returning an error entry for malformed doc requests.
- **Repetitive error-entry construction in HandleBulkDocs** [DocumentHandler.cls:433-530] -- Each error case in the bulk docs loop constructs a nearly identical `tEntry` object with `id`, `error`, `reason` fields. Could be extracted to a helper method for readability and maintainability. Not a bug, code quality improvement.

## Deferred from: code review of 3-5-replication-format-bulk-writes (2026-04-12)

- **Race condition on doc_count for concurrent SaveWithHistory calls** [DocumentEngine.cls:212] -- `$Data(^IRISCouch.Tree(pDB, pDocId))` check for genuinely new documents is performed before TSTART. If two concurrent SaveWithHistory calls arrive for the same new docId, both could see tIsNewDoc=1 and both increment doc_count. Low risk in current single-process architecture but should be addressed if concurrent replication support is added.

## Deferred from: code review of 3-6-all-documents-view (2026-04-12)

- **_local_seq field omitted when no changes entry found for document** [DocumentHandler.cls:370] -- When `local_seq=true` is requested on GET /{db}/{docid}, if no matching entry is found in ^IRISCouch.Changes, the _local_seq field is simply not included in the response. CouchDB always returns _local_seq when the parameter is specified. Acceptable for alpha; address when changes feed coverage is hardened.
