/// <p>HTTP integration tests for IRISCouch <code>POST /{db}/_revs_diff</code> endpoint.</p>
/// <p>Tests the full request/response cycle via live HTTP requests against
/// the running webapp at <code>/iris-couch/</code>. Validates routing,
/// JSON serialization, missing-revision detection, possible_ancestors, and
/// error responses. Covers AC #1-#6 for Story 8.2.</p>
Class IRISCouch.Test.RevsDiffHttpTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("rdhttp")
    Kill ^IRISCouch.Docs("rdhttp")
    Kill ^IRISCouch.Tree("rdhttp")
    Kill ^IRISCouch.Changes("rdhttp")
    Kill ^IRISCouch.Seq("rdhttp")
    Kill ^IRISCouch.Local("rdhttp")
    Kill ^IRISCouch.Proj("rdhttp")
    Kill ^IRISCouch.MangoIdx("rdhttp")
    ; Create the test database directly
    Set tSC = ##class(IRISCouch.Storage.Database).Create("rdhttp")
    Quit tSC
}

/// <p>Clean up test database after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("rdhttp")
    Kill ^IRISCouch.Docs("rdhttp")
    Kill ^IRISCouch.Tree("rdhttp")
    Kill ^IRISCouch.Changes("rdhttp")
    Kill ^IRISCouch.Seq("rdhttp")
    Kill ^IRISCouch.Local("rdhttp")
    Kill ^IRISCouch.Proj("rdhttp")
    Kill ^IRISCouch.MangoIdx("rdhttp")
    Quit $$$OK
}

/// <p>AC #2: POST _revs_diff with all known revisions returns 200 + {}.</p>
Method TestRevsDiffAllExist()
{
    ; Create a document with a known revision
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("rdhttp", "doc1", "{""name"":""test""}")
    Do $$$AssertTrue(tRev1 '= "", "doc1 created with rev")
    ; POST _revs_diff with the known revision
    Set tReqBody = "{""doc1"":[""" _ tRev1 _ """]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/rdhttp/_revs_diff", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _revs_diff request completed")
    Do $$$AssertEquals(tStatus, 200, "POST _revs_diff returns 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    ; Response should be empty — all revs exist
    Do $$$AssertEquals(tBody.%ToJSON(), "{}", "All revs exist — response is {}")
}

/// <p>AC #1: POST _revs_diff with unknown revisions returns 200 + missing array.</p>
Method TestRevsDiffMissing()
{
    ; Create a document with a known revision
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("rdhttp", "doc1", "{""name"":""test""}")
    Do $$$AssertTrue(tRev1 '= "", "doc1 created with rev")
    ; POST _revs_diff with one known and one unknown revision
    Set tFakeRev = "2-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1"
    Set tReqBody = "{""doc1"":[""" _ tRev1 _ """,""" _ tFakeRev _ """]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/rdhttp/_revs_diff", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _revs_diff request completed")
    Do $$$AssertEquals(tStatus, 200, "POST _revs_diff returns 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    ; doc1 should be in response with missing array
    Do $$$AssertTrue(tBody.%IsDefined("doc1"), "doc1 in response")
    Set tDocResult = tBody.%Get("doc1")
    Do $$$AssertTrue($IsObject(tDocResult), "doc1 result is object")
    Set tMissing = tDocResult.%Get("missing")
    Do $$$AssertTrue($IsObject(tMissing), "doc1 has missing array")
    Do $$$AssertEquals(tMissing.%Size(), 1, "Exactly one missing revision")
    Do $$$AssertEquals(tMissing.%Get(0), tFakeRev, "Missing rev is the fake one")
    ; Should have possible_ancestors since doc has a known tree
    Do $$$AssertTrue(tDocResult.%IsDefined("possible_ancestors"), "doc1 has possible_ancestors")
}

/// <p>AC #6: POST _revs_diff on non-existent database returns 404.</p>
Method TestRevsDiffDatabaseNotFound()
{
    Set tReqBody = "{""doc1"":[""1-abc""]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/no-such-db/_revs_diff", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _revs_diff request completed")
    Do $$$AssertEquals(tStatus, 404, "Non-existent DB returns 404")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found")
}

/// <p>AC #5: POST _revs_diff with empty body {} returns 200 + {}.</p>
Method TestRevsDiffEmptyBody()
{
    Set tReqBody = "{}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/rdhttp/_revs_diff", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _revs_diff request completed")
    Do $$$AssertEquals(tStatus, 200, "POST _revs_diff with {} returns 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertEquals(tBody.%ToJSON(), "{}", "Empty body returns {}")
}

/// <p>AC #3: POST with missing revs on doc that has a tree includes possible_ancestors.</p>
Method TestRevsDiffWithAncestors()
{
    ; Create doc with two revisions to build a tree
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("rdhttp", "doc2", "{""v"":1}")
    Do $$$AssertTrue(tRev1 '= "", "doc2 created with rev1")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("rdhttp", "doc2", "{""v"":2}", tRev1)
    Do $$$AssertTrue(tRev2 '= "", "doc2 updated with rev2")
    ; POST _revs_diff with a non-existing revision
    Set tFakeRev = "3-cccccccccccccccccccccccccccccccc"
    Set tReqBody = "{""doc2"":[""" _ tFakeRev _ """]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/rdhttp/_revs_diff", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _revs_diff request completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    ; doc2 should have missing and possible_ancestors
    Do $$$AssertTrue(tBody.%IsDefined("doc2"), "doc2 in response")
    Set tDocResult = tBody.%Get("doc2")
    Set tMissing = tDocResult.%Get("missing")
    Do $$$AssertEquals(tMissing.%Size(), 1, "One missing revision")
    Do $$$AssertEquals(tMissing.%Get(0), tFakeRev, "Missing rev is the fake one")
    ; possible_ancestors should include the current leaf (tRev2)
    Set tAncestors = tDocResult.%Get("possible_ancestors")
    Do $$$AssertTrue($IsObject(tAncestors), "possible_ancestors is array")
    Do $$$AssertTrue(tAncestors.%Size() > 0, "possible_ancestors is non-empty")
    ; Verify that tRev2 is among the ancestors
    Set tFound = 0
    Set tAncIter = tAncestors.%GetIterator()
    While tAncIter.%GetNext(.tIdx, .tVal) {
        If tVal = tRev2 Set tFound = 1
    }
    Do $$$AssertTrue(tFound, "possible_ancestors includes the current leaf revision")
}

}
