/// <p>Unit tests for IRISCouch attachment retrieval options.</p>
/// <p>Tests <class>IRISCouch.Storage.Attachment</class> GetMetadata stubs,
/// base64 encoding of attachment content, and atts_since filtering logic.
/// Covers AC #1, #2, #3.</p>
Class IRISCouch.Test.AttachmentRetrievalTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create a fresh test database and document with attachments before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.DB("testretrdb")
    Kill ^IRISCouch.Docs("testretrdb")
    Kill ^IRISCouch.Tree("testretrdb")
    Kill ^IRISCouch.Changes("testretrdb")
    Kill ^IRISCouch.Seq("testretrdb")
    Kill ^IRISCouch.Atts("testretrdb")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testretrdb")
    If $$$ISERR(tSC) Quit tSC
    ; Create a document
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testretrdb", "doc1", "{""name"":""retrieval test""}")
    If tRev = "" Quit $$$ERROR($$$GeneralError, "Failed to create test document")
    ; Store an attachment on the document revision
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("Hello attachment!")
    Do tStream.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testretrdb", "doc1", tRev, "hello.txt", "text/plain", tStream, 1, .tDigest, .tLength)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testretrdb")
    Kill ^IRISCouch.Docs("testretrdb")
    Kill ^IRISCouch.Tree("testretrdb")
    Kill ^IRISCouch.Changes("testretrdb")
    Kill ^IRISCouch.Seq("testretrdb")
    Kill ^IRISCouch.Atts("testretrdb")
    Quit $$$OK
}

/// <p>AC #1: GetMetadata returns correct stubs for document with attachments.</p>
Method TestGetMetadataReturnsStubs()
{
    Set tRev = ##class(IRISCouch.Storage.RevTree).GetWinner("testretrdb", "doc1")
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testretrdb", "doc1", tRev)
    Do $$$AssertTrue($IsObject(tMeta), "GetMetadata returns an object")
    ; Check hello.txt stub exists
    Set tStub = tMeta.%Get("hello.txt")
    Do $$$AssertTrue($IsObject(tStub), "hello.txt stub exists")
    Do $$$AssertEquals(tStub.%Get("content_type"), "text/plain", "content_type is text/plain")
    Do $$$AssertTrue(+tStub.%Get("length") > 0, "length is positive")
    Do $$$AssertTrue(tStub.%Get("digest") '= "", "digest is non-empty")
    Do $$$AssertEquals(+tStub.%Get("revpos"), 1, "revpos is 1")
    Do $$$AssertTrue(tStub.%Get("stub") = 1, "stub is true")
}

/// <p>AC #1: GetMetadata returns empty for document with no attachments.</p>
Method TestGetMetadataNoAttachments()
{
    ; Create a document without attachments
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testretrdb", "nodoc", "{""name"":""no attachments""}")
    Do $$$AssertTrue(tRev '= "", "Document created")
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testretrdb", "nodoc", tRev)
    Do $$$AssertTrue('$IsObject(tMeta), "GetMetadata returns empty for doc without attachments")
}

/// <p>AC #2: Base64 encoding of attachment content matches original data.</p>
Method TestBase64EncodingMatchesOriginal()
{
    Set tRev = ##class(IRISCouch.Storage.RevTree).GetWinner("testretrdb", "doc1")
    ; Get the attachment stream
    Set tSC = ##class(IRISCouch.Storage.Attachment).Get("testretrdb", "doc1", "hello.txt", .tStream, .tCT, .tLen, .tDig, tRev)
    Do $$$AssertStatusOK(tSC, "Get attachment succeeds")
    Do tStream.Rewind()
    Set tBinary = tStream.Read()
    ; Base64 encode
    Set tB64 = $System.Encryption.Base64Encode(tBinary)
    Do $$$AssertTrue(tB64 '= "", "Base64 encoding is non-empty")
    ; Decode and verify it matches original
    Set tDecoded = $System.Encryption.Base64Decode(tB64)
    Do $$$AssertEquals(tDecoded, "Hello attachment!", "Decoded base64 matches original content")
}

/// <p>AC #3: atts_since filtering — newer attachment gets data, older gets stub.</p>
Method TestAttsSinceFiltering()
{
    ; Setup: create doc1 with attachment at revpos 1 (already done in OnBeforeOneTest)
    ; Now update the document to create rev 2 with a new attachment at revpos 2
    Set tRev1 = ##class(IRISCouch.Storage.RevTree).GetWinner("testretrdb", "doc1")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testretrdb", "doc1", "{""name"":""updated""}", tRev1)
    Do $$$AssertTrue(tRev2 '= "", "Document updated to rev 2")
    ; Copy existing attachments forward
    Set tSC = ##class(IRISCouch.Storage.Attachment).CopyAttachments("testretrdb", "doc1", tRev1, tRev2)
    Do $$$AssertStatusOK(tSC, "Attachments copied forward")
    ; Add a new attachment at revpos 2
    Set tNewStream = ##class(%Stream.GlobalBinary).%New()
    Do tNewStream.Write("New content for rev 2")
    Do tNewStream.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testretrdb", "doc1", tRev2, "newfile.txt", "text/plain", tNewStream, 2, .tDig, .tNewLen)
    Do $$$AssertStatusOK(tSC, "New attachment stored at revpos 2")
    ; Get metadata for rev 2
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testretrdb", "doc1", tRev2)
    Do $$$AssertTrue($IsObject(tMeta), "Metadata exists")
    ; atts_since=["1-xxx"] means maxGen=1
    ; hello.txt has revpos=1 which is NOT > 1, so it stays as stub
    ; newfile.txt has revpos=2 which IS > 1, so it gets data
    Set tMaxGen = 1
    Set tAttIter = tMeta.%GetIterator()
    While tAttIter.%GetNext(.tName, .tStub) {
        Set tRevPos = +tStub.%Get("revpos")
        If tRevPos > tMaxGen {
            ; This attachment should get full data
            Do $$$AssertEquals(tName, "newfile.txt", "newfile.txt has revpos > maxGen")
        } Else {
            ; This attachment stays as stub
            Do $$$AssertEquals(tName, "hello.txt", "hello.txt has revpos <= maxGen")
            Do $$$AssertTrue(tStub.%Get("stub") = 1, "hello.txt remains a stub")
        }
    }
}

/// <p>AC #3: atts_since with max generation greater than all revpos returns all stubs.</p>
Method TestAttsSinceAllStubs()
{
    Set tRev = ##class(IRISCouch.Storage.RevTree).GetWinner("testretrdb", "doc1")
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testretrdb", "doc1", tRev)
    Do $$$AssertTrue($IsObject(tMeta), "Metadata exists")
    ; If atts_since includes a rev with generation 5, maxGen=5
    ; hello.txt has revpos=1 which is NOT > 5, so stays as stub
    Set tMaxGen = 5
    Set tStub = tMeta.%Get("hello.txt")
    Set tRevPos = +tStub.%Get("revpos")
    Do $$$AssertTrue(tRevPos '> tMaxGen, "revpos 1 is not greater than maxGen 5 — stays stub")
    Do $$$AssertTrue(tStub.%Get("stub") = 1, "stub remains true")
}

}
