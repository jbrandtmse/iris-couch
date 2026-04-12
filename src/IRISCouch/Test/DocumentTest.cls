/// <p>Unit tests for IRISCouch document storage, revision tree, revision hash,
/// and document engine operations.</p>
/// <p>Tests <class>IRISCouch.Storage.Document</class>, <class>IRISCouch.Storage.RevTree</class>,
/// <class>IRISCouch.Core.RevHash</class>, and <class>IRISCouch.Core.DocumentEngine</class>.
/// Covers AC #1, #2, #3, #4, #5.</p>
Class IRISCouch.Test.DocumentTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testdocdb")
    Kill ^IRISCouch.Docs("testdocdb")
    Kill ^IRISCouch.Tree("testdocdb")
    Kill ^IRISCouch.Changes("testdocdb")
    Kill ^IRISCouch.Seq("testdocdb")
    ; Create fresh test database
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

/// <p>AC #1/#2: RevHash.Generate returns 32-char lowercase hex.</p>
Method TestRevHashGenerate()
{
    Set tBody = "{""name"":""test""}"
    Set tHash = ##class(IRISCouch.Core.RevHash).Generate(tBody)
    Do $$$AssertTrue(tHash '= "", "Generate returns non-empty hash")
    Do $$$AssertEquals($Length(tHash), 32, "Hash is 32 characters long")
    ; Verify all characters are lowercase hex
    Set tValid = 1
    For tI = 1:1:$Length(tHash) {
        Set tChar = $Extract(tHash, tI)
        If "0123456789abcdef" '[ tChar {
            Set tValid = 0
            Quit
        }
    }
    Do $$$AssertTrue(tValid, "Hash contains only lowercase hex characters")
}

/// <p>AC #1/#2: Same body + parent produces same hash; different body produces different hash.</p>
Method TestRevHashDeterministic()
{
    Set tBody1 = "{""name"":""test""}"
    Set tBody2 = "{""name"":""other""}"
    ; Same input -> same output
    Set tHash1a = ##class(IRISCouch.Core.RevHash).Generate(tBody1)
    Set tHash1b = ##class(IRISCouch.Core.RevHash).Generate(tBody1)
    Do $$$AssertEquals(tHash1a, tHash1b, "Same body produces same hash")
    ; Different body -> different hash
    Set tHash2 = ##class(IRISCouch.Core.RevHash).Generate(tBody2)
    Do $$$AssertNotEquals(tHash1a, tHash2, "Different body produces different hash")
    ; Same body with different parent -> different hash
    Set tHash3 = ##class(IRISCouch.Core.RevHash).Generate(tBody1, "1-abc123")
    Do $$$AssertNotEquals(tHash1a, tHash3, "Same body with different parent produces different hash")
}

/// <p>AC #1/#2: MintRev returns format N-hash.</p>
Method TestMintRev()
{
    Set tBody = "{""name"":""test""}"
    Set tRev = ##class(IRISCouch.Core.RevHash).MintRev(1, tBody)
    Do $$$AssertTrue(tRev '= "", "MintRev returns non-empty string")
    ; Verify format: N-hash
    Set tGen = $Piece(tRev, "-", 1)
    Set tHash = $Piece(tRev, "-", 2)
    Do $$$AssertEquals(tGen, 1, "Generation is 1")
    Do $$$AssertEquals($Length(tHash), 32, "Hash part is 32 characters")
    ; Generation 2
    Set tRev2 = ##class(IRISCouch.Core.RevHash).MintRev(2, tBody, tRev)
    Set tGen2 = $Piece(tRev2, "-", 1)
    Do $$$AssertEquals(tGen2, 2, "Generation 2 is in rev string")
}

/// <p>AC #3: Write doc body, read it back, verify identical.</p>
Method TestDocumentWrite()
{
    Set tBody = "{""name"":""Alice"",""age"":30}"
    Set tSC = ##class(IRISCouch.Storage.Document).Write("testdocdb", "doc1", "1-abc", tBody)
    Do $$$AssertStatusOK(tSC, "Write returns OK status")
    ; Read it back
    Set tReadBody = ##class(IRISCouch.Storage.Document).Read("testdocdb", "doc1", "1-abc")
    Do $$$AssertEquals(tReadBody, tBody, "Read returns identical body")
}

/// <p>AC #3: Write doc, verify Exists returns 1; non-existent returns 0.</p>
Method TestDocumentExists()
{
    ; Non-existent
    Do $$$AssertTrue('##class(IRISCouch.Storage.Document).Exists("testdocdb", "nope"), "Non-existent doc returns 0")
    ; Write and verify exists
    Set tSC = ##class(IRISCouch.Storage.Document).Write("testdocdb", "doc1", "1-abc", "{""x"":1}")
    Do $$$AssertStatusOK(tSC, "Write succeeds")
    Do $$$AssertTrue(##class(IRISCouch.Storage.Document).Exists("testdocdb", "doc1"), "Existing doc returns 1")
}

/// <p>AC #1: Init tree, verify winner, leaf node, R node all correct.</p>
Method TestRevTreeInit()
{
    Set tRev = "1-abcdef1234567890abcdef1234567890"
    Set tSC = ##class(IRISCouch.Storage.RevTree).Init("testdocdb", "doc1", tRev)
    Do $$$AssertStatusOK(tSC, "Init returns OK status")
    ; Verify R node (parent pointer is empty for root)
    Do $$$AssertEquals($Get(^IRISCouch.Tree("testdocdb", "doc1", "R", tRev)), "", "R node has empty parent")
    ; Verify L node (leaf at depth 1)
    Do $$$AssertEquals($Get(^IRISCouch.Tree("testdocdb", "doc1", "L", tRev)), 1, "L node has depth 1")
    ; Verify W node (winner)
    Do $$$AssertEquals(##class(IRISCouch.Storage.RevTree).GetWinner("testdocdb", "doc1"), tRev, "Winner is the initial rev")
}

/// <p>AC #1/#2/#5: Save a new doc, verify body, rev tree, doc_count, update_seq, changes.</p>
Method TestDocumentEngineSave()
{
    Set tBody = "{""name"":""Bob""}"
    Set tDocId = "mydoc"
    Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).Save("testdocdb", tDocId, tBody)
    Do $$$AssertTrue(tNewRev '= "", "Save returns non-empty revision")
    ; Verify format
    Do $$$AssertEquals($Piece(tNewRev, "-", 1), 1, "Generation is 1")
    ; Verify body in global
    Set tStoredBody = ##class(IRISCouch.Storage.Document).Read("testdocdb", tDocId, tNewRev)
    Do $$$AssertEquals(tStoredBody, tBody, "Stored body matches input")
    ; Verify rev tree initialized
    Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner("testdocdb", tDocId)
    Do $$$AssertEquals(tWinner, tNewRev, "Winner matches returned rev")
    ; Verify doc_count incremented
    Do $$$AssertEquals(+$Get(^IRISCouch.DB("testdocdb", "doc_count")), 1, "doc_count is 1")
    ; Verify update_seq set
    Set tSeq = +$Get(^IRISCouch.DB("testdocdb", "update_seq"))
    Do $$$AssertTrue(tSeq > 0, "update_seq is greater than 0")
    ; Verify changes feed entry
    Set tChangeEntry = $Get(^IRISCouch.Changes("testdocdb", tSeq))
    Do $$$AssertTrue(tChangeEntry '= "", "Changes feed entry exists")
    Do $$$AssertEquals($ListGet(tChangeEntry, 1), tDocId, "Changes entry has doc ID")
    Do $$$AssertEquals($ListGet(tChangeEntry, 2), tNewRev, "Changes entry has rev")
}

/// <p>AC #5: Verify all changes are atomic after save.</p>
Method TestDocumentEngineSaveTransaction()
{
    Set tBody = "{""data"":""atomic""}"
    Set tDocId = "atomdoc"
    Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).Save("testdocdb", tDocId, tBody)
    Do $$$AssertTrue(tNewRev '= "", "Save returns non-empty revision")
    ; After successful save, all globals should be set atomically
    ; Check all parts exist
    Set tBodyStored = ##class(IRISCouch.Storage.Document).Read("testdocdb", tDocId, tNewRev)
    Do $$$AssertTrue(tBodyStored '= "", "Document body is stored")
    Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner("testdocdb", tDocId)
    Do $$$AssertTrue(tWinner '= "", "Rev tree winner is set")
    Set tSeq = +$Get(^IRISCouch.DB("testdocdb", "update_seq"))
    Do $$$AssertTrue(tSeq > 0, "update_seq is set")
    Set tDocCount = +$Get(^IRISCouch.DB("testdocdb", "doc_count"))
    Do $$$AssertEquals(tDocCount, 1, "doc_count is incremented")
    Set tChangeEntry = $Get(^IRISCouch.Changes("testdocdb", tSeq))
    Do $$$AssertTrue(tChangeEntry '= "", "Changes feed entry is written")
}

/// <p>AC #1: Save to non-existent database returns empty string.</p>
Method TestDocumentEngineSaveNoDb()
{
    Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).Save("nonexistentdb", "doc1", "{""x"":1}")
    Do $$$AssertEquals(tNewRev, "", "Save to non-existent db returns empty string")
}

/// <p>AC #1/#2: RevHash strips _id, _rev, _revisions, _deleted before hashing.</p>
Method TestRevHashStripsMetadata()
{
    Set tBodyClean = "{""name"":""test""}"
    Set tBodyWithMeta = "{""_id"":""abc"",""_rev"":""1-xyz"",""name"":""test""}"
    Set tHash1 = ##class(IRISCouch.Core.RevHash).Generate(tBodyClean)
    Set tHash2 = ##class(IRISCouch.Core.RevHash).Generate(tBodyWithMeta)
    Do $$$AssertEquals(tHash1, tHash2, "Hash is the same after stripping metadata fields")
}

}
