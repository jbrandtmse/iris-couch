/// <p>HTTP integration tests for IRISCouch revision tree query parameters.</p>
/// <p>Tests <code>GET /{db}/{docid}</code> with <code>?conflicts=true</code>,
/// <code>?revs=true</code>, <code>?revs_info=true</code>, <code>?open_revs=all</code>,
/// and <code>?open_revs=["rev"]</code> via live HTTP requests.
/// Covers AC #2, #3, #4, #5, #6.</p>
Class IRISCouch.Test.RevTreeHttpTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testrevhttp")
    Kill ^IRISCouch.Docs("testrevhttp")
    Kill ^IRISCouch.Tree("testrevhttp")
    Kill ^IRISCouch.Changes("testrevhttp")
    Kill ^IRISCouch.Seq("testrevhttp")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testrevhttp")
    Quit tSC
}

/// <p>Delete test database and kill all globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testrevhttp")
    Kill ^IRISCouch.Docs("testrevhttp")
    Kill ^IRISCouch.Tree("testrevhttp")
    Kill ^IRISCouch.Changes("testrevhttp")
    Kill ^IRISCouch.Seq("testrevhttp")
    Quit $$$OK
}

/// <p>AC #2: GET ?conflicts=true returns _conflicts array (empty when no conflicts).</p>
Method TestConflictsParam()
{
    ; Create a doc
    Set tReqBody = "{""name"":""Alice""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testrevhttp/cdoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    Set tRev1 = tBody.rev
    ; Update the doc to create rev2
    Set tReqBody2 = "{""name"":""Alice Updated"",""_rev"":""" _ tRev1 _ """}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testrevhttp/cdoc", .tStatus, .tBody, tReqBody2)
    Do $$$AssertEquals(tStatus, 201, "PUT updates document")
    ; GET with ?conflicts=true — no conflicts since sequential update
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testrevhttp/cdoc?conflicts=true", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with conflicts=true completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns 200")
    Do $$$AssertTrue($IsObject(tBody."_conflicts"), "_conflicts array present")
    Do $$$AssertEquals(tBody."_conflicts".%Size(), 0, "_conflicts is empty for sequential updates")
}

/// <p>AC #3: GET ?revs=true returns _revisions with start and ids.</p>
Method TestRevsParam()
{
    ; Create a doc
    Set tReqBody = "{""color"":""red""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testrevhttp/rvdoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    Set tRev1 = tBody.rev
    ; Update the doc
    Set tReqBody2 = "{""color"":""blue"",""_rev"":""" _ tRev1 _ """}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testrevhttp/rvdoc", .tStatus, .tBody, tReqBody2)
    Do $$$AssertEquals(tStatus, 201, "PUT updates document")
    Set tRev2 = tBody.rev
    ; GET with ?revs=true
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testrevhttp/rvdoc?revs=true", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with revs=true completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns 200")
    Set tRevisions = tBody."_revisions"
    Do $$$AssertTrue($IsObject(tRevisions), "_revisions object present")
    Do $$$AssertEquals(tRevisions.start, 2, "_revisions.start is 2")
    Do $$$AssertEquals(tRevisions.ids.%Size(), 2, "_revisions.ids has 2 entries")
}

/// <p>AC #4: GET ?revs_info=true returns _revs_info array with available status.</p>
Method TestRevsInfoParam()
{
    ; Create a doc
    Set tReqBody = "{""item"":""pen""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testrevhttp/ridoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    ; GET with ?revs_info=true
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testrevhttp/ridoc?revs_info=true", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with revs_info=true completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns 200")
    Set tRevsInfo = tBody."_revs_info"
    Do $$$AssertTrue($IsObject(tRevsInfo), "_revs_info array present")
    Do $$$AssertTrue(tRevsInfo.%Size() >= 1, "_revs_info has at least 1 entry")
    Set tFirst = tRevsInfo.%Get(0)
    Do $$$AssertEquals(tFirst.status, "available", "First rev status is available")
    Do $$$AssertTrue(tFirst.rev '= "", "First rev has non-empty rev string")
}

/// <p>AC #5: GET ?open_revs=all returns JSON array with one ok entry.</p>
Method TestOpenRevsAll()
{
    ; Create a doc
    Set tReqBody = "{""data"":""test""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testrevhttp/ordoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    ; GET with ?open_revs=all
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testrevhttp/ordoc?open_revs=all", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with open_revs=all completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns 200")
    ; Response should be a JSON array
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON array")
    Do $$$AssertEquals(tBody.%Size(), 1, "Array has 1 entry for single-leaf doc")
    Set tEntry = tBody.%Get(0)
    Do $$$AssertTrue($IsObject(tEntry.ok), "Entry has ok field with doc object")
    Do $$$AssertEquals(tEntry.ok."_id", "ordoc", "ok doc has correct _id")
}

/// <p>AC #6: GET ?open_revs=["rev"] returns ok for existing, missing for non-existent.</p>
Method TestOpenRevsSpecific()
{
    ; Create a doc
    Set tReqBody = "{""val"":42}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testrevhttp/osdoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    Set tRev1 = tBody.rev
    ; GET with specific existing rev
    Set tOpenRevs = "[""" _ tRev1 _ """]"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testrevhttp/osdoc?open_revs=" _ tOpenRevs, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with open_revs=[existing] completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON array")
    Do $$$AssertEquals(tBody.%Size(), 1, "Array has 1 entry")
    Do $$$AssertTrue($IsObject(tBody.%Get(0).ok), "Entry has ok field")
    ; GET with non-existent rev
    Set tBadRevs = "[""99-badrevnotexist00000000000000000""]"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testrevhttp/osdoc?open_revs=" _ tBadRevs, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with open_revs=[bad-rev] completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns 200")
    Do $$$AssertEquals(tBody.%Size(), 1, "Array has 1 entry")
    Do $$$AssertEquals(tBody.%Get(0).missing, "99-badrevnotexist00000000000000000", "Entry has missing field with rev string")
}

}
