/// <p>Unit tests for IRISCouch attachment storage operations.</p>
/// <p>Tests <class>IRISCouch.Storage.Attachment</class> and
/// <class>IRISCouch.Core.DocumentEngine</class> attachment methods.
/// Covers AC #2, #3, #4, #10, #11.</p>
Class IRISCouch.Test.AttachmentTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create a fresh test database and document before each test.</p>
Method OnBeforeOneTest() As %Status
{
    ; Clean up any previous test data
    Kill ^IRISCouch.DB("testattdb")
    Kill ^IRISCouch.Docs("testattdb")
    Kill ^IRISCouch.Tree("testattdb")
    Kill ^IRISCouch.Changes("testattdb")
    Kill ^IRISCouch.Seq("testattdb")
    Kill ^IRISCouch.Atts("testattdb")
    ; Create fresh test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testattdb")
    Quit tSC
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testattdb")
    Kill ^IRISCouch.Docs("testattdb")
    Kill ^IRISCouch.Tree("testattdb")
    Kill ^IRISCouch.Changes("testattdb")
    Kill ^IRISCouch.Seq("testattdb")
    Kill ^IRISCouch.Atts("testattdb")
    Quit $$$OK
}

/// <p>AC #2: Store and retrieve an attachment via Storage.Attachment.</p>
Method TestStoreAndRetrieve()
{
    ; Create a test stream
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("Hello, attachment world!")
    Do tStream.Rewind()
    ; Store attachment
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testattdb", "doc1", "1-abc", "hello.txt", "text/plain", tStream, 1, .tDigest, .tLength)
    Do $$$AssertStatusOK(tSC, "Store attachment succeeds")
    Do $$$AssertTrue(tLength > 0, "Length is positive")
    Do $$$AssertTrue(tDigest '= "", "Digest is non-empty")
    ; Retrieve attachment
    Set tSC = ##class(IRISCouch.Storage.Attachment).Get("testattdb", "doc1", "hello.txt", .tOutStream, .tOutType, .tOutLen, .tOutDigest, "1-abc")
    Do $$$AssertStatusOK(tSC, "Get attachment succeeds")
    Do $$$AssertEquals(tOutType, "text/plain", "Content type matches")
    Do $$$AssertEquals(tOutLen, tLength, "Length matches")
    Do $$$AssertEquals(tOutDigest, tDigest, "Digest matches")
    ; Read stream content
    Do tOutStream.Rewind()
    Set tContent = tOutStream.Read()
    Do $$$AssertEquals(tContent, "Hello, attachment world!", "Content matches original")
}

/// <p>AC #4: MD5 digest computed on upload in correct format.</p>
Method TestMD5DigestFormat()
{
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("test content for MD5")
    Do tStream.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testattdb", "doc1", "1-abc", "test.bin", "application/octet-stream", tStream, 1, .tDigest, .tLength)
    Do $$$AssertStatusOK(tSC, "Store succeeds")
    ; Verify digest format: "md5-<base64>"
    Do $$$AssertTrue($Extract(tDigest, 1, 4) = "md5-", "Digest starts with md5-")
    Set tB64Part = $Extract(tDigest, 5, *)
    Do $$$AssertTrue(tB64Part '= "", "Base64 part is non-empty")
    ; Verify base64 contains only valid characters
    Set tValid = 1
    For tI = 1:1:$Length(tB64Part) {
        Set tChar = $Extract(tB64Part, tI)
        If "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=" '[ tChar {
            Set tValid = 0
            Quit
        }
    }
    Do $$$AssertTrue(tValid, "Base64 portion contains only valid characters")
}

/// <p>AC #3: Attachment metadata retrieval returns stub format.</p>
Method TestGetMetadata()
{
    ; Store two attachments on same revision
    Set tStream1 = ##class(%Stream.GlobalBinary).%New()
    Do tStream1.Write("file one content")
    Do tStream1.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testattdb", "doc1", "1-abc", "file1.txt", "text/plain", tStream1, 1, .tDigest1, .tLen1)
    Do $$$AssertStatusOK(tSC, "Store file1 succeeds")
    Set tStream2 = ##class(%Stream.GlobalBinary).%New()
    Do tStream2.Write("file two content here")
    Do tStream2.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testattdb", "doc1", "1-abc", "file2.txt", "text/html", tStream2, 1, .tDigest2, .tLen2)
    Do $$$AssertStatusOK(tSC, "Store file2 succeeds")
    ; Get metadata
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testattdb", "doc1", "1-abc")
    Do $$$AssertTrue($IsObject(tMeta), "Metadata is an object")
    ; Check file1
    Set tStub1 = tMeta.%Get("file1.txt")
    Do $$$AssertTrue($IsObject(tStub1), "file1.txt stub exists")
    Do $$$AssertEquals(tStub1.%Get("content_type"), "text/plain", "file1 content_type correct")
    Do $$$AssertEquals(tStub1.%Get("stub"), 1, "file1 stub is true")
    Do $$$AssertEquals(tStub1.%Get("revpos"), 1, "file1 revpos is 1")
    Do $$$AssertTrue(tStub1.%Get("length") > 0, "file1 has positive length")
    Do $$$AssertTrue(tStub1.%Get("digest") '= "", "file1 has digest")
    ; Check file2
    Set tStub2 = tMeta.%Get("file2.txt")
    Do $$$AssertTrue($IsObject(tStub2), "file2.txt stub exists")
    Do $$$AssertEquals(tStub2.%Get("content_type"), "text/html", "file2 content_type correct")
}

/// <p>AC #2: Delete attachment removes it from storage.</p>
Method TestDeleteAttachment()
{
    ; Store attachment
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("deletable content")
    Do tStream.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testattdb", "doc1", "1-abc", "todelete.txt", "text/plain", tStream, 1, .tDigest, .tLength)
    Do $$$AssertStatusOK(tSC, "Store succeeds")
    ; Verify exists
    Do $$$AssertTrue(##class(IRISCouch.Storage.Attachment).Exists("testattdb", "doc1", "todelete.txt"), "Attachment exists before delete")
    ; Delete it
    Set tSC = ##class(IRISCouch.Storage.Attachment).Delete("testattdb", "doc1", "1-abc", "todelete.txt")
    Do $$$AssertStatusOK(tSC, "Delete succeeds")
    ; Verify no longer exists on that revision
    Do $$$AssertTrue('$Data(^IRISCouch.Atts("testattdb", "doc1", "1-abc", "todelete.txt")), "Attachment removed from storage")
}

/// <p>AC #8: Get attachment on non-existent document returns error.</p>
Method TestGetNonExistent()
{
    Set tSC = ##class(IRISCouch.Storage.Attachment).Get("testattdb", "nonexistent", "nofile.txt", .tStream, .tType, .tLen, .tDigest)
    Do $$$AssertStatusNotOK(tSC, "Get on non-existent document returns error")
}

/// <p>AC #10: SaveAttachment creates a new document revision.</p>
Method TestSaveAttachmentCreatesRevision()
{
    ; Create a document first
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testattdb", "attdoc1", "{""name"":""test""}")
    Do $$$AssertTrue(tRev1 '= "", "Initial document created")
    Do $$$AssertEquals($Piece(tRev1, "-", 1), 1, "Initial rev is generation 1")
    ; Add attachment
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("attachment content")
    Do tStream.Rewind()
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).SaveAttachment("testattdb", "attdoc1", tRev1, "file.txt", "text/plain", tStream)
    Do $$$AssertTrue(tRev2 '= "", "Attachment save returns new revision")
    Do $$$AssertEquals($Piece(tRev2, "-", 1), 2, "New rev is generation 2")
    Do $$$AssertTrue(tRev2 '= tRev1, "New rev differs from original")
    ; Verify attachment exists
    Do $$$AssertTrue(##class(IRISCouch.Storage.Attachment).Exists("testattdb", "attdoc1", "file.txt"), "Attachment exists after save")
}

/// <p>AC #11: SaveAttachment generates changes feed entry.</p>
Method TestSaveAttachmentRecordsChange()
{
    ; Create doc
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testattdb", "changesdoc", "{""data"":1}")
    Do $$$AssertTrue(tRev1 '= "", "Document created")
    Set tSeq1 = ##class(IRISCouch.Storage.Changes).GetLastSeq("testattdb")
    ; Add attachment
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("changes content")
    Do tStream.Rewind()
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).SaveAttachment("testattdb", "changesdoc", tRev1, "data.bin", "application/octet-stream", tStream)
    Do $$$AssertTrue(tRev2 '= "", "Attachment saved")
    Set tSeq2 = ##class(IRISCouch.Storage.Changes).GetLastSeq("testattdb")
    Do $$$AssertTrue(tSeq2 > tSeq1, "Sequence number increased after attachment save")
}

/// <p>AC #10: DeleteAttachment creates a new revision without the attachment.</p>
Method TestDeleteAttachmentCreatesRevision()
{
    ; Create doc and add attachment
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testattdb", "deldoc", "{""name"":""deletetest""}")
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("to be deleted")
    Do tStream.Rewind()
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).SaveAttachment("testattdb", "deldoc", tRev1, "del.txt", "text/plain", tStream)
    Do $$$AssertTrue(tRev2 '= "", "Attachment created")
    ; Delete attachment
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).DeleteAttachment("testattdb", "deldoc", tRev2, "del.txt")
    Do $$$AssertTrue(tRev3 '= "", "DeleteAttachment returns new rev")
    Do $$$AssertEquals($Piece(tRev3, "-", 1), 3, "Rev is generation 3")
    ; Verify attachment no longer exists on new revision
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testattdb", "deldoc", tRev3)
    Do $$$AssertTrue('$IsObject(tMeta) || (tMeta = ""), "No attachments on new revision after delete")
}

/// <p>AC #2: CopyAttachments carries forward attachments to new revision.</p>
Method TestCopyAttachments()
{
    ; Store an attachment
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("copy me")
    Do tStream.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testattdb", "copydoc", "1-abc", "copy.txt", "text/plain", tStream, 1, .tDigest, .tLength)
    Do $$$AssertStatusOK(tSC, "Store original succeeds")
    ; Copy to new revision
    Set tSC = ##class(IRISCouch.Storage.Attachment).CopyAttachments("testattdb", "copydoc", "1-abc", "2-def")
    Do $$$AssertStatusOK(tSC, "Copy succeeds")
    ; Verify attachment exists on new rev
    Set tMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata("testattdb", "copydoc", "2-def")
    Do $$$AssertTrue($IsObject(tMeta), "Metadata exists on new rev")
    Set tStub = tMeta.%Get("copy.txt")
    Do $$$AssertTrue($IsObject(tStub), "copy.txt exists on new rev")
}

}
