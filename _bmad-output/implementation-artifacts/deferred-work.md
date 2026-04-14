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

## Deferred from: Epic 3 retrospective — Storage Encapsulation Violations (2026-04-13)

- **HandleGet local_seq scans ^IRISCouch.Changes directly** [DocumentHandler.cls:362-364] -- The `local_seq=true` path in HandleGet iterates `^IRISCouch.Changes(pDB)` directly via `$Order` and reads entries. Should be encapsulated in a `Storage.Changes.GetDocSeq(pDB, pDocId)` method (or similar). Fix when `Storage.Changes` class is created in Epic 4.
- **HandleAllDocs iterates ^IRISCouch.Docs directly (9 lines)** [DocumentHandler.cls:798-876] -- HandleAllDocs and its key-range/pagination logic directly iterates `^IRISCouch.Docs(pDB)` via `$Order` and `$Data`. Should be encapsulated in a `Storage.Document.ListDocIds(pDB, pStartKey, pEndKey, pDirection)` iterator method or similar. Fix in Story 4.0 when DocumentHandler is split.
- **DocumentEngine.SaveDeleted sets ^IRISCouch.Tree D-marker directly** [DocumentEngine.cls:129] -- `Set ^IRISCouch.Tree(pDB, pDocId, "D", tNewRev) = 1` bypasses RevTree. Should use a `RevTree.MarkDeleted(pDB, pDocId, pRev)` method. Fix in Story 4.0.
- **DocumentEngine.SaveWithHistory checks ^IRISCouch.Tree for idempotency** [DocumentEngine.cls:192] -- `$Data(^IRISCouch.Tree(pDB, pDocId, "R", pRev))` check should use a `RevTree.RevExists(pDB, pDocId, pRev)` method. Fix in Story 4.0.
- **DocumentEngine.SaveWithHistory checks ^IRISCouch.Tree for new-doc detection** [DocumentEngine.cls:212] -- `$Data(^IRISCouch.Tree(pDB, pDocId))` check should use a `RevTree.TreeExists(pDB, pDocId)` method. Fix in Story 4.0.

## Deferred from: code review of 4-0-epic-3-deferred-cleanup (2026-04-12)

- **RevTree.GetRevsInfo accesses ^IRISCouch.Docs directly** [RevTree.cls:227] -- `$Data(^IRISCouch.Docs(pDB, pDocId, tRev))` is a cross-storage-domain access. RevTree (Storage.RevTree) checks a global belonging to Storage.Document. Should call `Storage.Document.RevBodyExists(pDB, pDocId, pRev)` or similar. Pre-existing from Story 3.3.
- **DocumentEngine direct global access to ^IRISCouch.Changes/Seq/DB** [DocumentEngine.cls:65-72,143-150,234-241] -- Save, SaveDeleted, and SaveWithHistory all write directly to ^IRISCouch.Changes, ^IRISCouch.Seq, and ^IRISCouch.DB globals. Should be encapsulated through Storage.Changes and Storage.Database methods. Pre-existing from Stories 3.1/3.2/3.5.
- **Inner try/catch Quit in HandleBulkDocs new_edits path** [BulkHandler.cls:36] -- When JSON parse fails in the inner try/catch (line 34-38), the Quit exits only the inner catch, then execution falls through to the normal new_edits=true path (line 103+). The response may be incorrect. Pre-existing from Story 3.5.

## Deferred from: code review of 4-1-normal-changes-feed (2026-04-12)

- **No test for unsupported feed mode 400 response** [ChangesHandler.cls:87-90] -- The handler returns 400 for feed modes other than "normal" (e.g., longpoll, continuous), but no unit or HTTP test exercises this path. Minor coverage gap; add when Story 4.2 (longpoll) is implemented.

## Deferred from: code review of 4-2-longpoll-changes-feed (2026-04-12)

- **Event resource name pattern duplicated in 4 locations** [DocumentEngine.cls:78,162,259 + ChangesHandler.cls:114] -- The event name string `"^IRISCouch.LPChanges(""" _ pDB _ """)"` is constructed identically in DocumentEngine.Save, SaveDeleted, SaveWithHistory, and ChangesHandler.HandleChanges. Should be extracted to a shared helper method or constant for maintainability. Code quality improvement, not a bug.

## Deferred from: code review of 4-3-built-in-changes-filters (2026-04-12)

- **Storage encapsulation: test files directly Kill ^IRISCouch.* globals** [ChangesFilterTest.cls:19-24, ChangesFilterHttpTest.cls:19-24] -- OnBeforeOneTest/OnAfterOneTest directly Kill ^IRISCouch.DB, ^IRISCouch.Docs, etc. instead of going through Storage.* classes. Pre-existing pattern used across all 24+ test files. Should be addressed project-wide when test infrastructure is refactored.
- **Missing test: _selector filter with deleted documents** [ChangesFilterTest.cls] -- No unit test exercises the _selector filter's behavior with deleted documents (which should be skipped per the implementation). The handler code correctly skips them, but no test validates this edge case. Add when delete+filter interaction is explicitly specified or during test coverage expansion.

## Deferred from: code review of 5-0-epic-4-deferred-cleanup (2026-04-12)

- **DocumentExists naming inconsistent with sibling Exists method** [Storage/Document.cls:69] -- Storage.Document has `Exists(pDB, pDocId)` for document-level and `DocumentExists(pDB, pDocId, pRev)` for revision-level checks. Name `DocumentExists` implies document-level existence. Consider renaming to `RevisionExists` for clarity in a future cleanup pass.
- **Unused local variables in IncrementDocCount/IncrementDelCount** [Storage/Database.cls:175,183] -- `$Increment` results are assigned to `tCount`/`tDelCount` but never returned or used. Harmless (ObjectScript requires assignment for `$Increment` side effect) but cosmetic noise.
- **RecordChange lacks documentation about transaction requirement** [Storage/Changes.cls:150] -- RecordChange performs two operations ($Increment + Set) that are not independently atomic. All current callers wrap in TSTART/TCOMMIT, but the method's doc comment does not mention this requirement. Add a note when Storage API documentation is formalized.
- **Test file directly kills ^IRISCouch.* globals** [StorageCleanupTest.cls:22-26,34-38] -- Continues pre-existing pattern across 24+ test files. Should be addressed project-wide when test infrastructure is refactored (same as existing deferred item from 4-3 review).

## Deferred from: code review of 5-1-standalone-attachment-upload-and-download (2026-04-12)

- **Duplicated HTTP helper in AttachmentHttpTest.MakeBinaryRequest** [AttachmentHttpTest.cls:70-107] -- Hardcoded credentials (_SYSTEM/SYS) and connection params (localhost:52773) duplicated from HttpIntegrationTest. Created because existing MakeRequest doesn't support custom content types for binary uploads. Consider extending HttpIntegrationTest.MakeRequest with optional content-type parameter when test infrastructure is refactored. Matches existing deferred pattern from 2-0 review.
- **FindRevWithAttachment lexicographic sort at generation 10+** [Storage/Attachment.cls:204-216] -- $Order sorts revision strings lexicographically ("10-x" before "2-x"), so at gen 10+ the "latest" found may not be the highest generation. Not reachable through HTTP handler (which resolves winning rev first), but could produce incorrect results when Storage.Attachment.Get() is called directly without a rev parameter. Address when multi-generation attachment scenarios are tested.
- **Stream OID leak on attachment Delete** [Storage/Attachment.cls:127-140] -- Storage.Attachment.Delete kills the metadata and stream OID reference but does not delete the underlying %Stream.GlobalBinary object. The stream data persists orphaned in the global. Low impact since it only affects explicitly deleted attachments, and database deletion cleans up the entire global. Address during storage compaction/garbage collection implementation.

## Deferred from: code review of 5-2-inline-and-multipart-attachment-upload (2026-04-12)

- **Base64 decode empty-string check is unreliable for validation** [DocumentEngine.cls:520-526] -- `$System.Encryption.Base64Decode` returns "" for both invalid base64 AND legitimately empty input. The check `If tBinary = ""` will reject zero-byte attachments as invalid. Also, some malformed base64 may decode to non-empty garbage. Not a practical issue since zero-byte inline attachments are unusual, but the validation is technically incorrect. Address if strict base64 validation is required.
- **Double base64 encode/decode in multipart/related path** [DocumentHandler.cls:143-148] -- The multipart handler reads binary data from MIME streams, base64-encodes it into a DynamicObject, then SaveWithAttachments base64-decodes it again. This is wasteful and risks issues with binary data exceeding ObjectScript string limits (~3.6MB). Consider adding a stream-based path to SaveWithAttachments that accepts pre-decoded streams for multipart use. Address when large attachment support is needed.
- **TestInvalidBase64 always passes regardless of outcome** [InlineAttachmentTest.cls:156] -- Uses `$$$AssertTrue(1, ...)` which is unconditionally true. Does not verify whether SaveWithAttachments actually rejected or accepted the invalid base64 data. Strengthen assertion when base64 validation logic is improved.

## Deferred from: code review of 5-3-attachment-retrieval-options-and-multipart-response (2026-04-12)

- **Attachment buffering in base64 paths reads entire stream into memory** [DocumentHandler.cls:591,623] -- `?attachments=true` and `?atts_since` paths use `tStream.Read()` which loads the full attachment into an ObjectScript string variable (~3.6MB limit). This is a known CouchDB design limitation: base64-in-JSON inherently requires full content in memory. The multipart path correctly streams in 32KB chunks. Document as a size limitation; CouchDB recommends standalone GET for large attachments.
- **Multipart boundary may contain MIME-special characters** [DocumentHandler.cls:442-444] -- `Base64Encode(GenCryptRand(16))` can produce `+`, `/`, `=` characters. RFC 2046 allows these in quoted boundaries but some parsers may have issues. Low risk since boundary is embedded in Content-Type header value. Consider using hex encoding or filtering to alphanumeric characters.
- **Invalid atts_since JSON silently falls back to stubs** [DocumentHandler.cls:601-606] -- When `?atts_since` contains invalid JSON, the catch block sets the parse result to empty and returns all attachments as stubs. CouchDB returns HTTP 400. Current behavior is defensively correct but deviates from CouchDB. Address if strict CouchDB compatibility is needed.
- **No attachments=true support for open_revs JSON response path** [DocumentHandler.cls:516-545] -- The open_revs JSON array path always returns attachment stubs. CouchDB supports combining `?attachments=true` with `?open_revs` to include base64 data in the array response. Not in story AC. Address if client compatibility requires it.
- **No multipart test with multiple conflicting revisions** [AttachmentRetrievalHttpTest.cls] -- All multipart tests use a single-revision document. No test validates correct MIME structure when multiple leaf revisions exist with different attachments. Add during test coverage expansion or conflict-related stories.

## Deferred from: code review of 6-0-epic-5-deferred-cleanup (2026-04-13)

- **Delete() clears shared stream OID data affecting other revisions** [Storage/Attachment.cls:131-139] -- CopyAttachments and CopyOneAttachment share stream OIDs between revisions. Delete() uses Clear()+Save() which destroys the underlying stream data for ALL revisions referencing the same OID. Not triggered by current production code paths (DeleteAttachment uses CopyAttachments with exclusion, not Delete()), but would corrupt data if Delete() is called on a revision whose stream OID is shared. Pre-existing architectural tension. Address when storage compaction or direct attachment deletion by revision is implemented.
- **Stub delimiter "||" in SaveWithAttachments may collide with attachment names** [DocumentEngine.cls:552] -- Attachment names are concatenated with "||" as delimiter, then split with $Piece. If an attachment name contains "||", parsing fails. Extremely unlikely in practice. Consider using $ListBuild for the stub name collection.
- **Delete Clear+Save leaves zero-byte stream entry** [Storage/Attachment.cls:134-138] -- After Clear()+Save(), the stream OID still exists as a zero-byte entry in stream storage. Not a data leak but leaves orphaned zero-byte entries. Address during storage compaction implementation.

## Deferred from: code review of 6-1-mango-index-management (2026-04-13)

- **GetJsonType treats string values "true"/"false" as boolean type without type hint** [Projection/MangoIndex.cls:219] -- The heuristic fallback path (no type hint) still cannot distinguish ObjectScript string "true" from a JSON boolean true. The primary extraction path now uses %GetTypeOf() hints which handles this correctly. The fallback path is only used by direct callers of GetJsonType without hints. Address if external callers require accurate boolean detection.
- ~~**MatchesPartialFilter only handles top-level equality selectors** [Projection/MangoIndex.cls:244-265]~~ -- **RESOLVED in Story 7.0**: Refactored to delegate to MangoSelector.Normalize()+Match() for full operator support.
- **FindByDefinition-to-Create race condition under concurrency** [API/MangoHandler.cls:131-140] -- Between FindByDefinition returning false and MangoIndexDef.Create(), a concurrent request could create the same index, causing a unique constraint violation surfaced as 500 instead of "exists". Extremely unlikely in current single-process architecture. Address if concurrent index creation support is required.
- **ExtractFieldValue cannot distinguish missing field from field with empty string value** [Projection/MangoIndex.cls:172-202] -- Both cases return "". The new pJsonType output parameter returns "null" for both. Not a practical issue for index population since empty string and missing field both result in "null" type index rows. Address if Mango query semantics require distinguishing $exists from empty value.

## Deferred from: code review of 6-2-mango-query-execution-selectors-and-query-plan (2026-04-13)

- ~~**Missing cross-type comparison unit tests** [MangoSelectorTest.cls]~~ -- **RESOLVED in Story 7.0**: Added TestCompareNullLtNumber and TestCompareBoolLtString tests. Also fixed TypeRank empty-string fallback to return null rank (0) instead of string rank (4).

## Deferred from: code review of 7-0-epic-6-deferred-cleanup (2026-04-13)

- **TypeRank vs InferType inconsistency on empty string** [MangoSelector.cls:820,914] -- `TypeRank("")` returns 0 (null) after the Story 7.0 fix, but `InferType("")` still returns "string" (line 914). When both are used on the same empty-string value, they disagree on the type. Currently safe because InferType is only called when field is found (tFound=true), while the empty-string-as-null path in TypeRank is for CompareValues direct calls. Pre-existing architectural inconsistency, not triggered by current code paths. Address if type detection is unified across the two methods.

## Deferred from: code review of 7-1-session-authentication-and-basic-auth (2026-04-13)

- **Username containing colons breaks cookie parsing** [Auth/Session.cls:59-61] -- Cookie format `username:hexTimestamp:hmacHex` uses `$Piece(tDecoded, ":", 1)` for username extraction. If a username contains a colon, parsing fails. Matches CouchDB's own colon-delimited format and IRIS usernames do not conventionally contain colons. Address if custom IRIS usernames with colons are supported.
- **GetSecret() race condition under concurrent requests** [Auth/Session.cls:96-101] -- Two concurrent requests seeing empty AUTHSECRET could both generate different secrets; the second Config.Set overwrites the first. Cookies signed with the first secret immediately become invalid. Same single-process architecture constraint documented in multiple previous deferred items (e.g., doc_count race, FindByDefinition race). Address if concurrent process support is required.

## Deferred from: code review of 7-2-jwt-and-proxy-authentication (2026-04-13)

- **JWT exp check has no clock skew tolerance** [Auth/JWT.cls:61] -- The expiration check `If tExp '> tNow Quit` is exact with zero tolerance for clock drift between the JWT issuer and the IRISCouch server. Industry standard is 30-60 seconds of leeway. CouchDB itself does not implement clock skew tolerance for JWT exp, so current behavior is CouchDB-compatible. Address if integration with external IdPs experiences clock-drift rejections.
- **Proxy auth unit tests test HMAC computation but not Authenticate() directly** [Test/JWTTest.cls:183-196] -- TestProxyAuthValid verifies HMAC-SHA1 computation and IsEnabled() but cannot call Proxy.Authenticate() because it requires a live %request object. The HTTP integration test (JWTHttpTest.TestProxyAuthSuccess) covers the full Authenticate() flow. Consider adding a mock %request pattern if unit-level coverage of Authenticate() is needed.
- **Hardcoded test credentials and connection params in JWTHttpTest** [Test/JWTHttpTest.cls:138-140,149-153] -- Hardcoded localhost:52773 and _SYSTEM/SYS credentials. Pre-existing pattern across all HTTP test files (same as deferred item from 2-0 review). Address project-wide when test infrastructure is refactored.

## Deferred from: code review of 7-5-auth-hotfix-credential-validation-and-role-assignment (2026-04-13)

- **CleanupTestUser swallows all exceptions silently** [Test/AuthHttpTest.cls:260] -- The catch block in CleanupTestUser discards all errors without logging. If cleanup fails (e.g., namespace switch error, user deletion failure), the test suite proceeds with stale state that could cause cascading test failures. Pre-existing test helper pattern used across multiple test files. Address when test infrastructure error handling is standardized.

## Deferred from: code review of 7-3-user-management-via-users-database (2026-04-13)

- **SaveWithHistory does not call _users hooks** [DocumentEngine.cls:424-516] -- If a _users document is replicated in via SaveWithHistory (new_edits=false), no password hashing or IRIS user sync occurs. This could allow importing user docs without creating corresponding IRIS users. Not triggered in current architecture since replication protocol (Epic 8) is not yet implemented. Address when Story 8.4 (bidirectional replication) is implemented.
- **SaveWithAttachments does not call _users hooks** [DocumentEngine.cls:538-685] -- If a _users document is saved via SaveWithAttachments, no user sync occurs. Extremely unlikely since _users documents do not normally have attachments. Address if attachment support on _users documents is required.
- **Falsy password values not guarded** [Auth/Users.cls:77] -- `pBody.%Get("password")` returns "" for null, but numeric 0 or boolean false would pass the `'= ""` check and be used as a password string. CouchDB clients always send password as a string, so this is not practically triggered. Address if input validation hardening is required.
- **Hardcoded test credentials and connection params in UsersHttpTest** [Test/UsersHttpTest.cls:184-189] -- Hardcoded localhost:52773 and _SYSTEM/SYS credentials. Pre-existing pattern across all HTTP test files (same as deferred item from 2-0 review). Address project-wide when test infrastructure is refactored.

## Deferred from: code review of 8-1-local-documents-and-replication-checkpoints (2026-04-13)

- **RenderInternal called without exception arg for Storage write failures** [ReplicationHandler.cls:119,190] -- When Storage.Local.Write() or Delete() returns an error status inside the Try block, RenderInternal is called without an exception object, so no detailed error info is logged to IRIS console. The status error details are lost. Address when a utility method for logging %Status errors (not just exceptions) is added.
- **No error handling in Storage.Local.Read()/GetRev() for corrupted $ListBuild data** [Local.cls:43-45,56-58] -- If the global value is corrupted and not a valid $ListBuild structure, $ListGet would throw an exception that propagates to the handler's Catch block. Not practically triggered unless global data is manually modified. Address during storage hardening or data integrity work.
- **TOCTOU race between Exists() and Read()/GetRev() in HandleLocalGet** [ReplicationHandler.cls:29-35] -- If another process deletes the local document between the Exists() check and the Read()/GetRev() calls, Read() returns "" and %FromJSON("") throws an exception caught by the outer Catch block (returns 500 instead of 404). Low probability in single-process IRIS configurations. Address when concurrent access patterns are implemented.

## Deferred from: code review of 8-2-revision-difference-calculation (2026-04-13)

- **possible_ancestors returns all leaf revisions without generation filtering** [ReplicationHandler.cls:190-193] -- CouchDB filters possible_ancestors to only include leaf revisions whose generation number is strictly less than the maximum missing revision's generation (couch_db.erl:2159-2170). IRISCouch returns all leaf revisions from GetLeafRevs without this filtering. This provides more data than strictly necessary to replication clients but does not break correctness since clients treat possible_ancestors as hints. The story spec explicitly defines the algorithm without generation filtering. Address when replication performance optimization is prioritized or if a client is observed to malfunction with the broader set.

## Deferred from: code review of 8-3-replication-ready-bulk-get (2026-04-13)

- **Inner parse catch Quit falls through to UNDEFINED in HandleBulkGet** [BulkHandler.cls:268-273] -- The inner Try/Catch for JSON parse failure uses `Quit` which only exits the inner Try, not the outer. Execution continues to line 273 where `tBody` is undefined, causing `<UNDEFINED>` caught by the outer Catch (returns 500 instead of intended 400). Same pre-existing bug pattern as HandleBulkDocs (logged in 4-0 deferred cleanup). Fix both together by changing inner catch to `Return $$$OK`.
- **Partial attachment Get() failure produces mixed stubs+inline response** [BulkHandler.cls:344-360] -- If `Storage.Attachment.Get()` fails for one attachment while others succeed, the failed attachment remains as its original stub entry while others are replaced with inline data. The response contains a mix of stubs and inline data for the same document. CouchDB does not define behavior for this edge case. Address if attachment retrieval reliability issues surface.

## Deferred from: code review of 8-4-bidirectional-replication-protocol (2026-04-13)

- **ReplicateLocal (push) path lacks NFR-R1 corruption detection** [Replicator.cls:404-439] -- The push path builds _bulk_docs payload for the remote CouchDB target but does not perform local corruption detection after the remote write. Remote CouchDB handles its own integrity checks. Address if bidirectional push integrity verification is needed.
- **ReplicateLocal (push) path does not include inline attachment data in _bulk_docs** [Replicator.cls:404-439] -- Push replication does not encode local attachment data as base64 inline entries in the _bulk_docs payload. Requires base64 inline attachment encoding not yet implemented. Address when push replication with attachments is a priority.
- **HttpClient SSLConfiguration hardcoded to "ISC.FeatureTracker.SSL.Config"** [HttpClient.cls:131] -- HTTPS requests use a hardcoded SSL config name. If this config does not exist on the IRIS instance, HTTPS connections will fail. Make configurable via an SSLConfiguration property when production SSL requirements are defined.
- **HttpClient.Request reads entire response body into string** [HttpClient.cls:171] -- `tReq.HttpResponse.Data.Read()` reads the full response into a string variable. For very large bulk_get responses this could exceed IRIS string limits. Implement streaming response handling for large replications.
- **Checkpoint BuildCheckpointDoc types source_last_seq as "number"** [Checkpoint.cls:183] -- Always forces source_last_seq to number type. CouchDB 2.x+ uses opaque string sequences (e.g., "57-g1AAAA..."). IRISCouch uses integer sequences locally so this is correct for local-to-local. Address when testing remote CouchDB 2.x+ interoperability.
- **No checkpoint written when source has zero changes and no prior checkpoint** [Replicator.cls:131-134] -- When source has no changes and no prior checkpoint exists, the method returns without writing a checkpoint. This is benign since the next replication will also start from 0. CouchDB protocol technically writes a checkpoint even with zero changes. Address if checkpoint consistency verification is implemented.

## Deferred from: code review of 8-5-replicator-database-and-continuous-replication-jobs (2026-04-13)

- **Missing MangoIndex re-indexing in _replicator Save hook** [DocumentEngine.cls:105-126] -- The _replicator hook in Save() updates Winners projection after body modification but does not re-index MangoIndex, unlike the _users hook pattern (lines 96-102). Inconsistent but low impact since Mango indexes on _replicator are unlikely. Address if Mango query support on _replicator documents is needed.
- **ReplicateLocal and ReplicateRemote do not populate pStats Output** [Replicator.cls:380,503] -- Push and pull replication paths do not pass through the Output pStats parameter. Callers receive zeros (initialized by Replicate() at lines 52-57) rather than actual stats. Address when push/pull replication stats are needed for _replicator document updates.
- **One-shot replication error does not retry** [Manager.cls:264-267] -- One-shot errors immediately set state to "error" and exit without retry. Story AC#5 mentions "the job retries with exponential backoff" but CouchDB behavior is that only continuous mode retries. Current behavior matches CouchDB semantics. Address if one-shot retry is explicitly required.

## Deferred from: code review of 9-0-epic-8-deferred-cleanup (2026-04-13)

- **$Horolog returns local time but timestamps append "Z" (UTC) suffix** [Storage/Database.cls:27, Replication/Manager.cls:70,170] -- All ISO-8601 timestamps use `$Translate($ZDateTime($Horolog, 3, 1), " ", "T") _ "Z"` which appends a UTC indicator to local server time. If the IRIS server is not in the UTC timezone, the stored timestamps will be semantically incorrect. The correct approach would be to use `$ZTimeStamp` (which returns UTC) instead of `$Horolog`. Pre-existing pattern introduced in Story 8.5, applied consistently in Story 9.0. Address when timezone-aware timestamp handling is implemented system-wide.

## Deferred from: code review of 9-1-prometheus-opentelemetry-metrics-endpoint (2026-04-13)

- **BuildOutput string concatenation may exceed ObjectScript ~3.6MB string limit** [Endpoint.cls:40-49] -- All Prometheus metric output is concatenated into a single ObjectScript string variable `tOut` via `BuildOutput()`. If many endpoint/method/status combinations accumulate over time, this could approach the ~3.6MB ObjectScript string limit. Pre-existing architectural pattern (string concatenation for HTTP responses). Address when metrics cardinality grows or when a streaming response pattern is adopted for large outputs.

## Deferred from: code review of 9-2-audit-event-emission (2026-04-13)

- **TestEnsureEvents namespace switch has no Try/Catch** [AuditTest.cls:119-129] -- The test switches to %SYS to verify Security.Events registration but does not wrap assertions in Try/Catch. If any assertion fails, the namespace stays as %SYS for remaining tests, potentially corrupting test isolation. Pre-existing test pattern across multiple test files. Address when test infrastructure error handling is standardized.
- **Hardcoded credentials (_SYSTEM/SYS) in AuditHttpTest** [AuditHttpTest.cls:93-94] -- Hardcoded credentials and connection params (localhost:52773). Pre-existing pattern across all HTTP test files (same as deferred items from 2-0 and 7-2 reviews). Address project-wide when test infrastructure is refactored.
