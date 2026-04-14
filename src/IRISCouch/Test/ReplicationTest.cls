/// <p>Unit tests for IRISCouch replication-format bulk writes.</p>
/// <p>Tests <method>DocumentEngine.SaveWithHistory</method> and
/// <method>RevTree.GraftChain</method> for <code>new_edits=false</code>
/// semantics. Covers AC #1-#4.</p>
Class IRISCouch.Test.ReplicationTest Extends %UnitTest.TestCase
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
    ; Clean up any previous test data
    Kill ^IRISCouch.DB("testrepldb")
    Kill ^IRISCouch.Docs("testrepldb")
    Kill ^IRISCouch.Tree("testrepldb")
    Kill ^IRISCouch.Changes("testrepldb")
    Kill ^IRISCouch.Seq("testrepldb")
    ; Create fresh test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testrepldb")
    Quit tSC
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testrepldb")
    Kill ^IRISCouch.Docs("testrepldb")
    Kill ^IRISCouch.Tree("testrepldb")
    Kill ^IRISCouch.Changes("testrepldb")
    Kill ^IRISCouch.Seq("testrepldb")
    Quit $$$OK
}

/// <p>AC #1, #3: Save a doc with rev "3-abc" and revisions {start:3, ids:["abc","def","ghi"]}.
/// Verify body stored, tree has 3 R-nodes, leaf at depth 3, winner is "3-abc".</p>
Method TestSaveWithHistoryNew()
{
    ; Build _revisions object
    Set tRevisions = {}
    Do tRevisions.%Set("start", 3, "number")
    Set tIds = []
    Do tIds.%Push("abc")
    Do tIds.%Push("def")
    Do tIds.%Push("ghi")
    Do tRevisions.%Set("ids", tIds)
    ; Call SaveWithHistory
    Set tSC = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory("testrepldb", "doc1", "{""name"":""Alice""}", "3-abc", tRevisions)
    Do $$$AssertStatusOK(tSC, "SaveWithHistory returns OK for new doc")
    ; Verify body stored at leaf rev
    Set tBody = ##class(IRISCouch.Storage.Document).Read("testrepldb", "doc1", "3-abc")
    Do $$$AssertTrue(tBody '= "", "Body stored for leaf rev 3-abc")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.name, "Alice", "Stored body has correct content")
    ; Verify tree has 3 R-nodes
    Do $$$AssertTrue($Data(^IRISCouch.Tree("testrepldb", "doc1", "R", "1-ghi")) > 0, "R-node exists for 1-ghi")
    Do $$$AssertTrue($Data(^IRISCouch.Tree("testrepldb", "doc1", "R", "2-def")) > 0, "R-node exists for 2-def")
    Do $$$AssertTrue($Data(^IRISCouch.Tree("testrepldb", "doc1", "R", "3-abc")) > 0, "R-node exists for 3-abc")
    ; Verify parent pointers
    Do $$$AssertEquals($Get(^IRISCouch.Tree("testrepldb", "doc1", "R", "1-ghi")), "", "1-ghi has no parent (root)")
    Do $$$AssertEquals($Get(^IRISCouch.Tree("testrepldb", "doc1", "R", "2-def")), "1-ghi", "2-def parent is 1-ghi")
    Do $$$AssertEquals($Get(^IRISCouch.Tree("testrepldb", "doc1", "R", "3-abc")), "2-def", "3-abc parent is 2-def")
    ; Verify leaf at depth 3
    Do $$$AssertEquals(+$Get(^IRISCouch.Tree("testrepldb", "doc1", "L", "3-abc")), 3, "Leaf 3-abc at depth 3")
    ; Verify winner is 3-abc
    Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner("testrepldb", "doc1")
    Do $$$AssertEquals(tWinner, "3-abc", "Winner is 3-abc")
    ; Verify doc_count incremented (new doc)
    Do $$$AssertEquals(+$Get(^IRISCouch.DB("testrepldb", "doc_count")), 1, "doc_count is 1 for new doc")
}

/// <p>AC #2: Create a doc normally (rev 1-xxx -> 2-yyy), then graft a new branch via
/// SaveWithHistory from the same root, verify both leaves exist, correct winner.</p>
Method TestSaveWithHistoryExisting()
{
    ; Create doc normally — creates rev 1-xxx
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testrepldb", "doc2", "{""v"":1}")
    Do $$$AssertTrue(tRev1 '= "", "Normal doc created with rev1")
    Do $$$AssertEquals($Piece(tRev1, "-", 1), 1, "Rev1 is generation 1")
    ; Update doc to create local chain: 1-xxx -> 2-yyy
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testrepldb", "doc2", "{""v"":2}", tRev1)
    Do $$$AssertTrue(tRev2 '= "", "Normal doc updated to rev2")
    Do $$$AssertEquals($Piece(tRev2, "-", 1), 2, "Rev2 is generation 2")
    ; Get the hash from the local root rev
    Set tLocalHash = $Piece(tRev1, "-", 2)
    ; Now graft a conflicting branch from same root: 1-localHash -> 2-remotebranch
    ; This creates a branch that diverges at the root
    Set tRevisions = {}
    Do tRevisions.%Set("start", 2, "number")
    Set tIds = []
    Do tIds.%Push("remotebranch")
    Do tIds.%Push(tLocalHash)
    Do tRevisions.%Set("ids", tIds)
    Set tSC = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory("testrepldb", "doc2", "{""v"":3}", "2-remotebranch", tRevisions)
    Do $$$AssertStatusOK(tSC, "SaveWithHistory grafts branch successfully")
    ; Verify both leaves exist (2-yyy local and 2-remotebranch remote)
    Set tLeaves = ##class(IRISCouch.Storage.RevTree).GetLeafRevs("testrepldb", "doc2")
    Do $$$AssertEquals(tLeaves.%Size(), 2, "Two leaf revisions exist after graft")
    ; Verify winner is determined correctly (same depth, lex tiebreak)
    Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner("testrepldb", "doc2")
    Do $$$AssertTrue(tWinner '= "", "Winner is computed after graft")
    ; Verify doc_count did NOT increment (existing doc)
    Do $$$AssertEquals(+$Get(^IRISCouch.DB("testrepldb", "doc_count")), 1, "doc_count still 1 for existing doc")
}

/// <p>AC #4: Call SaveWithHistory twice with same rev, verify second call is a no-op.</p>
Method TestSaveWithHistoryIdempotent()
{
    ; Build _revisions
    Set tRevisions = {}
    Do tRevisions.%Set("start", 2, "number")
    Set tIds = []
    Do tIds.%Push("rev2hash")
    Do tIds.%Push("rev1hash")
    Do tRevisions.%Set("ids", tIds)
    ; First call
    Set tSC = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory("testrepldb", "idempotent-doc", "{""v"":1}", "2-rev2hash", tRevisions)
    Do $$$AssertStatusOK(tSC, "First SaveWithHistory call OK")
    ; Record state after first call
    Set tSeqAfterFirst = +$Get(^IRISCouch.DB("testrepldb", "update_seq"))
    Set tCountAfterFirst = +$Get(^IRISCouch.DB("testrepldb", "doc_count"))
    ; Second call with exact same data
    Set tRevisions2 = {}
    Do tRevisions2.%Set("start", 2, "number")
    Set tIds2 = []
    Do tIds2.%Push("rev2hash")
    Do tIds2.%Push("rev1hash")
    Do tRevisions2.%Set("ids", tIds2)
    Set tSC2 = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory("testrepldb", "idempotent-doc", "{""v"":1}", "2-rev2hash", tRevisions2)
    Do $$$AssertStatusOK(tSC2, "Second SaveWithHistory call OK (no error)")
    ; Verify no change in state
    Set tSeqAfterSecond = +$Get(^IRISCouch.DB("testrepldb", "update_seq"))
    Do $$$AssertEquals(tSeqAfterSecond, tSeqAfterFirst, "update_seq unchanged after idempotent call")
    Set tCountAfterSecond = +$Get(^IRISCouch.DB("testrepldb", "doc_count"))
    Do $$$AssertEquals(tCountAfterSecond, tCountAfterFirst, "doc_count unchanged after idempotent call")
}

/// <p>AC #3 (Story 8.0): SaveWithHistory on _users database triggers password hashing via OnUserDocSave.
/// Verifies that password field is stripped and PBKDF2 metadata is added to the stored document.</p>
Method TestSaveWithHistoryUsersHook()
{
    ; Create _users database
    Kill ^IRISCouch.DB("_users")
    Kill ^IRISCouch.Docs("_users")
    Kill ^IRISCouch.Tree("_users")
    Kill ^IRISCouch.Changes("_users")
    Kill ^IRISCouch.Seq("_users")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("_users")
    Do $$$AssertStatusOK(tSC, "Created _users database")
    ; Build a user doc body with password
    Set tBody = "{""name"":""testuser8"",""password"":""secret"",""roles"":[],""type"":""user""}"
    ; Build revisions object
    Set tRevisions = {}
    Do tRevisions.%Set("start", 1, "number")
    Set tIds = []
    Do tIds.%Push("abc123")
    Do tRevisions.%Set("ids", tIds)
    ; Call SaveWithHistory on _users database
    Set tSC = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory("_users", "org.couchdb.user:testuser8", tBody, "1-abc123", tRevisions, 0)
    Do $$$AssertStatusOK(tSC, "SaveWithHistory on _users returns OK")
    ; Read stored doc back
    Set tStoredBody = ##class(IRISCouch.Storage.Document).Read("_users", "org.couchdb.user:testuser8", "1-abc123")
    Do $$$AssertTrue(tStoredBody '= "", "Stored body is not empty")
    ; Parse and verify password hashing occurred
    Set tParsed = ##class(%DynamicObject).%FromJSON(tStoredBody)
    ; Password field should be stripped
    Do $$$AssertEquals(tParsed.%Get("password"), "", "Password field is stripped from stored doc")
    ; PBKDF2 metadata should be present
    Do $$$AssertEquals(tParsed.%Get("password_scheme"), "pbkdf2", "password_scheme is pbkdf2")
    Do $$$AssertTrue(tParsed.%Get("derived_key") '= "", "derived_key is present")
    Do $$$AssertTrue(tParsed.%Get("salt") '= "", "salt is present")
    Do $$$AssertTrue(tParsed.%Get("iterations") > 0, "iterations is positive")
    ; Clean up _users database and IRIS user
    Set tOrigNS = $Namespace
    Set $Namespace = "%SYS"
    Set tExists = ""
    Do ##class(Security.Users).Exists("testuser8", .tExists)
    If tExists '= "" {
        Do ##class(Security.Users).Delete("testuser8")
    }
    Set $Namespace = tOrigNS
    Kill ^IRISCouch.DB("_users")
    Kill ^IRISCouch.Docs("_users")
    Kill ^IRISCouch.Tree("_users")
    Kill ^IRISCouch.Changes("_users")
    Kill ^IRISCouch.Seq("_users")
}

/// <p>AC #4 (Story 8.0): SaveWithHistory on _users database with pDeleted=1 triggers OnUserDocDelete.
/// Verifies that the IRIS user is removed when a deleted user doc is replicated in.</p>
Method TestSaveWithHistoryUsersDeleteHook()
{
    ; Create _users database
    Kill ^IRISCouch.DB("_users")
    Kill ^IRISCouch.Docs("_users")
    Kill ^IRISCouch.Tree("_users")
    Kill ^IRISCouch.Changes("_users")
    Kill ^IRISCouch.Seq("_users")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("_users")
    Do $$$AssertStatusOK(tSC, "Created _users database")
    ; First, save a user doc (non-deleted) to create the IRIS user
    Set tBody = "{""name"":""testuser8del"",""password"":""secret"",""roles"":[],""type"":""user""}"
    Set tRevisions = {}
    Do tRevisions.%Set("start", 1, "number")
    Set tIds = []
    Do tIds.%Push("rev1hash")
    Do tRevisions.%Set("ids", tIds)
    Set tSC = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory("_users", "org.couchdb.user:testuser8del", tBody, "1-rev1hash", tRevisions, 0)
    Do $$$AssertStatusOK(tSC, "Initial user doc saved via SaveWithHistory")
    ; Verify IRIS user was created
    Set tOrigNS = $Namespace
    Set $Namespace = "%SYS"
    Set tExists = ""
    Do ##class(Security.Users).Exists("testuser8del", .tExists)
    Set $Namespace = tOrigNS
    Do $$$AssertTrue(tExists '= "", "IRIS user testuser8del was created")
    ; Now call SaveWithHistory with pDeleted=1 for the same doc, new rev
    Set tDeleteBody = "{""_deleted"":true}"
    Set tRevisions2 = {}
    Do tRevisions2.%Set("start", 2, "number")
    Set tIds2 = []
    Do tIds2.%Push("rev2hash")
    Do tIds2.%Push("rev1hash")
    Do tRevisions2.%Set("ids", tIds2)
    Set tSC = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory("_users", "org.couchdb.user:testuser8del", tDeleteBody, "2-rev2hash", tRevisions2, 1)
    Do $$$AssertStatusOK(tSC, "Deleted user doc saved via SaveWithHistory")
    ; Verify IRIS user was deleted
    Set $Namespace = "%SYS"
    Set tExists2 = ""
    Do ##class(Security.Users).Exists("testuser8del", .tExists2)
    Set $Namespace = tOrigNS
    Do $$$AssertEquals(tExists2, "", "IRIS user testuser8del was removed after delete")
    ; Clean up _users database
    Kill ^IRISCouch.DB("_users")
    Kill ^IRISCouch.Docs("_users")
    Kill ^IRISCouch.Tree("_users")
    Kill ^IRISCouch.Changes("_users")
    Kill ^IRISCouch.Seq("_users")
}

/// <p>AC #1, #3: Save with _deleted=true, verify D marker set, winner computation correct.</p>
Method TestSaveWithHistoryDeleted()
{
    ; First graft a live branch
    Set tRevisions = {}
    Do tRevisions.%Set("start", 2, "number")
    Set tIds = []
    Do tIds.%Push("livehash")
    Do tIds.%Push("roothash")
    Do tRevisions.%Set("ids", tIds)
    Set tSC = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory("testrepldb", "del-doc", "{""v"":1}", "2-livehash", tRevisions)
    Do $$$AssertStatusOK(tSC, "Live branch grafted OK")
    ; Now graft a deleted branch from same root
    Set tRevisions2 = {}
    Do tRevisions2.%Set("start", 2, "number")
    Set tIds2 = []
    Do tIds2.%Push("deletedhash")
    Do tIds2.%Push("roothash")
    Do tRevisions2.%Set("ids", tIds2)
    Set tSC2 = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory("testrepldb", "del-doc", "{""_deleted"":true}", "2-deletedhash", tRevisions2, 1)
    Do $$$AssertStatusOK(tSC2, "Deleted branch grafted OK")
    ; Verify D marker is set on deleted rev
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).IsDeleted("testrepldb", "del-doc", "2-deletedhash"), "D marker set on deleted rev")
    ; Verify D marker is NOT set on live rev
    Do $$$AssertTrue('##class(IRISCouch.Storage.RevTree).IsDeleted("testrepldb", "del-doc", "2-livehash"), "D marker not set on live rev")
    ; Verify winner is the live branch (live beats deleted)
    Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner("testrepldb", "del-doc")
    Do $$$AssertEquals(tWinner, "2-livehash", "Winner is live branch, not deleted")
}

}
