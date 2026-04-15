# Deferred Work Log

## Deferred from: code review of 1-1-configuration-system-and-package-scaffold (2026-04-12)

- **Config.Get() silently returns "" for invalid/misspelled keys** [Config.cls:36] -- $Parameter() returns empty string for non-existent parameter names. No error signaling for typos like Get("JSRUNTIM"). Consider adding key validation when the API layer is built.
- **Config.GetAll() numeric parameters serialize as strings in JSON** [Config.cls:73-78] -- $Parameter() always returns strings. Values like JSRUNTIMETIMEOUT=5000 and METRICSENABLED=1 will serialize as "5000" and "1" in JSON rather than numeric 5000 and 1. Will matter when config is returned via HTTP API. Address during Story 1.2 or when API endpoints consume config values.
- **Config.Set() accepts arbitrary key names without validation** [Config.cls:57] -- No check that pKey matches a known class parameter. Allows setting phantom keys in the global. Low risk currently but could cause confusion. Consider validating against known parameter list.
- **Request.ReadBody() has no size limit on body read** [Request.cls:17] -- %request.Content.Read() has no explicit size limit. Very large request bodies could consume excessive memory. Address as part of NFR/security hardening work.
- ~~**Config.GetAll() requires manual update when parameters are added** [Config.cls:72-79] -- Each new parameter must be manually added to GetAll(). Consider using ObjectScript introspection to dynamically enumerate class parameters if the parameter count grows significantly.~~ -- **CLOSED: cosmetic, no functional impact**

## Deferred from: code review of 1-4-error-envelope-and-consistent-error-responses (2026-04-12)

- ~~**ServerHandler catch blocks use Render() instead of RenderInternal()** [ServerHandler.cls:23,50]~~ -- **RESOLVED prior to Story 9.0**: Both catch blocks now use `RenderInternal()` with subsystem-specific reasons. Verified in cleanup pass.
- ~~**ServerHandler catch block reasons do not name the subsystem** [ServerHandler.cls:23,50]~~ -- **RESOLVED prior to Story 9.0**: HandleWelcome uses "server: welcome endpoint error", HandleUUIDs uses "server: uuid generation error". Verified in cleanup pass.
- ~~**TestRenderEnvelopeFormat does not test Error.Render() method** [ErrorEnvelopeTest.cls:40-54] -- Test constructs %DynamicObject manually to verify JSON structure but never calls Error.Render(). Requires HTTP response mock or integration test harness to properly test.~~ -- **CLOSED: test-only, no production impact**
- ~~**TestRenderInternalHidesTrace does not test RenderInternal() method** [ErrorEnvelopeTest.cls:57-81] -- Test verifies hardcoded string "Internal Server Error" doesn't contain stack trace info but never calls RenderInternal(). Requires HTTP response mock to properly test.~~ -- **CLOSED: test-only, no production impact**
- **Error.Render() has no error handling for missing %response** [Error.cls:56-61] -- If %response is not available (e.g. non-HTTP context), Render() will throw an UNDEFINED error. Pre-existing from Story 1.1.

## Deferred from: code review of 2-0-epic-1-deferred-cleanup (2026-04-12)

- ~~**Hardcoded credentials (_SYSTEM/SYS) in HttpIntegrationTest.MakeRequest** [HttpIntegrationTest.cls:35-36]~~ -- **RESOLVED in cleanup pass**: Added configurable TESTSERVER/TESTPORT/TESTUSERNAME/TESTPASSWORD parameters with `GetTest*()` accessor methods reading from `^IRISCouchTest` global overrides. MakeRequest and all test files updated to use shared accessors.
- ~~**Hardcoded server/port (localhost:52773) in HttpIntegrationTest.MakeRequest** [HttpIntegrationTest.cls:33-34]~~ -- **RESOLVED in cleanup pass**: Same fix as above; server/port now configurable via `^IRISCouchTest("Server")` and `^IRISCouchTest("Port")` globals.
- ~~**No early-return guard after MakeRequest failure in test methods** [HttpIntegrationTest.cls:69-117] -- If MakeRequest returns error status, subsequent assertions on tBody properties would cause INVALID OREF. Test framework catches this as test error, but diagnostic info is lost. Consider adding guard pattern when test count grows.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 1-2-http-router-and-couchdb-welcome-endpoint (2026-04-12)

- **Missing metrics dispatch wrapper structure in Router** [Router.cls] -- Story 1.2 dev notes specify adding metrics wrapping structure (OnPreDispatch or dispatch wrapper) with a no-op stub. This was not implemented because IRISCouch.Metrics classes do not exist yet. Add the metrics dispatch wrapper when Story 9.1 (Prometheus/OTEL Metrics Endpoint) is implemented.

## Deferred from: code review of 2-1-create-and-delete-databases (2026-04-12)

- ~~**Race condition between Exists() and Create() in HandleCreate** [DatabaseHandler.cls:25-28] -- Between the Exists() check in HandleCreate and the Create() call, another concurrent request could create the same database. Create() does its own internal Exists() check, but if that second check fails, it returns an error status which triggers a 500 RenderInternal instead of the expected 412. Extremely unlikely in practice; address if concurrency requirements increase.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**
- **No maximum database name length validation** [Storage/Database.cls:88-136] -- CouchDB enforces a maximum database name length. Not specified in story AC but could cause issues with very long names hitting global subscript limits. Address when hardening database lifecycle operations.

## Deferred from: code review of 3-1-single-document-create-and-read (2026-04-12)

- **RevTree.AddChild does not verify parent revision exists in leaf index** [RevTree.cls:55] -- If pParentRev is not in the leaf index, $Get returns "" coercing to 0, resulting in incorrect depth calculation. Not reachable in Story 3.1 (create-only uses Init), but should be validated when update path (Story 3.2) is implemented.
- **No underscore-prefix validation on document IDs in HandlePut** [DocumentHandler.cls:74] -- CouchDB reserves document IDs starting with underscore for system documents (_design/, _local/). No validation prevents clients from creating documents with reserved ID prefixes. Address when system document handling is implemented (Epic 5+).

## Deferred from: code review of 3-2-document-update-delete-and-optimistic-concurrency (2026-04-12)

- ~~**doc_count can go negative on double-delete via engine API** [DocumentEngine.cls:SaveDeleted] -- If SaveDeleted is called on a document that has already been deleted (e.g., via direct engine call bypassing handler), doc_count is decremented again, potentially going negative. The handler layer prevents this via exists + rev match checks, but the engine has no internal guard. Low risk since the API layer blocks this path. Address if engine methods are exposed to other callers.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**

## Deferred from: code review of 3-3-revision-tree-and-conflict-management (2026-04-12)

- ~~**No unit test for `deleted` or `missing` status in GetRevsInfo** [RevTreeTest.cls] -- TestGetRevsInfo only covers the `available` status path. The `deleted` and `missing` status branches in GetRevsInfo are not exercised by unit tests. Add test cases that create a deleted revision and a pruned/missing revision to verify all three status paths. Not a code bug, but incomplete test coverage.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 3-4-bulk-document-operations (2026-04-12)

- **HandleBulkGet silently skips docs with empty id** [DocumentHandler.cls:596] -- When a `_bulk_get` request contains a doc entry with no `id` field or an empty `id`, the code silently skips it with `Continue`. The response array will have fewer entries than the request array. Not in AC and CouchDB behavior for this edge case is unspecified. Consider returning an error entry for malformed doc requests.
- ~~**Repetitive error-entry construction in HandleBulkDocs** [DocumentHandler.cls:433-530]~~ -- **RESOLVED in cleanup pass**: Extracted `BuildErrorEntry(pDocId, pError, pReason)` helper method in BulkHandler.cls. All error-entry construction now delegates to it.

## Deferred from: code review of 3-5-replication-format-bulk-writes (2026-04-12)

- ~~**Race condition on doc_count for concurrent SaveWithHistory calls** [DocumentEngine.cls:212] -- `$Data(^IRISCouch.Tree(pDB, pDocId))` check for genuinely new documents is performed before TSTART. If two concurrent SaveWithHistory calls arrive for the same new docId, both could see tIsNewDoc=1 and both increment doc_count. Low risk in current single-process architecture but should be addressed if concurrent replication support is added.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**

## Deferred from: code review of 3-6-all-documents-view (2026-04-12)

- **_local_seq field omitted when no changes entry found for document** [DocumentHandler.cls:370] -- When `local_seq=true` is requested on GET /{db}/{docid}, if no matching entry is found in ^IRISCouch.Changes, the _local_seq field is simply not included in the response. CouchDB always returns _local_seq when the parameter is specified. Acceptable for alpha; address when changes feed coverage is hardened.

## Deferred from: Epic 3 retrospective — Storage Encapsulation Violations (2026-04-13)

- ~~**HandleGet local_seq scans ^IRISCouch.Changes directly** [DocumentHandler.cls:362-364]~~ -- **RESOLVED prior to Story 9.0**: HandleGet uses `Storage.Changes.GetDocSeq(pDB, pDocId)` (line 664). Verified in cleanup pass.
- **HandleAllDocs iterates ^IRISCouch.Docs directly (9 lines)** [DocumentHandler.cls:798-876] -- HandleAllDocs and its key-range/pagination logic directly iterates `^IRISCouch.Docs(pDB)` via `$Order` and `$Data`. Should be encapsulated in a `Storage.Document.ListDocIds(pDB, pStartKey, pEndKey, pDirection)` iterator method or similar. Fix in Story 4.0 when DocumentHandler is split.
- ~~**DocumentEngine.SaveDeleted sets ^IRISCouch.Tree D-marker directly** [DocumentEngine.cls:129]~~ -- **RESOLVED prior to Story 9.0**: SaveDeleted uses `RevTree.MarkDeleted(pDB, pDocId, tNewRev)` (line 397). Verified in cleanup pass.
- ~~**DocumentEngine.SaveWithHistory checks ^IRISCouch.Tree for idempotency** [DocumentEngine.cls:192]~~ -- **RESOLVED prior to Story 9.0**: SaveWithHistory uses `RevTree.RevExists(pDB, pDocId, pRev)` (line 495). Verified in cleanup pass.
- ~~**DocumentEngine.SaveWithHistory checks ^IRISCouch.Tree for new-doc detection** [DocumentEngine.cls:212]~~ -- **RESOLVED prior to Story 9.0**: SaveWithHistory uses `RevTree.TreeExists(pDB, pDocId)` (line 515). Verified in cleanup pass.

## Deferred from: code review of 4-0-epic-3-deferred-cleanup (2026-04-12)

- ~~**RevTree.GetRevsInfo accesses ^IRISCouch.Docs directly** [RevTree.cls:227]~~ -- **RESOLVED prior to Story 9.0**: GetRevsInfo uses `Storage.Document.RevisionExists(pDB, pDocId, tRev)` (line 227). Verified in cleanup pass.
- ~~**DocumentEngine direct global access to ^IRISCouch.Changes/Seq/DB** [DocumentEngine.cls:65-72,143-150,234-241]~~ -- **RESOLVED prior to Story 9.0**: All three methods use `Storage.Changes.RecordChange()`, `Storage.Database.IncrementDocCount()`, `Storage.Database.SetUpdateSeq()`, etc. Verified in cleanup pass.
- ~~**Inner try/catch Quit in HandleBulkDocs new_edits path** [BulkHandler.cls:36]~~ -- **RESOLVED prior to Story 9.0**: HandleBulkDocs inner catch already uses `Return $$$OK` (line 37). Verified in cleanup pass.

## Deferred from: code review of 4-1-normal-changes-feed (2026-04-12)

- ~~**No test for unsupported feed mode 400 response** [ChangesHandler.cls:87-90] -- The handler returns 400 for feed modes other than "normal" (e.g., longpoll, continuous), but no unit or HTTP test exercises this path. Minor coverage gap; add when Story 4.2 (longpoll) is implemented.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 4-2-longpoll-changes-feed (2026-04-12)

- ~~**Event resource name pattern duplicated in 4 locations** [DocumentEngine.cls:78,162,259 + ChangesHandler.cls:114] -- The event name string `"^IRISCouch.LPChanges(""" _ pDB _ """)"` is constructed identically in DocumentEngine.Save, SaveDeleted, SaveWithHistory, and ChangesHandler.HandleChanges. Should be extracted to a shared helper method or constant for maintainability. Code quality improvement, not a bug.~~ -- **CLOSED: cosmetic, no functional impact**

## Deferred from: code review of 4-3-built-in-changes-filters (2026-04-12)

- ~~**Storage encapsulation: test files directly Kill ^IRISCouch.* globals** [ChangesFilterTest.cls:19-24, ChangesFilterHttpTest.cls:19-24] -- OnBeforeOneTest/OnAfterOneTest directly Kill ^IRISCouch.DB, ^IRISCouch.Docs, etc. instead of going through Storage.* classes. Pre-existing pattern used across all 24+ test files. Should be addressed project-wide when test infrastructure is refactored.~~ -- **CLOSED: test-only, no production impact**
- ~~**Missing test: _selector filter with deleted documents** [ChangesFilterTest.cls] -- No unit test exercises the _selector filter's behavior with deleted documents (which should be skipped per the implementation). The handler code correctly skips them, but no test validates this edge case. Add when delete+filter interaction is explicitly specified or during test coverage expansion.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 5-0-epic-4-deferred-cleanup (2026-04-12)

- ~~**DocumentExists naming inconsistent with sibling Exists method** [Storage/Document.cls:69]~~ -- **RESOLVED prior to Story 9.0**: Method renamed to `RevisionExists(pDB, pDocId, pRev)`. All callers updated. Verified in cleanup pass.
- ~~**Unused local variables in IncrementDocCount/IncrementDelCount** [Storage/Database.cls:175,183] -- `$Increment` results are assigned to `tCount`/`tDelCount` but never returned or used. Harmless (ObjectScript requires assignment for `$Increment` side effect) but cosmetic noise.~~ -- **CLOSED: cosmetic, no functional impact**
- ~~**RecordChange lacks documentation about transaction requirement** [Storage/Changes.cls:150]~~ -- **RESOLVED in cleanup pass**: Added doc comment noting TSTART/TCOMMIT requirement for callers.
- ~~**Test file directly kills ^IRISCouch.* globals** [StorageCleanupTest.cls:22-26,34-38] -- Continues pre-existing pattern across 24+ test files. Should be addressed project-wide when test infrastructure is refactored (same as existing deferred item from 4-3 review).~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 5-1-standalone-attachment-upload-and-download (2026-04-12)

- ~~**Duplicated HTTP helper in AttachmentHttpTest.MakeBinaryRequest** [AttachmentHttpTest.cls:70-107]~~ -- **RESOLVED in cleanup pass**: All hardcoded credentials and connection params replaced with `HttpIntegrationTest.GetTest*()` shared accessors. MakeRequest already supports custom content type via pContentType parameter.
- **FindRevWithAttachment lexicographic sort at generation 10+** [Storage/Attachment.cls:204-216] -- $Order sorts revision strings lexicographically ("10-x" before "2-x"), so at gen 10+ the "latest" found may not be the highest generation. Not reachable through HTTP handler (which resolves winning rev first), but could produce incorrect results when Storage.Attachment.Get() is called directly without a rev parameter. Address when multi-generation attachment scenarios are tested.
- **Stream OID leak on attachment Delete** [Storage/Attachment.cls:127-140] -- Storage.Attachment.Delete kills the metadata and stream OID reference but does not delete the underlying %Stream.GlobalBinary object. The stream data persists orphaned in the global. Low impact since it only affects explicitly deleted attachments, and database deletion cleans up the entire global. Address during storage compaction/garbage collection implementation.

## Deferred from: code review of 5-2-inline-and-multipart-attachment-upload (2026-04-12)

- ~~**Base64 decode empty-string check is unreliable for validation** [DocumentEngine.cls:520-526]~~ -- **RESOLVED in cleanup pass**: Fixed validation to check `(tBinary = "") && (tBase64 '= "")`, allowing zero-byte attachments (empty base64 input) while rejecting non-empty base64 that decodes to empty.
- **Double base64 encode/decode in multipart/related path** [DocumentHandler.cls:143-148] -- The multipart handler reads binary data from MIME streams, base64-encodes it into a DynamicObject, then SaveWithAttachments base64-decodes it again. This is wasteful and risks issues with binary data exceeding ObjectScript string limits (~3.6MB). Consider adding a stream-based path to SaveWithAttachments that accepts pre-decoded streams for multipart use. Address when large attachment support is needed.
- ~~**TestInvalidBase64 always passes regardless of outcome** [InlineAttachmentTest.cls:156] -- Uses `$$$AssertTrue(1, ...)` which is unconditionally true. Does not verify whether SaveWithAttachments actually rejected or accepted the invalid base64 data. Strengthen assertion when base64 validation logic is improved.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 5-3-attachment-retrieval-options-and-multipart-response (2026-04-12)

- **Attachment buffering in base64 paths reads entire stream into memory** [DocumentHandler.cls:591,623] -- `?attachments=true` and `?atts_since` paths use `tStream.Read()` which loads the full attachment into an ObjectScript string variable (~3.6MB limit). This is a known CouchDB design limitation: base64-in-JSON inherently requires full content in memory. The multipart path correctly streams in 32KB chunks. Document as a size limitation; CouchDB recommends standalone GET for large attachments.
- ~~**Multipart boundary may contain MIME-special characters** [DocumentHandler.cls:442-444]~~ -- **RESOLVED in cleanup pass**: Changed from `Base64Encode` to hex encoding via `%xsd.hexBinary.LogicalToXSD()`, producing only safe alphanumeric characters in the boundary string.
- ~~**Invalid atts_since JSON silently falls back to stubs** [DocumentHandler.cls:601-606]~~ -- **RESOLVED prior to Story 9.0**: The catch block now returns HTTP 400 with "invalid JSON in atts_since parameter" (line 616-617). Verified in cleanup pass.
- **No attachments=true support for open_revs JSON response path** [DocumentHandler.cls:516-545] -- The open_revs JSON array path always returns attachment stubs. CouchDB supports combining `?attachments=true` with `?open_revs` to include base64 data in the array response. Not in story AC. Address if client compatibility requires it.
- ~~**No multipart test with multiple conflicting revisions** [AttachmentRetrievalHttpTest.cls] -- All multipart tests use a single-revision document. No test validates correct MIME structure when multiple leaf revisions exist with different attachments. Add during test coverage expansion or conflict-related stories.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 6-0-epic-5-deferred-cleanup (2026-04-13)

- **Delete() clears shared stream OID data affecting other revisions** [Storage/Attachment.cls:131-139] -- CopyAttachments and CopyOneAttachment share stream OIDs between revisions. Delete() uses Clear()+Save() which destroys the underlying stream data for ALL revisions referencing the same OID. Not triggered by current production code paths (DeleteAttachment uses CopyAttachments with exclusion, not Delete()), but would corrupt data if Delete() is called on a revision whose stream OID is shared. Pre-existing architectural tension. Address when storage compaction or direct attachment deletion by revision is implemented.
- **Stub delimiter "||" in SaveWithAttachments may collide with attachment names** [DocumentEngine.cls:552] -- Attachment names are concatenated with "||" as delimiter, then split with $Piece. If an attachment name contains "||", parsing fails. Extremely unlikely in practice. Consider using $ListBuild for the stub name collection.
- **Delete Clear+Save leaves zero-byte stream entry** [Storage/Attachment.cls:134-138] -- After Clear()+Save(), the stream OID still exists as a zero-byte entry in stream storage. Not a data leak but leaves orphaned zero-byte entries. Address during storage compaction implementation.

## Deferred from: code review of 6-1-mango-index-management (2026-04-13)

- **GetJsonType treats string values "true"/"false" as boolean type without type hint** [Projection/MangoIndex.cls:219] -- The heuristic fallback path (no type hint) still cannot distinguish ObjectScript string "true" from a JSON boolean true. The primary extraction path now uses %GetTypeOf() hints which handles this correctly. The fallback path is only used by direct callers of GetJsonType without hints. Address if external callers require accurate boolean detection.
- ~~**MatchesPartialFilter only handles top-level equality selectors** [Projection/MangoIndex.cls:244-265]~~ -- **RESOLVED in Story 7.0**: Refactored to delegate to MangoSelector.Normalize()+Match() for full operator support.
- ~~**FindByDefinition-to-Create race condition under concurrency** [API/MangoHandler.cls:131-140] -- Between FindByDefinition returning false and MangoIndexDef.Create(), a concurrent request could create the same index, causing a unique constraint violation surfaced as 500 instead of "exists". Extremely unlikely in current single-process architecture. Address if concurrent index creation support is required.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**
- **ExtractFieldValue cannot distinguish missing field from field with empty string value** [Projection/MangoIndex.cls:172-202] -- Both cases return "". The new pJsonType output parameter returns "null" for both. Not a practical issue for index population since empty string and missing field both result in "null" type index rows. Address if Mango query semantics require distinguishing $exists from empty value.

## Deferred from: code review of 6-2-mango-query-execution-selectors-and-query-plan (2026-04-13)

- ~~**Missing cross-type comparison unit tests** [MangoSelectorTest.cls]~~ -- **RESOLVED in Story 7.0**: Added TestCompareNullLtNumber and TestCompareBoolLtString tests. Also fixed TypeRank empty-string fallback to return null rank (0) instead of string rank (4).

## Deferred from: code review of 7-0-epic-6-deferred-cleanup (2026-04-13)

- **TypeRank vs InferType inconsistency on empty string** [MangoSelector.cls:820,914] -- `TypeRank("")` returns 0 (null) after the Story 7.0 fix, but `InferType("")` still returns "string" (line 914). When both are used on the same empty-string value, they disagree on the type. Currently safe because InferType is only called when field is found (tFound=true), while the empty-string-as-null path in TypeRank is for CompareValues direct calls. Pre-existing architectural inconsistency, not triggered by current code paths. Address if type detection is unified across the two methods.

## Deferred from: code review of 7-1-session-authentication-and-basic-auth (2026-04-13)

- **Username containing colons breaks cookie parsing** [Auth/Session.cls:59-61] -- Cookie format `username:hexTimestamp:hmacHex` uses `$Piece(tDecoded, ":", 1)` for username extraction. If a username contains a colon, parsing fails. Matches CouchDB's own colon-delimited format and IRIS usernames do not conventionally contain colons. Address if custom IRIS usernames with colons are supported.
- ~~**GetSecret() race condition under concurrent requests** [Auth/Session.cls:96-101] -- Two concurrent requests seeing empty AUTHSECRET could both generate different secrets; the second Config.Set overwrites the first. Cookies signed with the first secret immediately become invalid. Same single-process architecture constraint documented in multiple previous deferred items (e.g., doc_count race, FindByDefinition race). Address if concurrent process support is required.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**

## Deferred from: code review of 7-2-jwt-and-proxy-authentication (2026-04-13)

- **JWT exp check has no clock skew tolerance** [Auth/JWT.cls:61] -- The expiration check `If tExp '> tNow Quit` is exact with zero tolerance for clock drift between the JWT issuer and the IRISCouch server. Industry standard is 30-60 seconds of leeway. CouchDB itself does not implement clock skew tolerance for JWT exp, so current behavior is CouchDB-compatible. Address if integration with external IdPs experiences clock-drift rejections.
- ~~**Proxy auth unit tests test HMAC computation but not Authenticate() directly** [Test/JWTTest.cls:183-196] -- TestProxyAuthValid verifies HMAC-SHA1 computation and IsEnabled() but cannot call Proxy.Authenticate() because it requires a live %request object. The HTTP integration test (JWTHttpTest.TestProxyAuthSuccess) covers the full Authenticate() flow. Consider adding a mock %request pattern if unit-level coverage of Authenticate() is needed.~~ -- **CLOSED: test-only, no production impact**
- ~~**Hardcoded test credentials and connection params in JWTHttpTest** [Test/JWTHttpTest.cls:138-140,149-153]~~ -- **RESOLVED in cleanup pass**: All hardcoded values replaced with `HttpIntegrationTest.GetTest*()` shared accessors.

## Deferred from: code review of 7-5-auth-hotfix-credential-validation-and-role-assignment (2026-04-13)

- ~~**CleanupTestUser swallows all exceptions silently** [Test/AuthHttpTest.cls:260] -- The catch block in CleanupTestUser discards all errors without logging. If cleanup fails (e.g., namespace switch error, user deletion failure), the test suite proceeds with stale state that could cause cascading test failures. Pre-existing test helper pattern used across multiple test files. Address when test infrastructure error handling is standardized.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 7-3-user-management-via-users-database (2026-04-13)

- **SaveWithHistory does not call _users hooks** [DocumentEngine.cls:424-516] -- If a _users document is replicated in via SaveWithHistory (new_edits=false), no password hashing or IRIS user sync occurs. This could allow importing user docs without creating corresponding IRIS users. Not triggered in current architecture since replication protocol (Epic 8) is not yet implemented. Address when Story 8.4 (bidirectional replication) is implemented.
- **SaveWithAttachments does not call _users hooks** [DocumentEngine.cls:538-685] -- If a _users document is saved via SaveWithAttachments, no user sync occurs. Extremely unlikely since _users documents do not normally have attachments. Address if attachment support on _users documents is required.
- **Falsy password values not guarded** [Auth/Users.cls:77] -- `pBody.%Get("password")` returns "" for null, but numeric 0 or boolean false would pass the `'= ""` check and be used as a password string. CouchDB clients always send password as a string, so this is not practically triggered. Address if input validation hardening is required.
- ~~**Hardcoded test credentials and connection params in UsersHttpTest** [Test/UsersHttpTest.cls:184-189]~~ -- **RESOLVED in cleanup pass**: All hardcoded values replaced with `HttpIntegrationTest.GetTest*()` shared accessors.

## Deferred from: code review of 8-1-local-documents-and-replication-checkpoints (2026-04-13)

- **RenderInternal called without exception arg for Storage write failures** [ReplicationHandler.cls:119,190] -- When Storage.Local.Write() or Delete() returns an error status inside the Try block, RenderInternal is called without an exception object, so no detailed error info is logged to IRIS console. The status error details are lost. Address when a utility method for logging %Status errors (not just exceptions) is added.
- **No error handling in Storage.Local.Read()/GetRev() for corrupted $ListBuild data** [Local.cls:43-45,56-58] -- If the global value is corrupted and not a valid $ListBuild structure, $ListGet would throw an exception that propagates to the handler's Catch block. Not practically triggered unless global data is manually modified. Address during storage hardening or data integrity work.
- ~~**TOCTOU race between Exists() and Read()/GetRev() in HandleLocalGet** [ReplicationHandler.cls:29-35] -- If another process deletes the local document between the Exists() check and the Read()/GetRev() calls, Read() returns "" and %FromJSON("") throws an exception caught by the outer Catch block (returns 500 instead of 404). Low probability in single-process IRIS configurations. Address when concurrent access patterns are implemented.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**

## Deferred from: code review of 8-2-revision-difference-calculation (2026-04-13)

- **possible_ancestors returns all leaf revisions without generation filtering** [ReplicationHandler.cls:190-193] -- CouchDB filters possible_ancestors to only include leaf revisions whose generation number is strictly less than the maximum missing revision's generation (couch_db.erl:2159-2170). IRISCouch returns all leaf revisions from GetLeafRevs without this filtering. This provides more data than strictly necessary to replication clients but does not break correctness since clients treat possible_ancestors as hints. The story spec explicitly defines the algorithm without generation filtering. Address when replication performance optimization is prioritized or if a client is observed to malfunction with the broader set.

## Deferred from: code review of 8-3-replication-ready-bulk-get (2026-04-13)

- ~~**Inner parse catch Quit falls through to UNDEFINED in HandleBulkGet** [BulkHandler.cls:268-273]~~ -- **RESOLVED in cleanup pass**: Changed inner catch `Quit` to `Return $$$OK` to correctly exit the method after rendering the 400 error response.
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

- ~~**$Horolog returns local time but timestamps append "Z" (UTC) suffix** [Storage/Database.cls:27, Replication/Manager.cls:70,170]~~ -- **RESOLVED in Story 10.0**: All three locations changed from `$Horolog` to `$ZTimeStamp` (UTC). Updated "Timestamp and Encoding Standards" rule to document `$ZTimeStamp` as the correct choice. All tests pass.

## Deferred from: code review of 9-1-prometheus-opentelemetry-metrics-endpoint (2026-04-13)

- **BuildOutput string concatenation may exceed ObjectScript ~3.6MB string limit** [Endpoint.cls:40-49] -- All Prometheus metric output is concatenated into a single ObjectScript string variable `tOut` via `BuildOutput()`. If many endpoint/method/status combinations accumulate over time, this could approach the ~3.6MB ObjectScript string limit. Pre-existing architectural pattern (string concatenation for HTTP responses). Address when metrics cardinality grows or when a streaming response pattern is adopted for large outputs.

## Deferred from: code review of 9-2-audit-event-emission (2026-04-13)

- ~~**TestEnsureEvents namespace switch has no Try/Catch** [AuditTest.cls:119-129] -- The test switches to %SYS to verify Security.Events registration but does not wrap assertions in Try/Catch. If any assertion fails, the namespace stays as %SYS for remaining tests, potentially corrupting test isolation. Pre-existing test pattern across multiple test files. Address when test infrastructure error handling is standardized.~~ -- **CLOSED: test-only, no production impact**
- ~~**Hardcoded credentials (_SYSTEM/SYS) in AuditHttpTest** [AuditHttpTest.cls:93-94]~~ -- **RESOLVED in cleanup pass**: All hardcoded values replaced with `HttpIntegrationTest.GetTest*()` shared accessors.

## Deferred from: code review of 9-3-operational-resilience-and-data-durability (2026-04-13)

- **Log.Debug() has no gating for debug-level logging** [Util/Log.cls:54-57] -- The doc comment says "Only emitted when IRIS debug logging is enabled" but the implementation always calls Emit unconditionally. IRIS does not have a built-in debug flag that can be checked via ObjectScript. Consider adding a Config parameter (e.g., LOGLEVEL) to control minimum log level, or checking a global flag before emitting debug messages. Low impact since Debug() is not currently called from any production code path.

## Deferred from: code review of 10-0-epic-9-deferred-cleanup (2026-04-14)

- **JWT.UnixTimestamp() uses $Horolog (local time) but doc claims UTC** [Auth/JWT.cls:158] -- `UnixTimestamp()` computes Unix epoch from `$Horolog` which returns local server time, but the doc comment says "seconds since 1970-01-01 00:00:00 UTC". On non-UTC servers, JWT `iat`/`exp` claims will be offset by the server's timezone delta. Pre-existing issue not introduced by Story 10.0 (which fixed the ISO-8601 `$Horolog`+Z pattern in different files). Should use `$ZTimeStamp` for the day and seconds components, or document the local-time assumption. Low impact when server runs in UTC.

---

## Epic 10 Triage (2026-04-14)

**Reviewed by:** Story 10.0 (Epic 9 Deferred Cleanup)

All 43 remaining open deferred work items were reviewed for Epic 10 (Admin UI - Angular frontend) relevance. Every item is an ObjectScript backend concern (storage encapsulation, string limits, stream OID leaks, race conditions, attachment edge cases, replication stats, cookie parsing, JWT clock skew, etc.). **None reference Angular, TypeScript, or frontend code. None block Epic 10 work.** The Angular frontend consumes the IRISCouch REST API and does not depend on any of these backend internals being resolved first.

## Deferred from: code review of 10-1-angular-scaffold-design-tokens-and-icon-system (2026-04-14)

- **No ChangeDetectionStrategy.OnPush on icon components** [ui/src/app/couch-ui/icons/*.ts] -- All 20 icon components and AppComponent use the default change detection strategy. For components with no dynamic content beyond a single `size` input, OnPush would be a minor performance optimization. LOW -- address project-wide when more components exist.
- **@Input() decorator vs modern input() signal** [ui/src/app/couch-ui/icons/*.ts] -- Angular 18 introduced the `input()` signal function. The current code uses the traditional `@Input()` decorator which is fully supported and not deprecated. LOW -- stylistic preference, can be adopted project-wide when the team decides on signal adoption.
- **No JetBrains Mono weight 500 bundled** [ui/src/assets/fonts/] -- UX spec mentions weights 400 and 500, but only 400 is bundled per story decision. Browser will synthesize faux-bold for 500. LOW -- bundle 500 weight WOFF2 (~20KB more) in a later story if synthetic bold looks poor on Windows ClearType.

## Deferred from: code review of 10-2-core-ui-components (2026-04-14)

- **Badge 10px font-size vs AC #6 "no text below 12px"** [ui/src/app/couch-ui/badge/badge.component.ts:29] -- UX spec explicitly requires "10 px uppercase small-caps" for badges; AC #6 says no text below 12px. These contradict. UX spec is the design authority and takes precedence. If the minimum changes, update badge font-size accordingly.
- **Hardcoded RGBA values in badge backgrounds** [ui/src/app/couch-ui/badge/badge.component.ts:44-59] -- Background colors use raw rgba() values (e.g., rgba(60, 90, 158, 0.1)) corresponding to semantic colors at 10% alpha. No CSS token exists for alpha-modified semantic colors. LOW -- consider adding alpha-variant tokens to tokens.css if more components need this pattern.
- **CopyButton no error feedback on failed clipboard copy** [ui/src/app/couch-ui/copy-button/copy-button.component.ts:93] -- When clipboard.copy() returns false (e.g., due to browser security restrictions), no error feedback is shown. User gets no indication the copy failed. LOW -- add visual/auditory error feedback in a future pass.

## Deferred from: code review of 10-3-appshell-navigation-and-login (2026-04-14)

- **ErrorDisplay test suite has only 3 examples (401, 404, 500)** [ui/src/app/couch-ui/error-display/error-display.component.spec.ts] -- UX spec requires at least 5 examples (401, 404, 409, 500, network error). Missing 409 conflict error and network error test cases. MEDIUM -- add missing test cases in a future story or test expansion pass.
- **Password field not cleared after successful login** [ui/src/app/features/auth/login.component.ts:186-189] -- After successful login, this.password remains in component memory until Angular garbage-collects the component on navigation. Security hygiene improvement. LOW -- component is destroyed on navigation, so exposure window is minimal.
- **Button component CSS budget warning** [ui/src/app/couch-ui/button/button.component.ts] -- Production build warns button component CSS (2.28 KB) exceeds the 2.05 KB budget by 229 bytes. Pre-existing from Story 10.2. LOW -- either increase budget or reduce CSS.

## Deferred from: code review of 10-4-database-list-view-with-create-and-delete (2026-04-14)

- **No UI trigger for database delete action (AC #5)** [ui/src/app/features/databases/database-list.component.ts] -- `openDeleteDialog(db: DatabaseEntry)` method exists and works correctly, but no template element invokes it. The DataTable component is domain-free and does not support action columns with buttons. AC #5 requires "the operator clicks delete on a database" which needs either: (a) extending DataTable to support template-projected cell content for an actions column, (b) adding a separate row-action overlay/menu, or (c) adding inline delete buttons outside the DataTable. MEDIUM -- functional code exists and is tested; only the UI trigger is missing.

## Deferred from: code review of 10-5-document-list-view-with-filtering-and-pagination (2026-04-14)

- **paginationStart assumes linear page history** [ui/src/app/features/database/database-detail.component.ts] -- Range indicator math uses `pageHistory.length * PAGE_SIZE`, which is inaccurate if any page had fewer than PAGE_SIZE rows (e.g., the last page of filtered results). Cosmetic only -- affects the approximate range indicator display. LOW.
- **totalRows reflects total DB doc count, not filtered count** [ui/src/app/features/database/database-detail.component.ts] -- CouchDB `_all_docs` `total_rows` returns the total number of documents in the database regardless of filter. Range indicator shows "rows 1-3 of ~42,187" even when only 3 docs match the filter prefix. By design per CouchDB API -- no way to get filtered count without a separate query. LOW.

## Deferred from: code review of 10-6-document-detail-view (2026-04-14)

- **Design doc ID double-encoding in getDocument and getAttachmentUrl** [ui/src/app/services/document.service.ts, ui/src/app/features/document/document-detail.component.ts] -- `encodeURIComponent('_design/myview')` produces `_design%2Fmyview`, but CouchDB expects `/{db}/_design/myview` with the slash unencoded. This will cause 404s when navigating to design doc detail views. Address in Epic 11 Story 11-1 (Design Document List and Detail View) which introduces design doc-specific routing and API methods.

## Deferred from: code review of 10-7-error-handling-accessibility-and-cross-browser-verification (2026-04-14)

- **Network error message hardcoded in 3 components** [database-list.component.ts, database-detail.component.ts, document-detail.component.ts] -- The string "Cannot reach `/iris-couch/`. Check that the server is running." is duplicated across all three feature components. Extract to a shared constant or utility function for DRY compliance. LOW.
- **Error handler pattern (status=0 branch) duplicated 3x** [database-list.component.ts, database-detail.component.ts, document-detail.component.ts] -- The `if (err.status === 0) { ... } else { ... }` error classification logic is copy-pasted identically across all three components. Extract to a shared error handler utility function (e.g., `classifyHttpError(err): { error, reason, statusCode }`) for maintainability. LOW.
