/// <p>Unit tests for IRISCouch inline attachment operations.</p>
/// <p>Tests <method>DocumentEngine.SaveWithAttachments</method> for base64
/// inline attachments, multiple attachments, and stub preservation.
/// Covers AC #1, #2, #4, #5, #6.</p>
Class IRISCouch.Test.InlineAttachmentTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testinline")
    Kill ^IRISCouch.Docs("testinline")
    Kill ^IRISCouch.Tree("testinline")
    Kill ^IRISCouch.Changes("testinline")
    Kill ^IRISCouch.Seq("testinline")
    Kill ^IRISCouch.Atts("testinline")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testinline")
    Quit tSC
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testinline")
    Kill ^IRISCouch.Docs("testinline")
    Kill ^IRISCouch.Tree("testinline")
    Kill ^IRISCouch.Changes("testinline")
    Kill ^IRISCouch.Seq("testinline")
    Kill ^IRISCouch.Atts("testinline")
    Quit $$$OK
}

/// <p>AC #1: Base64 decode and store single inline attachment via SaveWithAttachments.</p>
Method TestSingleInlineAttachment()
{
    ; Build _attachments with base64 data
    ; "hello" = aGVsbG8=
    Set tAttachments = {}
    Set tAttEntry = {}
    Do tAttEntry.%Set("content_type", "text/plain")
    Do tAttEntry.%Set("data", "aGVsbG8=")
    Do tAttachments.%Set("hello.txt", tAttEntry)
    ; Save document with inline attachment
    Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments("testinline", "doc1", "{""name"":""test""}", "", tAttachments)
    Do $$$AssertTrue(tNewRev '= "", "SaveWithAttachments returns new revision")
    Do $$$AssertEquals($Piece(tNewRev, "-", 1), 1, "Rev is generation 1")
    ; Verify attachment was stored
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testinline", "doc1", tNewRev)
    Do $$$AssertTrue($IsObject(tMeta), "Attachment metadata exists")
    Set tStub = tMeta.%Get("hello.txt")
    Do $$$AssertTrue($IsObject(tStub), "hello.txt stub exists")
    Do $$$AssertEquals(tStub.%Get("content_type"), "text/plain", "Content type matches")
    Do $$$AssertEquals(tStub.%Get("length"), 5, "Length is 5 bytes for 'hello'")
    Do $$$AssertTrue(tStub.%Get("digest") '= "", "Digest is non-empty")
    ; Verify we can retrieve the attachment content
    Set tSC = ##class(IRISCouch.Storage.Attachment).Get("testinline", "doc1", "hello.txt", .tStream, .tType, .tLen, .tDigest, tNewRev)
    Do $$$AssertStatusOK(tSC, "Get attachment succeeds")
    Do tStream.Rewind()
    Set tContent = tStream.Read()
    Do $$$AssertEquals(tContent, "hello", "Attachment content is 'hello'")
}

/// <p>AC #2: Multiple inline attachments stored atomically in one document.</p>
Method TestMultipleInlineAttachments()
{
    Set tAttachments = {}
    ; Attachment 1: "hello" = aGVsbG8=
    Set tAtt1 = {}
    Do tAtt1.%Set("content_type", "text/plain")
    Do tAtt1.%Set("data", "aGVsbG8=")
    Do tAttachments.%Set("file1.txt", tAtt1)
    ; Attachment 2: "world" = d29ybGQ=
    Set tAtt2 = {}
    Do tAtt2.%Set("content_type", "text/html")
    Do tAtt2.%Set("data", "d29ybGQ=")
    Do tAttachments.%Set("file2.txt", tAtt2)
    Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments("testinline", "multidoc", "{""count"":2}", "", tAttachments)
    Do $$$AssertTrue(tNewRev '= "", "SaveWithAttachments with multiple attachments succeeds")
    ; Verify both attachments exist
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testinline", "multidoc", tNewRev)
    Do $$$AssertTrue($IsObject(tMeta), "Metadata exists")
    Set tStub1 = tMeta.%Get("file1.txt")
    Do $$$AssertTrue($IsObject(tStub1), "file1.txt exists")
    Do $$$AssertEquals(tStub1.%Get("content_type"), "text/plain", "file1 content_type correct")
    Set tStub2 = tMeta.%Get("file2.txt")
    Do $$$AssertTrue($IsObject(tStub2), "file2.txt exists")
    Do $$$AssertEquals(tStub2.%Get("content_type"), "text/html", "file2 content_type correct")
    ; Verify content of each
    Set tSC = ##class(IRISCouch.Storage.Attachment).Get("testinline", "multidoc", "file1.txt", .tStream1, .tType1, .tLen1, .tDigest1, tNewRev)
    Do $$$AssertStatusOK(tSC, "Get file1 succeeds")
    Do tStream1.Rewind()
    Do $$$AssertEquals(tStream1.Read(), "hello", "file1 content is 'hello'")
    Set tSC = ##class(IRISCouch.Storage.Attachment).Get("testinline", "multidoc", "file2.txt", .tStream2, .tType2, .tLen2, .tDigest2, tNewRev)
    Do $$$AssertStatusOK(tSC, "Get file2 succeeds")
    Do tStream2.Rewind()
    Do $$$AssertEquals(tStream2.Read(), "world", "file2 content is 'world'")
}

/// <p>AC #5, #6: Stub preservation — update doc with new attachment + existing stub.</p>
Method TestStubPreservation()
{
    ; Create doc with initial attachment
    Set tAttachments1 = {}
    Set tAtt1 = {}
    Do tAtt1.%Set("content_type", "text/plain")
    Do tAtt1.%Set("data", "aGVsbG8=")
    Do tAttachments1.%Set("existing.txt", tAtt1)
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments("testinline", "stubdoc", "{""v"":1}", "", tAttachments1)
    Do $$$AssertTrue(tRev1 '= "", "Initial save succeeds")
    ; Update doc: keep existing.txt as stub, add new.txt
    Set tAttachments2 = {}
    Set tStubEntry = {}
    Do tStubEntry.%Set("stub", 1, "boolean")
    Do tAttachments2.%Set("existing.txt", tStubEntry)
    Set tNewAtt = {}
    Do tNewAtt.%Set("content_type", "application/json")
    Do tNewAtt.%Set("data", "e30=")
    Do tAttachments2.%Set("new.txt", tNewAtt)
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments("testinline", "stubdoc", "{""v"":2}", tRev1, tAttachments2)
    Do $$$AssertTrue(tRev2 '= "", "Update with stub + new attachment succeeds")
    Do $$$AssertEquals($Piece(tRev2, "-", 1), 2, "Rev is generation 2")
    ; Verify both attachments exist on new rev
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testinline", "stubdoc", tRev2)
    Do $$$AssertTrue($IsObject(tMeta), "Metadata exists on new rev")
    Set tStub1 = tMeta.%Get("existing.txt")
    Do $$$AssertTrue($IsObject(tStub1), "existing.txt carried forward via stub")
    Set tStub2 = tMeta.%Get("new.txt")
    Do $$$AssertTrue($IsObject(tStub2), "new.txt added in update")
    ; Verify existing.txt content still accessible
    Set tSC = ##class(IRISCouch.Storage.Attachment).Get("testinline", "stubdoc", "existing.txt", .tStream, .tType, .tLen, .tDigest, tRev2)
    Do $$$AssertStatusOK(tSC, "Get existing.txt from new rev succeeds")
    Do tStream.Rewind()
    Do $$$AssertEquals(tStream.Read(), "hello", "existing.txt content preserved")
}

/// <p>AC #1: Invalid base64 data returns empty revision (rollback).</p>
/// <p>ObjectScript's <code>$System.Encryption.Base64Decode</code> returns "" for
/// invalid input, which triggers the rollback path in SaveWithAttachments.
/// This test verifies SaveWithAttachments rejects invalid base64 by returning
/// an empty revision and that no document or attachment data is persisted.</p>
Method TestInvalidBase64()
{
    Set tAttachments = {}
    Set tAttEntry = {}
    Do tAttEntry.%Set("content_type", "text/plain")
    Do tAttEntry.%Set("data", "!!!invalid-base64!!!")
    Do tAttachments.%Set("bad.txt", tAttEntry)
    Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments("testinline", "baddoc", "{}", "", tAttachments)
    ; $System.Encryption.Base64Decode returns "" for invalid input,
    ; which triggers the rollback in SaveWithAttachments (empty binary check)
    Do $$$AssertEquals(tNewRev, "", "SaveWithAttachments returns empty rev for invalid base64")
    ; Verify no document was persisted (transaction rolled back)
    Do $$$AssertTrue('##class(IRISCouch.Storage.Document).Exists("testinline", "baddoc"), "No document persisted for invalid base64")
    ; Verify no attachment was persisted
    Do $$$AssertTrue('##class(IRISCouch.Storage.Attachment).Exists("testinline", "baddoc", "bad.txt"), "No attachment persisted for invalid base64")
}

/// <p>AC: Stream-based attachment path stores data without base64 round-trip.</p>
/// <p>Verifies that passing a stream via the _stream key in the attachments
/// object stores the attachment correctly through SaveWithAttachments.</p>
Method TestStreamBasedAttachment()
{
    ; Build _attachments with a stream (bypasses base64 encode/decode)
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("direct stream data")
    Do tStream.Rewind()
    Set tAttachments = {}
    Set tAttEntry = {}
    Do tAttEntry.%Set("content_type", "text/plain")
    Do tAttEntry.%Set("_stream", tStream)
    Do tAttachments.%Set("streamed.txt", tAttEntry)
    ; Save document with stream-based attachment
    Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments("testinline", "streamdoc", "{""mode"":""stream""}", "", tAttachments)
    Do $$$AssertTrue(tNewRev '= "", "SaveWithAttachments with stream returns new revision")
    ; Verify attachment was stored correctly
    Set tSC = ##class(IRISCouch.Storage.Attachment).Get("testinline", "streamdoc", "streamed.txt", .tRetStream, .tType, .tLen, .tDigest, tNewRev)
    Do $$$AssertStatusOK(tSC, "Get stream attachment succeeds")
    Do tRetStream.Rewind()
    Set tContent = tRetStream.Read()
    Do $$$AssertEquals(tContent, "direct stream data", "Stream attachment content matches")
    Do $$$AssertEquals(tType, "text/plain", "Stream attachment content type matches")
}

/// <p>AC: Mixed stream and base64 attachments stored correctly in one call.</p>
Method TestMixedStreamAndBase64Attachments()
{
    ; Stream-based attachment
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("from stream")
    Do tStream.Rewind()
    Set tAttachments = {}
    Set tStreamEntry = {}
    Do tStreamEntry.%Set("content_type", "text/plain")
    Do tStreamEntry.%Set("_stream", tStream)
    Do tAttachments.%Set("stream.txt", tStreamEntry)
    ; Base64 attachment ("base64" = YmFzZTY0)
    Set tB64Entry = {}
    Do tB64Entry.%Set("content_type", "application/json")
    Do tB64Entry.%Set("data", "YmFzZTY0")
    Do tAttachments.%Set("b64.txt", tB64Entry)
    Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments("testinline", "mixdoc", "{""mixed"":true}", "", tAttachments)
    Do $$$AssertTrue(tNewRev '= "", "Mixed attachment save succeeds")
    ; Verify stream attachment
    Set tSC = ##class(IRISCouch.Storage.Attachment).Get("testinline", "mixdoc", "stream.txt", .tS1, .tT1, .tL1, .tD1, tNewRev)
    Do $$$AssertStatusOK(tSC, "Get stream.txt succeeds")
    Do tS1.Rewind()
    Do $$$AssertEquals(tS1.Read(), "from stream", "stream.txt content correct")
    ; Verify base64 attachment
    Set tSC = ##class(IRISCouch.Storage.Attachment).Get("testinline", "mixdoc", "b64.txt", .tS2, .tT2, .tL2, .tD2, tNewRev)
    Do $$$AssertStatusOK(tSC, "Get b64.txt succeeds")
    Do tS2.Rewind()
    Do $$$AssertEquals(tS2.Read(), "base64", "b64.txt content correct")
}

/// <p>AC #4: SaveWithAttachments is atomic — transaction rolls back on DB error.</p>
Method TestAtomicTransaction()
{
    ; Try to save to non-existent database
    Set tAttachments = {}
    Set tAttEntry = {}
    Do tAttEntry.%Set("content_type", "text/plain")
    Do tAttEntry.%Set("data", "aGVsbG8=")
    Do tAttachments.%Set("test.txt", tAttEntry)
    Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments("nosuchdb", "doc1", "{}", "", tAttachments)
    Do $$$AssertEquals(tNewRev, "", "SaveWithAttachments to non-existent DB returns empty rev")
}

/// <p>AC #4: Changes feed records inline attachment save.</p>
Method TestInlineAttachmentRecordsChange()
{
    Set tSeqBefore = ##class(IRISCouch.Storage.Changes).GetLastSeq("testinline")
    Set tAttachments = {}
    Set tAtt = {}
    Do tAtt.%Set("content_type", "text/plain")
    Do tAtt.%Set("data", "aGVsbG8=")
    Do tAttachments.%Set("change.txt", tAtt)
    Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments("testinline", "changedoc", "{}", "", tAttachments)
    Do $$$AssertTrue(tNewRev '= "", "Save succeeds")
    Set tSeqAfter = ##class(IRISCouch.Storage.Changes).GetLastSeq("testinline")
    Do $$$AssertTrue(tSeqAfter > tSeqBefore, "Sequence increased after inline attachment save")
}

}
