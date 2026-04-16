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

/// <p>Story 11.4 Task 1: GET with combined ?revs_info=true&conflicts=true&deleted_conflicts=true
/// returns a full tree snapshot in one call for the revision-history UI.</p>
/// <p>Sets up a 3-rev linear chain plus one conflict branch (live) plus one deleted
/// conflict branch, then verifies the combined GET response contains:
/// <ul>
/// <li><code>_revs_info</code> — the winning ancestor chain (3 entries: 3-winner, 2-mid, 1-base)</li>
/// <li><code>_conflicts</code> — a single live conflict leaf</li>
/// <li><code>_deleted_conflicts</code> — a single deleted conflict leaf</li>
/// </ul></p>
Method TestRevisionTreeCombinedQuery()
{
    ; Create base rev 1-base
    Set tReqBody = "{""v"":1}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testrevhttp/tree1", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document rev 1")
    Set tRev1 = tBody.rev
    ; Update to rev 2 (linear)
    Set tReqBody = "{""v"":2,""_rev"":""" _ tRev1 _ """}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testrevhttp/tree1", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT rev 2 linear update")
    Set tRev2 = tBody.rev
    ; Update to rev 3 (linear winner)
    Set tReqBody = "{""v"":3,""_rev"":""" _ tRev2 _ """}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testrevhttp/tree1", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT rev 3 linear winner")
    Set tRev3 = tBody.rev
    ; Force a live conflict branch at depth 2
    Set tConflictRev = "2-aaaaconflictbranch"
    Set tSC2 = ##class(IRISCouch.Storage.RevTree).AddBranch("testrevhttp", "tree1", tRev1, tConflictRev)
    Do $$$AssertStatusOK(tSC2, "Added live conflict branch")
    Set tSC3 = ##class(IRISCouch.Storage.Document).Write("testrevhttp", "tree1", tConflictRev, "{""v"":""conflict""}")
    Do $$$AssertStatusOK(tSC3, "Wrote live conflict body")
    ; Force a deleted conflict branch at depth 2
    Set tDeletedRev = "2-bbbbdeletedbranch"
    Set tSC4 = ##class(IRISCouch.Storage.RevTree).AddBranch("testrevhttp", "tree1", tRev1, tDeletedRev)
    Do $$$AssertStatusOK(tSC4, "Added deleted conflict branch")
    Set tSC5 = ##class(IRISCouch.Storage.RevTree).MarkDeleted("testrevhttp", "tree1", tDeletedRev)
    Do $$$AssertStatusOK(tSC5, "Marked deleted branch")
    Set tSC6 = ##class(IRISCouch.Storage.Document).Write("testrevhttp", "tree1", tDeletedRev, "{""_deleted"":true}")
    Do $$$AssertStatusOK(tSC6, "Wrote deleted body")
    ; Recompute winner just in case
    Do ##class(IRISCouch.Storage.RevTree).RecomputeWinner("testrevhttp", "tree1")
    ; GET with all three query params combined
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testrevhttp/tree1?revs_info=true&conflicts=true&deleted_conflicts=true", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET combined request completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns 200")
    ; Winner is rev 3 (highest depth among live leaves)
    Do $$$AssertEquals(tBody."_rev", tRev3, "Winner _rev is rev 3")
    ; _revs_info covers the winner's 3-deep ancestor chain
    Set tRevsInfo = tBody."_revs_info"
    Do $$$AssertTrue($IsObject(tRevsInfo), "_revs_info present")
    Do $$$AssertEquals(tRevsInfo.%Size(), 3, "_revs_info has 3 entries (winning chain depth 3)")
    ; _conflicts has one live conflict leaf
    Set tConflicts = tBody."_conflicts"
    Do $$$AssertTrue($IsObject(tConflicts), "_conflicts present")
    Do $$$AssertEquals(tConflicts.%Size(), 1, "_conflicts has 1 entry")
    Do $$$AssertEquals(tConflicts.%Get(0), tConflictRev, "_conflicts entry is the live branch rev")
    ; _deleted_conflicts has one deleted leaf
    Set tDeleted = tBody."_deleted_conflicts"
    Do $$$AssertTrue($IsObject(tDeleted), "_deleted_conflicts present")
    Do $$$AssertEquals(tDeleted.%Size(), 1, "_deleted_conflicts has 1 entry")
    Do $$$AssertEquals(tDeleted.%Get(0), tDeletedRev, "_deleted_conflicts entry is the deleted branch rev")
}

/// <p>Story 11.4 Task 1: GET ?deleted_conflicts=true on a doc with no deleted leaves
/// returns an empty array (contract check for the UI).</p>
Method TestDeletedConflictsEmpty()
{
    Set tReqBody = "{""x"":1}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testrevhttp/nodeleted", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates doc")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testrevhttp/nodeleted?deleted_conflicts=true", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "GET returns 200")
    Set tDeleted = tBody."_deleted_conflicts"
    Do $$$AssertTrue($IsObject(tDeleted), "_deleted_conflicts present")
    Do $$$AssertEquals(tDeleted.%Size(), 0, "_deleted_conflicts is empty for simple doc")
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
