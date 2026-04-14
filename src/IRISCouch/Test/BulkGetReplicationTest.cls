/// <p>Unit tests for IRISCouch replication-ready <code>_bulk_get</code> enhancements.</p>
/// <p>Tests <code>revs=true</code>, <code>attachments=true</code>, combined flags,
/// missing document error entries, stub-only defaults, digest preservation,
/// and documents without attachments. Covers AC #1-#6 for Story 8.3.</p>
Class IRISCouch.Test.BulkGetReplicationTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testbgrepl")
    Kill ^IRISCouch.Docs("testbgrepl")
    Kill ^IRISCouch.Tree("testbgrepl")
    Kill ^IRISCouch.Changes("testbgrepl")
    Kill ^IRISCouch.Seq("testbgrepl")
    Kill ^IRISCouch.Atts("testbgrepl")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testbgrepl")
    Quit tSC
}

/// <p>Clean up test database after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testbgrepl")
    Kill ^IRISCouch.Docs("testbgrepl")
    Kill ^IRISCouch.Tree("testbgrepl")
    Kill ^IRISCouch.Changes("testbgrepl")
    Kill ^IRISCouch.Seq("testbgrepl")
    Kill ^IRISCouch.Atts("testbgrepl")
    Quit $$$OK
}

/// <p>Helper: create a document and return the revision string.</p>
ClassMethod CreateDoc(pDocId As %String, pBody As %String, pParentRev As %String = "") As %String
{
    Quit ##class(IRISCouch.Core.DocumentEngine).Save("testbgrepl", pDocId, pBody, pParentRev)
}

/// <p>Helper: store a text attachment on a document revision.</p>
ClassMethod StoreAttachment(pDocId As %String, pRev As %String, pAttName As %String, pContent As %String, pContentType As %String = "text/plain", pRevPos As %Integer = 1, Output pDigest As %String, Output pLength As %Integer) As %Status
{
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write(pContent)
    Do tStream.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testbgrepl", pDocId, pRev, pAttName, pContentType, tStream, pRevPos, .pDigest, .pLength)
    Quit tSC
}

/// <p>Helper: simulate a _bulk_get call directly via HandleBulkGet.
/// Builds a mock %request object with the given body and query params,
/// then calls HandleBulkGet and parses the response from %response.</p>
/// <p>Since unit tests cannot easily mock %request/%response for the handler,
/// we test the underlying storage + attachment logic directly and verify
/// the handler integration via HTTP tests (Task 4).</p>

/// <p>AC #1: revs=true returns _revisions with start and ids array.</p>
Method TestBulkGetRevsTrue()
{
    ; Create a document with two revisions
    Set tRev1 = ..CreateDoc("rdoc1", "{""v"":1}")
    Do $$$AssertTrue(tRev1 '= "", "rdoc1 rev1 created")
    Set tRev2 = ..CreateDoc("rdoc1", "{""v"":2}", tRev1)
    Do $$$AssertTrue(tRev2 '= "", "rdoc1 rev2 created")
    ; Verify GetRevisions returns correct structure
    Set tRevisions = ##class(IRISCouch.Storage.RevTree).GetRevisions("testbgrepl", "rdoc1", tRev2)
    Do $$$AssertTrue($IsObject(tRevisions), "_revisions is an object")
    Do $$$AssertEquals(tRevisions.start, 2, "_revisions.start is 2")
    Set tIds = tRevisions.ids
    Do $$$AssertTrue($IsObject(tIds), "_revisions.ids is an array")
    Do $$$AssertEquals(tIds.%Size(), 2, "_revisions.ids has 2 entries")
    ; First id should be the hash from rev2, second from rev1
    Set tRev2Hash = $Piece(tRev2, "-", 2)
    Set tRev1Hash = $Piece(tRev1, "-", 2)
    Do $$$AssertEquals(tIds.%Get(0), tRev2Hash, "First id is rev2 hash")
    Do $$$AssertEquals(tIds.%Get(1), tRev1Hash, "Second id is rev1 hash")
}

/// <p>AC #2: attachments=true returns inline base64 data, not stubs.</p>
Method TestBulkGetAttachmentsTrue()
{
    ; Create document and attach a file
    Set tRev1 = ..CreateDoc("adoc1", "{""name"":""test""}")
    Do $$$AssertTrue(tRev1 '= "", "adoc1 created")
    Set tContent = "Hello base64 world!"
    Set tSC = ..StoreAttachment("adoc1", tRev1, "hello.txt", tContent, "text/plain", 1, .tDigest, .tLength)
    Do $$$AssertStatusOK(tSC, "Attachment stored")
    ; Get metadata (stubs)
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testbgrepl", "adoc1", tRev1)
    Do $$$AssertTrue($IsObject(tMeta), "Metadata is an object")
    Set tStub = tMeta.%Get("hello.txt")
    Do $$$AssertTrue($IsObject(tStub), "hello.txt stub exists")
    Do $$$AssertEquals(tStub.%Get("stub"), 1, "Stub is true in metadata")
    ; Now simulate inline mode: get stream and base64 encode
    Set tSC2 = ##class(IRISCouch.Storage.Attachment).Get("testbgrepl", "adoc1", "hello.txt", .tStream, .tCType, .tLen, .tDig, tRev1)
    Do $$$AssertStatusOK(tSC2, "Get attachment stream succeeds")
    Do $$$AssertTrue($IsObject(tStream), "Stream is valid object")
    Do tStream.Rewind()
    Set tBinary = tStream.Read()
    Set tBase64 = $System.Encryption.Base64Encode(tBinary)
    Do $$$AssertTrue(tBase64 '= "", "Base64 encoding is non-empty")
    ; Verify we can decode back to original
    Set tDecoded = $System.Encryption.Base64Decode(tBase64)
    Do $$$AssertEquals(tDecoded, tContent, "Decoded base64 matches original content")
    ; Verify content_type preserved
    Do $$$AssertEquals(tCType, "text/plain", "Content type is text/plain")
}

/// <p>AC #5: Without attachments=true, stubs are returned (stub:true).</p>
Method TestBulkGetAttachmentsFalse()
{
    ; Create document and attach a file
    Set tRev1 = ..CreateDoc("sdoc1", "{""name"":""stub-test""}")
    Do $$$AssertTrue(tRev1 '= "", "sdoc1 created")
    Set tSC = ..StoreAttachment("sdoc1", tRev1, "data.bin", "binary content here", "application/octet-stream", 1, .tDigest, .tLength)
    Do $$$AssertStatusOK(tSC, "Attachment stored")
    ; Get metadata — should be stubs
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testbgrepl", "sdoc1", tRev1)
    Do $$$AssertTrue($IsObject(tMeta), "Metadata object returned")
    Set tStub = tMeta.%Get("data.bin")
    Do $$$AssertTrue($IsObject(tStub), "data.bin stub exists")
    Do $$$AssertEquals(tStub.%Get("stub"), 1, "stub is true")
    Do $$$AssertEquals(tStub.%Get("content_type"), "application/octet-stream", "content_type correct")
    Do $$$AssertTrue(+tStub.%Get("length") > 0, "length is positive")
    Do $$$AssertTrue(tStub.%Get("digest") '= "", "digest is non-empty")
    Do $$$AssertTrue(+tStub.%Get("revpos") > 0, "revpos is positive")
    ; Verify data field is NOT present in stub mode
    Do $$$AssertTrue('tStub.%IsDefined("data"), "No data field in stub mode")
}

/// <p>AC #6: Both revs=true and attachments=true — verify both _revisions and inline data.</p>
Method TestBulkGetBothFlags()
{
    ; Create document with 2 revisions
    Set tRev1 = ..CreateDoc("bdoc1", "{""v"":1}")
    Do $$$AssertTrue(tRev1 '= "", "bdoc1 rev1 created")
    Set tRev2 = ..CreateDoc("bdoc1", "{""v"":2}", tRev1)
    Do $$$AssertTrue(tRev2 '= "", "bdoc1 rev2 created")
    ; Attach to the latest revision
    Set tSC = ..StoreAttachment("bdoc1", tRev2, "report.pdf", "PDF content here", "application/pdf", 2, .tDigest, .tLength)
    Do $$$AssertStatusOK(tSC, "Attachment stored on rev2")
    ; Verify _revisions
    Set tRevisions = ##class(IRISCouch.Storage.RevTree).GetRevisions("testbgrepl", "bdoc1", tRev2)
    Do $$$AssertTrue($IsObject(tRevisions), "_revisions object exists")
    Do $$$AssertEquals(tRevisions.start, 2, "_revisions.start is 2")
    Do $$$AssertEquals(tRevisions.ids.%Size(), 2, "_revisions.ids has 2 entries")
    ; Verify attachment metadata exists
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testbgrepl", "bdoc1", tRev2)
    Do $$$AssertTrue($IsObject(tMeta), "Attachment metadata exists")
    Set tStub = tMeta.%Get("report.pdf")
    Do $$$AssertTrue($IsObject(tStub), "report.pdf stub exists")
    ; Verify stream can be base64 encoded (inline mode)
    Set tSC2 = ##class(IRISCouch.Storage.Attachment).Get("testbgrepl", "bdoc1", "report.pdf", .tStream, .tCType, .tLen, .tDig, tRev2)
    Do $$$AssertStatusOK(tSC2, "Get attachment stream succeeds")
    Do tStream.Rewind()
    Set tBase64 = $System.Encryption.Base64Encode(tStream.Read())
    Do $$$AssertTrue(tBase64 '= "", "Base64 data is non-empty")
    ; Both structures verified — handler will combine them in response
}

/// <p>AC #3: Missing document returns error entry with not_found and reason:missing.</p>
Method TestBulkGetMissingDoc()
{
    ; Verify the document does not exist
    Set tExists = ##class(IRISCouch.Storage.Document).Exists("testbgrepl", "nonexistent-doc")
    Do $$$AssertTrue('tExists, "Document does not exist")
    ; Verify no winner revision
    Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner("testbgrepl", "nonexistent-doc")
    Do $$$AssertEquals(tWinner, "", "No winner revision for nonexistent doc")
    ; Document body read should return empty
    Set tBodyStr = ##class(IRISCouch.Storage.Document).Read("testbgrepl", "nonexistent-doc", "1-fake")
    Do $$$AssertEquals(tBodyStr, "", "Document body is empty for missing doc")
}

/// <p>AC #4: Document without attachments requested with attachments=true — no _attachments field.</p>
Method TestBulkGetNoAttachments()
{
    ; Create a document WITHOUT any attachments
    Set tRev1 = ..CreateDoc("nadoc1", "{""name"":""no-attachments""}")
    Do $$$AssertTrue(tRev1 '= "", "nadoc1 created")
    ; GetMetadata should return "" (no attachments)
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testbgrepl", "nadoc1", tRev1)
    Do $$$AssertTrue('$IsObject(tMeta), "No attachment metadata for doc without attachments")
    ; Verify document body reads correctly
    Set tBodyStr = ##class(IRISCouch.Storage.Document).Read("testbgrepl", "nadoc1", tRev1)
    Do $$$AssertTrue(tBodyStr '= "", "Document body is readable")
    Set tBodyObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertEquals(tBodyObj.name, "no-attachments", "Document content correct")
}

/// <p>AC #2: Attachment digest in md5-base64 format is preserved through storage and retrieval.</p>
Method TestBulkGetDigestPreserved()
{
    ; Create document and attach
    Set tRev1 = ..CreateDoc("ddoc1", "{""name"":""digest-test""}")
    Do $$$AssertTrue(tRev1 '= "", "ddoc1 created")
    Set tContent = "Test content for digest verification"
    Set tSC = ..StoreAttachment("ddoc1", tRev1, "test.txt", tContent, "text/plain", 1, .tOrigDigest, .tOrigLength)
    Do $$$AssertStatusOK(tSC, "Attachment stored")
    ; Verify original digest format
    Do $$$AssertTrue($Extract(tOrigDigest, 1, 4) = "md5-", "Original digest starts with md5-")
    ; Retrieve via Get and verify digest matches
    Set tSC2 = ##class(IRISCouch.Storage.Attachment).Get("testbgrepl", "ddoc1", "test.txt", .tStream, .tCType, .tLen, .tRetrDigest, tRev1)
    Do $$$AssertStatusOK(tSC2, "Get attachment succeeds")
    Do $$$AssertEquals(tRetrDigest, tOrigDigest, "Retrieved digest matches original")
    ; Verify via metadata stubs
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testbgrepl", "ddoc1", tRev1)
    Do $$$AssertTrue($IsObject(tMeta), "Metadata exists")
    Set tStub = tMeta.%Get("test.txt")
    Do $$$AssertEquals(tStub.%Get("digest"), tOrigDigest, "Metadata digest matches original")
    ; Verify length preserved
    Do $$$AssertEquals(+tStub.%Get("length"), tOrigLength, "Metadata length matches original")
}

/// <p>Deleted documents should still return error entries (existing behavior).</p>
/// <p>The handler skips body read when IsDeleted is true, producing an error entry.
/// Document.Read still returns the tombstone body, so the handler's IsDeleted
/// check is what prevents the document from appearing as "found".</p>
Method TestBulkGetDeletedDoc()
{
    ; Create and then delete a document
    Set tRev1 = ..CreateDoc("deldoc1", "{""name"":""to-delete""}")
    Do $$$AssertTrue(tRev1 '= "", "deldoc1 created")
    Set tDelRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted("testbgrepl", "deldoc1", tRev1)
    Do $$$AssertTrue(tDelRev '= "", "deldoc1 deleted")
    ; Verify IsDeleted returns true for the deleted revision
    Set tIsDeleted = ##class(IRISCouch.Storage.RevTree).IsDeleted("testbgrepl", "deldoc1", tDelRev)
    Do $$$AssertTrue(tIsDeleted, "Deleted revision is marked as deleted")
    ; The winner should now be the deleted revision
    Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner("testbgrepl", "deldoc1")
    Do $$$AssertEquals(tWinner, tDelRev, "Winner is the deleted revision")
    ; Verify the handler logic: when IsDeleted is true, bodyStr is set to ""
    ; which produces an error entry (not_found/missing)
    Set tIsDelWinner = ##class(IRISCouch.Storage.RevTree).IsDeleted("testbgrepl", "deldoc1", tWinner)
    Do $$$AssertTrue(tIsDelWinner, "Winner revision is deleted — handler will produce error entry")
}

}
