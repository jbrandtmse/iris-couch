/// <p>Unit tests for document update, delete, optimistic concurrency,
/// and underscore field validation operations.</p>
/// <p>Tests <class>IRISCouch.Core.DocumentEngine</class> Save/SaveDeleted,
/// <class>IRISCouch.Storage.RevTree</class> deletion-aware winner,
/// and <class>IRISCouch.API.DocumentHandler</class> field validation.
/// Covers Story 3.2 AC #1-#5.</p>
Class IRISCouch.Test.DocumentUpdateTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testdocdb")
    Kill ^IRISCouch.Docs("testdocdb")
    Kill ^IRISCouch.Tree("testdocdb")
    Kill ^IRISCouch.Changes("testdocdb")
    Kill ^IRISCouch.Seq("testdocdb")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testdocdb")
    Quit tSC
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testdocdb")
    Kill ^IRISCouch.Docs("testdocdb")
    Kill ^IRISCouch.Tree("testdocdb")
    Kill ^IRISCouch.Changes("testdocdb")
    Kill ^IRISCouch.Seq("testdocdb")
    Quit $$$OK
}

/// <p>AC #1: Create doc, update with correct _rev, verify new rev is 2-*, old body still readable.</p>
Method TestDocumentUpdate()
{
    ; Create initial document
    Set tBody1 = "{""name"":""Alice""}"
    Set tDocId = "updatedoc"
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testdocdb", tDocId, tBody1)
    Do $$$AssertTrue(tRev1 '= "", "Initial save returns non-empty revision")
    Do $$$AssertEquals($Piece(tRev1, "-", 1), 1, "Initial rev is generation 1")
    ; Update with correct _rev
    Set tBody2 = "{""name"":""Bob""}"
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testdocdb", tDocId, tBody2, tRev1)
    Do $$$AssertTrue(tRev2 '= "", "Update save returns non-empty revision")
    Do $$$AssertEquals($Piece(tRev2, "-", 1), 2, "Updated rev is generation 2")
    ; Verify new body is stored
    Set tStoredBody = ##class(IRISCouch.Storage.Document).Read("testdocdb", tDocId, tRev2)
    Do $$$AssertEquals(tStoredBody, tBody2, "New body is stored at rev 2")
    ; Verify old body still readable
    Set tOldBody = ##class(IRISCouch.Storage.Document).Read("testdocdb", tDocId, tRev1)
    Do $$$AssertEquals(tOldBody, tBody1, "Old body still readable at rev 1")
    ; Verify winner is updated
    Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner("testdocdb", tDocId)
    Do $$$AssertEquals(tWinner, tRev2, "Winner is the updated rev")
}

/// <p>AC #1: Create doc, update, verify rev tree structure has correct parent chain.</p>
Method TestDocumentUpdateRevTree()
{
    ; Create initial document
    Set tBody1 = "{""x"":1}"
    Set tDocId = "treedoc"
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testdocdb", tDocId, tBody1)
    ; Update
    Set tBody2 = "{""x"":2}"
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testdocdb", tDocId, tBody2, tRev1)
    ; Verify R nodes: rev2 has parent rev1, rev1 has no parent
    Do $$$AssertEquals($Get(^IRISCouch.Tree("testdocdb", tDocId, "R", tRev1)), "", "Rev1 has empty parent (root)")
    Do $$$AssertEquals($Get(^IRISCouch.Tree("testdocdb", tDocId, "R", tRev2)), tRev1, "Rev2 parent is rev1")
    ; Verify leaf: only rev2 is a leaf
    Do $$$AssertTrue('$Data(^IRISCouch.Tree("testdocdb", tDocId, "L", tRev1)), "Rev1 is no longer a leaf")
    Do $$$AssertEquals(+$Get(^IRISCouch.Tree("testdocdb", tDocId, "L", tRev2)), 2, "Rev2 is leaf at depth 2")
    ; Verify winner
    Do $$$AssertEquals(##class(IRISCouch.Storage.RevTree).GetWinner("testdocdb", tDocId), tRev2, "Winner is rev2")
}

/// <p>AC #3: Create doc, delete via SaveDeleted(), verify tombstone body, doc_count, doc_del_count.</p>
Method TestDocumentDelete()
{
    ; Create initial document
    Set tBody = "{""name"":""ToDelete""}"
    Set tDocId = "deldoc"
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testdocdb", tDocId, tBody)
    Do $$$AssertTrue(tRev1 '= "", "Initial save succeeds")
    Do $$$AssertEquals(+$Get(^IRISCouch.DB("testdocdb", "doc_count")), 1, "doc_count is 1 after create")
    ; Delete
    Set tDelRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted("testdocdb", tDocId, tRev1)
    Do $$$AssertTrue(tDelRev '= "", "SaveDeleted returns non-empty revision")
    Do $$$AssertEquals($Piece(tDelRev, "-", 1), 2, "Tombstone rev is generation 2")
    ; Verify tombstone body
    Set tTombBody = ##class(IRISCouch.Storage.Document).Read("testdocdb", tDocId, tDelRev)
    Do $$$AssertEquals(tTombBody, "{""_deleted"":true}", "Tombstone body is correct")
    ; Verify doc_count decremented
    Do $$$AssertEquals(+$Get(^IRISCouch.DB("testdocdb", "doc_count")), 0, "doc_count is 0 after delete")
    ; Verify doc_del_count incremented
    Do $$$AssertEquals(+$Get(^IRISCouch.DB("testdocdb", "doc_del_count")), 1, "doc_del_count is 1 after delete")
    ; Verify deleted marker in tree
    Do $$$AssertEquals(+$Get(^IRISCouch.Tree("testdocdb", tDocId, "D", tDelRev)), 1, "Deleted marker is set")
}

/// <p>AC #3: Verify deleted leaf winner algorithm. Single doc: delete makes tombstone winner.
/// Two leafs (conflict): delete one, non-deleted wins.</p>
Method TestDeletedRevTreeWinner()
{
    ; Create document
    Set tBody = "{""val"":1}"
    Set tDocId = "wintest"
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testdocdb", tDocId, tBody)
    ; Delete it — tombstone is only leaf, must be winner
    Set tDelRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted("testdocdb", tDocId, tRev1)
    Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner("testdocdb", tDocId)
    Do $$$AssertEquals(tWinner, tDelRev, "When only leaf is deleted, tombstone is winner")
    ; Now test with conflict: create second doc with two leafs
    Set tDocId2 = "wintest2"
    Set tBody2 = "{""val"":2}"
    Set tRev2a = ##class(IRISCouch.Core.DocumentEngine).Save("testdocdb", tDocId2, tBody2)
    ; Manually create a conflict by adding another leaf at same depth via RevTree
    Set tConflictBody = "{""val"":3}"
    Set tConflictRev = ##class(IRISCouch.Core.RevHash).MintRev(2, tConflictBody, tRev2a)
    Do ##class(IRISCouch.Storage.Document).Write("testdocdb", tDocId2, tConflictRev, tConflictBody)
    ; Add conflict as leaf but keep parent as leaf too (simulate conflict)
    Set ^IRISCouch.Tree("testdocdb", tDocId2, "R", tConflictRev) = tRev2a
    Set ^IRISCouch.Tree("testdocdb", tDocId2, "L", tConflictRev) = 2
    ; Also keep rev2a as leaf (this is a conflict — both are leaves)
    Set ^IRISCouch.Tree("testdocdb", tDocId2, "L", tRev2a) = 1
    ; Mark conflict rev as deleted
    Set ^IRISCouch.Tree("testdocdb", tDocId2, "D", tConflictRev) = 1
    ; Recompute winner
    Do ##class(IRISCouch.Storage.RevTree).RecomputeWinner("testdocdb", tDocId2)
    Set tWinner2 = ##class(IRISCouch.Storage.RevTree).GetWinner("testdocdb", tDocId2)
    ; Non-deleted leaf (tRev2a) should win over deleted leaf (tConflictRev)
    Do $$$AssertEquals(tWinner2, tRev2a, "Non-deleted leaf wins over deleted leaf")
}

/// <p>AC #5: Verify underscore field validation accepts allowed fields, rejects bad ones.</p>
Method TestUnderscoreFieldValidation()
{
    ; Allowed fields should pass (return empty string)
    Set tBody1 = {"_id":"test", "_rev":"1-abc", "_deleted":true, "_revisions":{}, "_attachments":{}, "name":"ok"}
    Set tResult = ##class(IRISCouch.API.DocumentHandler).ValidateFields(tBody1)
    Do $$$AssertEquals(tResult, "", "All allowed underscore fields pass validation")
    ; Bad field should fail (return field name)
    Set tBody2 = {"name":"test", "_badfield":"evil"}
    Set tResult2 = ##class(IRISCouch.API.DocumentHandler).ValidateFields(tBody2)
    Do $$$AssertEquals(tResult2, "_badfield", "Bad underscore field _badfield is rejected")
    ; Another bad field
    Set tBody3 = {"_conflicts":[]}
    Set tResult3 = ##class(IRISCouch.API.DocumentHandler).ValidateFields(tBody3)
    Do $$$AssertEquals(tResult3, "_conflicts", "Bad underscore field _conflicts is rejected")
    ; No underscore fields should pass
    Set tBody4 = {"name":"clean", "count":42}
    Set tResult4 = ##class(IRISCouch.API.DocumentHandler).ValidateFields(tBody4)
    Do $$$AssertEquals(tResult4, "", "No underscore fields pass validation")
}

}
