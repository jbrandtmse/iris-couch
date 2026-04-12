/// <p>Unit tests for IRISCouch revision tree query methods.</p>
/// <p>Tests <class>IRISCouch.Storage.RevTree</class> methods: AddBranch,
/// GetConflicts, GetRevisions, GetRevsInfo, GetLeafRevs, IsDeleted.
/// Covers AC #1, #2, #3, #4, #5.</p>
Class IRISCouch.Test.RevTreeTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create a fresh test database before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.DB("testrevtreedb")
    Kill ^IRISCouch.Docs("testrevtreedb")
    Kill ^IRISCouch.Tree("testrevtreedb")
    Kill ^IRISCouch.Changes("testrevtreedb")
    Kill ^IRISCouch.Seq("testrevtreedb")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testrevtreedb")
    Quit tSC
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testrevtreedb")
    Kill ^IRISCouch.Docs("testrevtreedb")
    Kill ^IRISCouch.Tree("testrevtreedb")
    Kill ^IRISCouch.Changes("testrevtreedb")
    Kill ^IRISCouch.Seq("testrevtreedb")
    Quit $$$OK
}

/// <p>AC #1: AddBranch creates two leaves from same parent, correct winner computed.</p>
Method TestAddBranch()
{
    Set tDB = "testrevtreedb"
    Set tDocId = "branchdoc"
    Set tRev1 = "1-aaaa0000000000000000000000000000"
    ; Init tree with root revision
    Set tSC = ##class(IRISCouch.Storage.RevTree).Init(tDB, tDocId, tRev1)
    Do $$$AssertStatusOK(tSC, "Init returns OK")
    ; Create two branch revisions from the same parent
    Set tRev2a = "2-bbbb0000000000000000000000000000"
    Set tRev2b = "2-cccc0000000000000000000000000000"
    Set tSC = ##class(IRISCouch.Storage.RevTree).AddBranch(tDB, tDocId, tRev1, tRev2a)
    Do $$$AssertStatusOK(tSC, "AddBranch for rev2a returns OK")
    Set tSC = ##class(IRISCouch.Storage.RevTree).AddBranch(tDB, tDocId, tRev1, tRev2b)
    Do $$$AssertStatusOK(tSC, "AddBranch for rev2b returns OK")
    ; Verify parent is still a leaf (AddBranch does NOT remove parent from leaf index)
    Do $$$AssertTrue(+$Get(^IRISCouch.Tree(tDB, tDocId, "L", tRev1)) > 0, "Parent rev1 is still a leaf")
    ; Verify both children are leaves
    Do $$$AssertTrue(+$Get(^IRISCouch.Tree(tDB, tDocId, "L", tRev2a)) > 0, "Rev2a is a leaf")
    Do $$$AssertTrue(+$Get(^IRISCouch.Tree(tDB, tDocId, "L", tRev2b)) > 0, "Rev2b is a leaf")
    ; Verify depths: children should be at depth 2
    Do $$$AssertEquals(+$Get(^IRISCouch.Tree(tDB, tDocId, "L", tRev2a)), 2, "Rev2a depth is 2")
    Do $$$AssertEquals(+$Get(^IRISCouch.Tree(tDB, tDocId, "L", tRev2b)), 2, "Rev2b depth is 2")
    ; Winner should be the lexicographically highest at same depth: 2-cccc > 2-bbbb
    Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(tDB, tDocId)
    Do $$$AssertEquals(tWinner, tRev2b, "Winner is the lexicographically highest rev at same depth")
}

/// <p>AC #2: GetConflicts returns non-winner, non-deleted leaf revisions.</p>
Method TestGetConflicts()
{
    Set tDB = "testrevtreedb"
    Set tDocId = "conflictdoc"
    Set tRev1 = "1-aaaa0000000000000000000000000000"
    Set tSC = ##class(IRISCouch.Storage.RevTree).Init(tDB, tDocId, tRev1)
    Do $$$AssertStatusOK(tSC, "Init returns OK")
    ; Create branch: two children from same parent
    Set tRev2a = "2-bbbb0000000000000000000000000000"
    Set tRev2b = "2-cccc0000000000000000000000000000"
    Set tSC = ##class(IRISCouch.Storage.RevTree).AddBranch(tDB, tDocId, tRev1, tRev2a)
    Do $$$AssertStatusOK(tSC, "AddBranch rev2a OK")
    Set tSC = ##class(IRISCouch.Storage.RevTree).AddBranch(tDB, tDocId, tRev1, tRev2b)
    Do $$$AssertStatusOK(tSC, "AddBranch rev2b OK")
    ; GetConflicts should return non-winner leaves
    Set tConflicts = ##class(IRISCouch.Storage.RevTree).GetConflicts(tDB, tDocId)
    Do $$$AssertTrue($IsObject(tConflicts), "GetConflicts returns an object")
    ; Winner is 2-cccc, so conflicts should include 1-aaaa and 2-bbbb
    ; (parent rev1 is still a leaf because AddBranch does not remove it)
    Set tFound2a = 0
    Set tFound1 = 0
    For tI = 0:1:(tConflicts.%Size()-1) {
        Set tVal = tConflicts.%Get(tI)
        If tVal = tRev2a Set tFound2a = 1
        If tVal = tRev1 Set tFound1 = 1
    }
    Do $$$AssertTrue(tFound2a, "Conflicts include rev2a (non-winner leaf)")
    Do $$$AssertTrue(tFound1, "Conflicts include rev1 (non-winner leaf)")
}

/// <p>AC #2: GetConflicts returns empty array when no conflicts exist.</p>
Method TestGetConflictsNoConflict()
{
    Set tDB = "testrevtreedb"
    Set tDocId = "singleleaf"
    Set tRev1 = "1-aaaa0000000000000000000000000000"
    Set tSC = ##class(IRISCouch.Storage.RevTree).Init(tDB, tDocId, tRev1)
    Do $$$AssertStatusOK(tSC, "Init returns OK")
    Set tConflicts = ##class(IRISCouch.Storage.RevTree).GetConflicts(tDB, tDocId)
    Do $$$AssertEquals(tConflicts.%Size(), 0, "No conflicts for single-leaf document")
}

/// <p>AC #3: GetRevisions returns start and ids array tracing path to root.</p>
Method TestGetRevisions()
{
    Set tDB = "testrevtreedb"
    Set tDocId = "chaineddoc"
    Set tRev1 = "1-aaaa0000000000000000000000000000"
    Set tRev2 = "2-bbbb0000000000000000000000000000"
    Set tRev3 = "3-cccc0000000000000000000000000000"
    ; Build a chain of 3 revisions
    Set tSC = ##class(IRISCouch.Storage.RevTree).Init(tDB, tDocId, tRev1)
    Do $$$AssertStatusOK(tSC, "Init OK")
    Set tSC = ##class(IRISCouch.Storage.RevTree).AddChild(tDB, tDocId, tRev1, tRev2)
    Do $$$AssertStatusOK(tSC, "AddChild rev2 OK")
    Set tSC = ##class(IRISCouch.Storage.RevTree).AddChild(tDB, tDocId, tRev2, tRev3)
    Do $$$AssertStatusOK(tSC, "AddChild rev3 OK")
    ; GetRevisions from rev3
    Set tRevisions = ##class(IRISCouch.Storage.RevTree).GetRevisions(tDB, tDocId, tRev3)
    Do $$$AssertTrue($IsObject(tRevisions), "GetRevisions returns object")
    Do $$$AssertEquals(tRevisions.start, 3, "start is 3")
    Set tIds = tRevisions.ids
    Do $$$AssertEquals(tIds.%Size(), 3, "ids array has 3 entries")
    Do $$$AssertEquals(tIds.%Get(0), "cccc0000000000000000000000000000", "First id is rev3 hash")
    Do $$$AssertEquals(tIds.%Get(1), "bbbb0000000000000000000000000000", "Second id is rev2 hash")
    Do $$$AssertEquals(tIds.%Get(2), "aaaa0000000000000000000000000000", "Third id is rev1 hash")
}

/// <p>AC #4: GetRevsInfo returns status for each revision in chain.</p>
Method TestGetRevsInfo()
{
    Set tDB = "testrevtreedb"
    Set tDocId = "revsinfodoc"
    Set tRev1 = "1-aaaa0000000000000000000000000000"
    Set tRev2 = "2-bbbb0000000000000000000000000000"
    ; Build chain and store bodies
    Set tSC = ##class(IRISCouch.Storage.RevTree).Init(tDB, tDocId, tRev1)
    Do $$$AssertStatusOK(tSC, "Init OK")
    Set tSC = ##class(IRISCouch.Storage.Document).Write(tDB, tDocId, tRev1, "{""v"":1}")
    Do $$$AssertStatusOK(tSC, "Write rev1 body OK")
    Set tSC = ##class(IRISCouch.Storage.RevTree).AddChild(tDB, tDocId, tRev1, tRev2)
    Do $$$AssertStatusOK(tSC, "AddChild rev2 OK")
    Set tSC = ##class(IRISCouch.Storage.Document).Write(tDB, tDocId, tRev2, "{""v"":2}")
    Do $$$AssertStatusOK(tSC, "Write rev2 body OK")
    ; GetRevsInfo from rev2
    Set tRevsInfo = ##class(IRISCouch.Storage.RevTree).GetRevsInfo(tDB, tDocId, tRev2)
    Do $$$AssertTrue($IsObject(tRevsInfo), "GetRevsInfo returns object")
    Do $$$AssertEquals(tRevsInfo.%Size(), 2, "RevsInfo has 2 entries")
    ; First entry is rev2, should be available
    Set tInfo0 = tRevsInfo.%Get(0)
    Do $$$AssertEquals(tInfo0.rev, tRev2, "First entry is rev2")
    Do $$$AssertEquals(tInfo0.status, "available", "Rev2 status is available")
    ; Second entry is rev1, should be available
    Set tInfo1 = tRevsInfo.%Get(1)
    Do $$$AssertEquals(tInfo1.rev, tRev1, "Second entry is rev1")
    Do $$$AssertEquals(tInfo1.status, "available", "Rev1 status is available")
}

/// <p>AC #5: GetLeafRevs returns all leaf revisions including branches.</p>
Method TestGetLeafRevs()
{
    Set tDB = "testrevtreedb"
    Set tDocId = "leafdoc"
    Set tRev1 = "1-aaaa0000000000000000000000000000"
    Set tSC = ##class(IRISCouch.Storage.RevTree).Init(tDB, tDocId, tRev1)
    Do $$$AssertStatusOK(tSC, "Init OK")
    ; Create two branches from the same parent
    Set tRev2a = "2-bbbb0000000000000000000000000000"
    Set tRev2b = "2-cccc0000000000000000000000000000"
    Set tSC = ##class(IRISCouch.Storage.RevTree).AddBranch(tDB, tDocId, tRev1, tRev2a)
    Do $$$AssertStatusOK(tSC, "AddBranch rev2a OK")
    Set tSC = ##class(IRISCouch.Storage.RevTree).AddBranch(tDB, tDocId, tRev1, tRev2b)
    Do $$$AssertStatusOK(tSC, "AddBranch rev2b OK")
    ; GetLeafRevs should return all 3 leaves (parent + 2 children)
    Set tLeaves = ##class(IRISCouch.Storage.RevTree).GetLeafRevs(tDB, tDocId)
    Do $$$AssertEquals(tLeaves.%Size(), 3, "GetLeafRevs returns 3 leaves")
}

}
