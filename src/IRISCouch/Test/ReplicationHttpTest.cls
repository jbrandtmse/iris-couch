/// <p>HTTP integration tests for IRISCouch replication-format bulk writes.</p>
/// <p>Tests <code>POST /{db}/_bulk_docs</code> with <code>new_edits=false</code>
/// via live HTTP requests. Covers AC #1-#4.</p>
Class IRISCouch.Test.ReplicationHttpTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testreplhttp")
    Kill ^IRISCouch.Docs("testreplhttp")
    Kill ^IRISCouch.Tree("testreplhttp")
    Kill ^IRISCouch.Changes("testreplhttp")
    Kill ^IRISCouch.Seq("testreplhttp")
    ; Create test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testreplhttp")
    Quit tSC
}

/// <p>Delete test database and kill all globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testreplhttp")
    Kill ^IRISCouch.Docs("testreplhttp")
    Kill ^IRISCouch.Tree("testreplhttp")
    Kill ^IRISCouch.Changes("testreplhttp")
    Kill ^IRISCouch.Seq("testreplhttp")
    Quit $$$OK
}

/// <p>AC #1: POST /_bulk_docs with new_edits:false and 1 doc with _revisions.
/// Verify 201 with [], then GET the doc returns correct body.</p>
Method TestBulkDocsNewEditsFalse()
{
    ; POST _bulk_docs with new_edits=false
    Set tReqBody = "{""new_edits"":false,""docs"":[{""_id"":""repldoc1"",""_rev"":""3-abc123"",""_revisions"":{""start"":3,""ids"":[""abc123"",""def456"",""ghi789""]},""name"":""Alice""}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testreplhttp/_bulk_docs", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _bulk_docs new_edits=false request completed")
    Do $$$AssertEquals(tStatus, 201, "POST _bulk_docs new_edits=false returns HTTP 201")
    ; Response should be empty array []
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON array")
    Do $$$AssertEquals(tBody.%Size(), 0, "Response is empty array []")
    ; GET the doc and verify body
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testreplhttp/repldoc1", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "GET doc returns HTTP 200")
    Do $$$AssertEquals(tBody."_id", "repldoc1", "Doc has correct _id")
    Do $$$AssertEquals(tBody."_rev", "3-abc123", "Doc has correct _rev")
    Do $$$AssertEquals(tBody.name, "Alice", "Doc has correct body content")
}

/// <p>AC #2: Create doc normally with update (2 revs), then graft conflicting branch
/// via new_edits=false from same root. Verify both revisions accessible via ?open_revs=all.</p>
Method TestBulkDocsNewEditsFalseConflict()
{
    ; First create a doc normally
    Set tCreateBody = "{""_id"":""cfdoc"",""v"":1}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testreplhttp/cfdoc", .tStatus, .tBody, tCreateBody)
    Do $$$AssertEquals(tStatus, 201, "Create doc for conflict test")
    Set tRev1 = tBody.rev
    Set tLocalHash = $Piece(tRev1, "-", 2)
    ; Update doc to create a local chain: 1-xxx -> 2-yyy
    Set tUpdateBody = "{""_rev"":""" _ tRev1 _ """,""v"":2}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testreplhttp/cfdoc", .tStatus, .tBody, tUpdateBody)
    Do $$$AssertEquals(tStatus, 201, "Update doc to create local chain")
    Set tRev2 = tBody.rev
    ; Now graft a conflicting branch via new_edits=false from same root
    Set tReqBody = "{""new_edits"":false,""docs"":[{""_id"":""cfdoc"",""_rev"":""2-remotebranch"",""_revisions"":{""start"":2,""ids"":[""remotebranch"",""" _ tLocalHash _ """]},""v"":3}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testreplhttp/_bulk_docs", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "POST _bulk_docs new_edits=false returns 201")
    Do $$$AssertEquals(tBody.%Size(), 0, "Response is empty array")
    ; Verify both revisions accessible via open_revs=all
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testreplhttp/cfdoc?open_revs=all", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "GET with open_revs=all returns 200")
    Do $$$AssertEquals(tBody.%Size(), 2, "Two leaf revisions returned via open_revs=all")
}

/// <p>AC #4: Send same doc twice via new_edits=false, verify no error and doc_count unchanged.</p>
Method TestBulkDocsNewEditsFalseIdempotent()
{
    ; First send
    Set tReqBody = "{""new_edits"":false,""docs"":[{""_id"":""idemp1"",""_rev"":""2-xyz"",""_revisions"":{""start"":2,""ids"":[""xyz"",""abc""]},""v"":1}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testreplhttp/_bulk_docs", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "First new_edits=false send returns 201")
    ; Record doc_count
    Set tCountAfterFirst = +$Get(^IRISCouch.DB("testreplhttp", "doc_count"))
    ; Second send with same data
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testreplhttp/_bulk_docs", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "Second new_edits=false send returns 201 (no error)")
    Do $$$AssertEquals(tBody.%Size(), 0, "Response is still empty array")
    ; Verify doc_count unchanged
    Set tCountAfterSecond = +$Get(^IRISCouch.DB("testreplhttp", "doc_count"))
    Do $$$AssertEquals(tCountAfterSecond, tCountAfterFirst, "doc_count unchanged after idempotent send")
}

}
