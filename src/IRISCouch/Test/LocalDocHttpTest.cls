/// <p>HTTP integration tests for IRISCouch local document endpoints.</p>
/// <p>Tests <code>PUT/GET/DELETE /{db}/_local/{id}</code> via live HTTP requests.
/// Validates end-to-end behavior including routing, revision management,
/// conflict detection, and error responses. Covers AC #1-#3, #6-#8 for Story 8.1.</p>
Class IRISCouch.Test.LocalDocHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Set up test database before each test.</p>
Method OnBeforeOneTest() As %Status
{
    ; Clean up any stale data
    Kill ^IRISCouch.DB("localhttp")
    Kill ^IRISCouch.Docs("localhttp")
    Kill ^IRISCouch.Tree("localhttp")
    Kill ^IRISCouch.Changes("localhttp")
    Kill ^IRISCouch.Seq("localhttp")
    Kill ^IRISCouch.Local("localhttp")
    ; Create the test database directly (avoid HTTP overhead)
    Set tSC = ##class(IRISCouch.Storage.Database).Create("localhttp")
    Quit tSC
}

/// <p>Clean up test database after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("localhttp")
    Kill ^IRISCouch.Docs("localhttp")
    Kill ^IRISCouch.Tree("localhttp")
    Kill ^IRISCouch.Changes("localhttp")
    Kill ^IRISCouch.Seq("localhttp")
    Kill ^IRISCouch.Local("localhttp")
    Quit $$$OK
}

/// <p>AC #1, #2: PUT a local doc via HTTP, GET it back, verify 201/200 and body/rev.</p>
Method TestLocalPutAndGet()
{
    ; PUT a local document
    Set tReqBody = "{""source"":""replicator-A"",""session_id"":""abc123""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/localhttp/_local/chkpt-1", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "PUT local doc request completed")
    Do $$$AssertEquals(tStatus, 201, "PUT local doc returns 201")
    Do $$$AssertTrue($IsObject(tBody), "PUT response is JSON object")
    Do $$$AssertTrue(tBody.ok, "PUT response has ok: true")
    Do $$$AssertEquals(tBody.id, "_local/chkpt-1", "PUT response id is _local/chkpt-1")
    Do $$$AssertEquals(tBody.rev, "0-1", "PUT response rev is 0-1")
    ; GET the local document back
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/localhttp/_local/chkpt-1", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET local doc request completed")
    Do $$$AssertEquals(tStatus, 200, "GET local doc returns 200")
    Do $$$AssertTrue($IsObject(tBody), "GET response is JSON object")
    Do $$$AssertEquals(tBody."_id", "_local/chkpt-1", "GET response _id is _local/chkpt-1")
    Do $$$AssertEquals(tBody."_rev", "0-1", "GET response _rev is 0-1")
    Do $$$AssertEquals(tBody.source, "replicator-A", "GET response body field preserved")
    Do $$$AssertEquals(tBody."session_id", "abc123", "GET response session_id preserved")
}

/// <p>AC #7: PUT, then PUT again with correct _rev, verify 201 with rev "0-2".</p>
Method TestLocalUpdate()
{
    ; Initial PUT
    Set tReqBody = "{""seq"":10}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/localhttp/_local/chkpt-2", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "Initial PUT returns 201")
    Do $$$AssertEquals(tBody.rev, "0-1", "Initial rev is 0-1")
    ; Update with correct _rev
    Set tUpdateBody = "{""seq"":25,""_rev"":""0-1""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/localhttp/_local/chkpt-2", .tStatus, .tBody, tUpdateBody)
    Do $$$AssertStatusOK(tSC, "Update PUT request completed")
    Do $$$AssertEquals(tStatus, 201, "Update PUT returns 201")
    Do $$$AssertEquals(tBody.rev, "0-2", "Update rev is 0-2")
    ; GET and verify updated body
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/localhttp/_local/chkpt-2", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "GET updated doc returns 200")
    Do $$$AssertEquals(tBody.seq, 25, "GET returns updated seq value")
    Do $$$AssertEquals(tBody."_rev", "0-2", "GET returns updated rev")
}

/// <p>AC #8: PUT, then PUT with wrong _rev, verify 409 Conflict.</p>
Method TestLocalConflictOnWrongRev()
{
    ; Initial PUT
    Set tReqBody = "{""seq"":10}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/localhttp/_local/chkpt-3", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "Initial PUT returns 201")
    ; Attempt update with wrong _rev
    Set tBadBody = "{""seq"":99,""_rev"":""0-5""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/localhttp/_local/chkpt-3", .tStatus, .tBody, tBadBody)
    Do $$$AssertStatusOK(tSC, "Conflict PUT request completed")
    Do $$$AssertEquals(tStatus, 409, "Wrong rev returns 409 Conflict")
    Do $$$AssertEquals(tBody.error, "conflict", "Error slug is conflict")
}

/// <p>AC #3: PUT, then DELETE with correct rev, verify 200.</p>
Method TestLocalDelete()
{
    ; PUT first
    Set tReqBody = "{""seq"":10}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/localhttp/_local/chkpt-4", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT returns 201 for delete test")
    ; DELETE with correct rev via query parameter
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/localhttp/_local/chkpt-4?rev=0-1", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "DELETE request completed")
    Do $$$AssertEquals(tStatus, 200, "DELETE returns 200")
    Do $$$AssertTrue(tBody.ok, "DELETE response has ok: true")
    Do $$$AssertEquals(tBody.id, "_local/chkpt-4", "DELETE response id correct")
    ; Verify document is gone
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/localhttp/_local/chkpt-4", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 404, "GET after delete returns 404")
}

/// <p>AC #6: GET non-existent local doc, verify 404.</p>
Method TestLocalNotFound()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/localhttp/_local/nonexistent", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET non-existent request completed")
    Do $$$AssertEquals(tStatus, 404, "GET non-existent returns 404")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found")
    Do $$$AssertEquals(tBody.reason, "missing", "Reason is missing")
}

/// <p>AC #1: PUT new doc without _rev field, verify 201.</p>
Method TestLocalNewDocWithoutRev()
{
    ; PUT without _rev — should succeed for new document
    Set tReqBody = "{""data"":""checkpoint-data""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/localhttp/_local/chkpt-new", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "PUT new doc without rev completed")
    Do $$$AssertEquals(tStatus, 201, "PUT new doc without rev returns 201")
    Do $$$AssertTrue(tBody.ok, "Response has ok: true")
    Do $$$AssertEquals(tBody.id, "_local/chkpt-new", "Response id is correct")
    Do $$$AssertEquals(tBody.rev, "0-1", "Response rev is 0-1 for new doc")
}

}
