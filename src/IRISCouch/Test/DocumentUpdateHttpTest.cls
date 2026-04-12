/// <p>HTTP integration tests for document update, delete, and validation endpoints.</p>
/// <p>Tests <code>PUT /{db}/{docid}</code> (update/delete via _deleted),
/// <code>DELETE /{db}/{docid}</code>, and underscore field validation
/// via live HTTP requests. Covers Story 3.2 AC #1-#5.</p>
Class IRISCouch.Test.DocumentUpdateHttpTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testdochttp2")
    Kill ^IRISCouch.Docs("testdochttp2")
    Kill ^IRISCouch.Tree("testdochttp2")
    Kill ^IRISCouch.Changes("testdochttp2")
    Kill ^IRISCouch.Seq("testdochttp2")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testdochttp2")
    Quit tSC
}

/// <p>Delete test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testdochttp2")
    Kill ^IRISCouch.Docs("testdochttp2")
    Kill ^IRISCouch.Tree("testdochttp2")
    Kill ^IRISCouch.Changes("testdochttp2")
    Kill ^IRISCouch.Seq("testdochttp2")
    Quit $$$OK
}

/// <p>AC #1: Create doc, PUT with valid _rev returns 201 with rev 2-*.</p>
Method TestUpdateDocument()
{
    ; Create doc first
    Set tReqBody = "{""name"":""Alice""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp2/updoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    Set tRev1 = tBody.rev
    Do $$$AssertEquals($Piece(tRev1, "-", 1), 1, "Initial rev is gen 1")
    ; Update with correct _rev in body
    Set tUpdateBody = "{""name"":""Bob"",""_rev"":""" _ tRev1 _ """}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp2/updoc", .tStatus, .tBody, tUpdateBody)
    Do $$$AssertStatusOK(tSC, "PUT update request completed")
    Do $$$AssertEquals(tStatus, 201, "PUT update returns HTTP 201")
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON object")
    Do $$$AssertTrue(tBody.ok, "Response has ok: true")
    Do $$$AssertEquals(tBody.id, "updoc", "Response id matches")
    Set tRev2 = tBody.rev
    Do $$$AssertEquals($Piece(tRev2, "-", 1), 2, "Updated rev is generation 2")
    ; Verify GET returns updated content
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testdochttp2/updoc", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "GET updated doc returns 200")
    Do $$$AssertEquals(tBody.name, "Bob", "GET returns updated name")
    Do $$$AssertEquals(tBody."_rev", tRev2, "GET returns new rev")
}

/// <p>AC #2: Create doc, PUT with stale _rev returns 409 conflict.</p>
Method TestUpdateConflict()
{
    ; Create doc
    Set tReqBody = "{""val"":1}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp2/confdoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    Set tRev1 = tBody.rev
    ; Update to get rev2
    Set tUpdateBody = "{""val"":2,""_rev"":""" _ tRev1 _ """}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp2/confdoc", .tStatus, .tBody, tUpdateBody)
    Do $$$AssertEquals(tStatus, 201, "First update succeeds")
    ; Now try to update with stale rev1
    Set tStaleBody = "{""val"":3,""_rev"":""" _ tRev1 _ """}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp2/confdoc", .tStatus, .tBody, tStaleBody)
    Do $$$AssertStatusOK(tSC, "PUT with stale rev request completed")
    Do $$$AssertEquals(tStatus, 409, "PUT with stale _rev returns HTTP 409")
    Do $$$AssertEquals(tBody.error, "conflict", "Error slug is conflict")
}

/// <p>AC #3: Create doc, DELETE with rev returns 200, GET returns 404.</p>
Method TestDeleteDocument()
{
    ; Create doc
    Set tReqBody = "{""item"":""pen""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp2/deldoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    Set tRev1 = tBody.rev
    ; DELETE with correct rev
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testdochttp2/deldoc?rev=" _ tRev1, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "DELETE request completed")
    Do $$$AssertEquals(tStatus, 200, "DELETE returns HTTP 200")
    Do $$$AssertTrue(tBody.ok, "Response has ok: true")
    Do $$$AssertEquals(tBody.id, "deldoc", "Response id matches")
    Do $$$AssertEquals($Piece(tBody.rev, "-", 1), 2, "Tombstone rev is generation 2")
    ; GET should now return 404
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testdochttp2/deldoc", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 404, "GET deleted doc returns HTTP 404")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found")
}

/// <p>AC #4: Create doc, PUT with _deleted:true and valid _rev returns 200.</p>
Method TestDeleteViaPut()
{
    ; Create doc
    Set tReqBody = "{""color"":""blue""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp2/delputtdoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    Set tRev1 = tBody.rev
    ; DELETE via PUT with _deleted:true
    Set tDelBody = "{""_rev"":""" _ tRev1 _ """,""_deleted"":true}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp2/delputtdoc", .tStatus, .tBody, tDelBody)
    Do $$$AssertStatusOK(tSC, "PUT with _deleted:true request completed")
    Do $$$AssertEquals(tStatus, 200, "PUT with _deleted:true returns HTTP 200")
    Do $$$AssertTrue(tBody.ok, "Response has ok: true")
    Do $$$AssertEquals(tBody.id, "delputtdoc", "Response id matches")
    Do $$$AssertEquals($Piece(tBody.rev, "-", 1), 2, "Tombstone rev is generation 2")
    ; GET should now return 404
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testdochttp2/delputtdoc", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 404, "GET deleted doc returns HTTP 404")
}

/// <p>AC #3: DELETE without rev returns 409 conflict.</p>
Method TestDeleteNoRev()
{
    ; Create doc
    Set tReqBody = "{""x"":1}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp2/norevdoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    ; DELETE without rev param
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testdochttp2/norevdoc", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "DELETE without rev request completed")
    Do $$$AssertEquals(tStatus, 409, "DELETE without rev returns HTTP 409")
    Do $$$AssertEquals(tBody.error, "conflict", "Error slug is conflict")
}

/// <p>AC #5: PUT with disallowed underscore field returns 400 doc_validation.</p>
Method TestUnderscoreFieldRejected()
{
    Set tReqBody = "{""name"":""test"",""_foo"":""bar""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp2/baddoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "PUT with bad underscore field request completed")
    Do $$$AssertEquals(tStatus, 400, "PUT with _foo returns HTTP 400")
    Do $$$AssertEquals(tBody.error, "doc_validation", "Error slug is doc_validation")
    Do $$$AssertTrue(tBody.reason [ "_foo", "Reason mentions the bad field")
}

}
