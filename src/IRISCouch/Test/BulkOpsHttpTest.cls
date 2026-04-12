/// <p>HTTP integration tests for IRISCouch bulk document endpoints.</p>
/// <p>Tests <code>POST /{db}/_bulk_docs</code> and <code>POST /{db}/_bulk_get</code>
/// via live HTTP requests. Covers AC #1-#6.</p>
Class IRISCouch.Test.BulkOpsHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create a test database before each test.</p>
Method OnBeforeOneTest() As %Status
{
    ; Clean up any previous state
    Kill ^IRISCouch.DB("testbulkhttp")
    Kill ^IRISCouch.Docs("testbulkhttp")
    Kill ^IRISCouch.Tree("testbulkhttp")
    Kill ^IRISCouch.Changes("testbulkhttp")
    Kill ^IRISCouch.Seq("testbulkhttp")
    ; Create test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testbulkhttp")
    Quit tSC
}

/// <p>Delete test database and kill all globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testbulkhttp")
    Kill ^IRISCouch.Docs("testbulkhttp")
    Kill ^IRISCouch.Tree("testbulkhttp")
    Kill ^IRISCouch.Changes("testbulkhttp")
    Kill ^IRISCouch.Seq("testbulkhttp")
    Quit $$$OK
}

/// <p>AC #1: POST /{db}/_bulk_docs with 2 docs returns 201, array of 2 results with ok.</p>
Method TestBulkDocsHttp()
{
    Set tReqBody = "{""docs"":[{""_id"":""bd1"",""name"":""Alice""},{""_id"":""bd2"",""name"":""Bob""}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testbulkhttp/_bulk_docs", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _bulk_docs request completed")
    Do $$$AssertEquals(tStatus, 201, "POST _bulk_docs returns HTTP 201")
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON array")
    Do $$$AssertEquals(tBody.%Size(), 2, "Response has 2 entries")
    ; Check first entry
    Set tEntry1 = tBody.%Get(0)
    Do $$$AssertTrue(tEntry1.ok, "Entry 1 has ok: true")
    Do $$$AssertEquals(tEntry1.id, "bd1", "Entry 1 id is bd1")
    Do $$$AssertTrue(tEntry1.rev '= "", "Entry 1 has non-empty rev")
    ; Check second entry
    Set tEntry2 = tBody.%Get(1)
    Do $$$AssertTrue(tEntry2.ok, "Entry 2 has ok: true")
    Do $$$AssertEquals(tEntry2.id, "bd2", "Entry 2 id is bd2")
    Do $$$AssertTrue(tEntry2.rev '= "", "Entry 2 has non-empty rev")
}

/// <p>AC #5: Create doc, bulk update with stale rev — result array has conflict error for that doc.</p>
Method TestBulkDocsConflictHttp()
{
    ; First create a doc
    Set tCreateBody = "{""_id"":""cfl1"",""v"":1}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testbulkhttp/cfl1", .tStatus, .tBody, tCreateBody)
    Do $$$AssertEquals(tStatus, 201, "Create doc for conflict test")
    Set tRev1 = tBody.rev
    ; Now bulk_docs: update with stale rev and create a new doc (should succeed)
    Set tBulkBody = "{""docs"":[{""_id"":""cfl1"",""_rev"":""0-stalerev"",""v"":2},{""_id"":""cfl2"",""v"":1}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testbulkhttp/_bulk_docs", .tStatus, .tBody, tBulkBody)
    Do $$$AssertEquals(tStatus, 201, "POST _bulk_docs returns 201 even with conflict")
    Do $$$AssertEquals(tBody.%Size(), 2, "Response has 2 entries")
    ; First entry should be conflict
    Set tE1 = tBody.%Get(0)
    Do $$$AssertEquals(tE1.error, "conflict", "First entry has conflict error")
    Do $$$AssertEquals(tE1.id, "cfl1", "Conflict entry has correct id")
    ; Second entry should succeed
    Set tE2 = tBody.%Get(1)
    Do $$$AssertTrue(tE2.ok, "Second entry succeeded despite first conflict")
    Do $$$AssertEquals(tE2.id, "cfl2", "Second entry has correct id")
}

/// <p>AC #2: Create 2 docs, POST /{db}/_bulk_get with both IDs returns 200 with both docs.</p>
Method TestBulkGetHttp()
{
    ; Create 2 docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testbulkhttp/bg1", .tStatus, .tBody, "{""name"":""Alice""}")
    Do $$$AssertEquals(tStatus, 201, "Create doc bg1")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testbulkhttp/bg2", .tStatus, .tBody, "{""name"":""Bob""}")
    Do $$$AssertEquals(tStatus, 201, "Create doc bg2")
    ; Bulk get both
    Set tReqBody = "{""docs"":[{""id"":""bg1""},{""id"":""bg2""}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testbulkhttp/_bulk_get", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _bulk_get request completed")
    Do $$$AssertEquals(tStatus, 200, "POST _bulk_get returns HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON object")
    Set tResults = tBody.results
    Do $$$AssertEquals(tResults.%Size(), 2, "Results has 2 entries")
    ; Check first result
    Set tR1 = tResults.%Get(0)
    Do $$$AssertEquals(tR1.id, "bg1", "First result id is bg1")
    Set tOk1 = tR1.docs.%Get(0).ok
    Do $$$AssertEquals(tOk1."_id", "bg1", "First doc has _id bg1")
    Do $$$AssertTrue(tOk1."_rev" '= "", "First doc has _rev")
    Do $$$AssertEquals(tOk1.name, "Alice", "First doc has name Alice")
    ; Check second result
    Set tR2 = tResults.%Get(1)
    Do $$$AssertEquals(tR2.id, "bg2", "Second result id is bg2")
    Set tOk2 = tR2.docs.%Get(0).ok
    Do $$$AssertEquals(tOk2."_id", "bg2", "Second doc has _id bg2")
    Do $$$AssertEquals(tOk2.name, "Bob", "Second doc has name Bob")
}

/// <p>AC #2: POST /{db}/_bulk_get with non-existent ID returns result with error entry.</p>
Method TestBulkGetMissingHttp()
{
    Set tReqBody = "{""docs"":[{""id"":""nonexistent123""}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testbulkhttp/_bulk_get", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _bulk_get request completed")
    Do $$$AssertEquals(tStatus, 200, "POST _bulk_get returns HTTP 200 even for missing docs")
    Set tResults = tBody.results
    Do $$$AssertEquals(tResults.%Size(), 1, "Results has 1 entry")
    Set tR1 = tResults.%Get(0)
    Do $$$AssertEquals(tR1.id, "nonexistent123", "Result id matches request")
    ; Check error entry
    Set tErrDoc = tR1.docs.%Get(0).error
    Do $$$AssertTrue($IsObject(tErrDoc), "Error entry is an object")
    Do $$$AssertEquals(tErrDoc.error, "not_found", "Error is not_found")
    Do $$$AssertEquals(tErrDoc.reason, "missing", "Reason is missing")
}

/// <p>AC #3: Create doc, update, POST /{db}/_bulk_get?revs=true — result includes _revisions.</p>
Method TestBulkGetRevsHttp()
{
    ; Create doc
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testbulkhttp/rvdoc", .tStatus, .tBody, "{""v"":1}")
    Do $$$AssertEquals(tStatus, 201, "Create doc for revs test")
    Set tRev1 = tBody.rev
    ; Update doc
    Set tUpdateBody = "{""_rev"":""" _ tRev1 _ """,""v"":2}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testbulkhttp/rvdoc", .tStatus, .tBody, tUpdateBody)
    Do $$$AssertEquals(tStatus, 201, "Update doc for revs test")
    Set tRev2 = tBody.rev
    ; Bulk get with revs=true
    Set tReqBody = "{""docs"":[{""id"":""rvdoc""}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testbulkhttp/_bulk_get?revs=true", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _bulk_get?revs=true request completed")
    Do $$$AssertEquals(tStatus, 200, "POST _bulk_get?revs=true returns HTTP 200")
    Set tResults = tBody.results
    Do $$$AssertEquals(tResults.%Size(), 1, "Results has 1 entry")
    Set tOkDoc = tResults.%Get(0).docs.%Get(0).ok
    Do $$$AssertEquals(tOkDoc."_id", "rvdoc", "Doc has correct _id")
    Do $$$AssertEquals(tOkDoc."_rev", tRev2, "Doc has latest _rev")
    ; Check _revisions
    Set tRevisions = tOkDoc."_revisions"
    Do $$$AssertTrue($IsObject(tRevisions), "_revisions field is present")
    Do $$$AssertEquals(tRevisions.start, 2, "_revisions.start is 2")
    Do $$$AssertEquals(tRevisions.ids.%Size(), 2, "_revisions.ids has 2 entries")
}

/// <p>Story 3.5: POST /{db}/_bulk_docs with new_edits=false stores doc with provided rev.</p>
Method TestBulkDocsNewEditsFalseHttp()
{
    Set tReqBody = "{""new_edits"":false,""docs"":[{""_id"":""ne1"",""_rev"":""1-abc"",""v"":1}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testbulkhttp/_bulk_docs", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _bulk_docs with new_edits=false request completed")
    Do $$$AssertEquals(tStatus, 201, "POST _bulk_docs with new_edits=false returns HTTP 201")
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON array")
    Do $$$AssertEquals(tBody.%Size(), 0, "Response is empty array per CouchDB spec")
}

}
