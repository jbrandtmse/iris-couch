/// <p>HTTP integration tests for IRISCouch attachment retrieval options.</p>
/// <p>Tests GET <code>/{db}/{docid}</code> with <code>_attachments</code> stubs,
/// <code>?attachments=true</code>, <code>?atts_since</code>, and
/// <code>Accept: multipart/mixed</code> with <code>?open_revs=all</code>.
/// Covers AC #1, #2, #3, #4, #6.</p>
Class IRISCouch.Test.AttachmentRetrievalHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create a test database with a document and attachment before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.DB("testretrhttp")
    Kill ^IRISCouch.Docs("testretrhttp")
    Kill ^IRISCouch.Tree("testretrhttp")
    Kill ^IRISCouch.Changes("testretrhttp")
    Kill ^IRISCouch.Seq("testretrhttp")
    Kill ^IRISCouch.Atts("testretrhttp")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testretrhttp")
    If $$$ISERR(tSC) Quit tSC
    ; Create a document
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testretrhttp", "rdoc1", "{""name"":""retrieval http test""}")
    If tRev = "" Quit $$$ERROR($$$GeneralError, "Failed to create test document")
    ; Add an attachment via standalone PUT endpoint
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("hello world")
    Do tStream.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testretrhttp", "rdoc1", tRev, "greet.txt", "text/plain", tStream, 1, .tDigest, .tLen)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Delete test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testretrhttp")
    Kill ^IRISCouch.Docs("testretrhttp")
    Kill ^IRISCouch.Tree("testretrhttp")
    Kill ^IRISCouch.Changes("testretrhttp")
    Kill ^IRISCouch.Seq("testretrhttp")
    Kill ^IRISCouch.Atts("testretrhttp")
    Quit $$$OK
}

/// <p>AC #1: GET document returns _attachments stubs by default.</p>
Method TestGetDocDefaultStubs()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testretrhttp/rdoc1", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET request completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertEquals(tBody.%Get("_id"), "rdoc1", "Response has correct _id")
    ; Check _attachments stubs
    Set tAtts = tBody.%Get("_attachments")
    Do $$$AssertTrue($IsObject(tAtts), "_attachments object exists in response")
    Set tStub = tAtts.%Get("greet.txt")
    Do $$$AssertTrue($IsObject(tStub), "greet.txt stub exists")
    Do $$$AssertEquals(tStub.%Get("content_type"), "text/plain", "content_type is text/plain")
    Do $$$AssertTrue(+tStub.%Get("length") > 0, "length is positive")
    Do $$$AssertTrue(tStub.%Get("digest") '= "", "digest is non-empty")
    Do $$$AssertEquals(+tStub.%Get("revpos"), 1, "revpos is 1")
    Do $$$AssertTrue(tStub.%Get("stub") = 1, "stub is true")
    ; Verify no data field in stub mode
    Do $$$AssertTrue(tStub.%Get("data") = "", "No data field in stub mode")
}

/// <p>AC #1: GET document without attachments has no _attachments field.</p>
Method TestGetDocNoAttachments()
{
    ; Create a document without attachments
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testretrhttp", "noadoc", "{""foo"":""bar""}")
    Do $$$AssertTrue(tRev '= "", "Document without attachments created")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testretrhttp/noadoc", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET request completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns HTTP 200")
    Do $$$AssertTrue('$IsObject(tBody.%Get("_attachments")), "No _attachments for doc without attachments")
}

/// <p>AC #2: GET with ?attachments=true returns base64 data.</p>
Method TestGetDocAttachmentsTrue()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testretrhttp/rdoc1?attachments=true", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET ?attachments=true request completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns HTTP 200")
    Set tAtts = tBody.%Get("_attachments")
    Do $$$AssertTrue($IsObject(tAtts), "_attachments object exists")
    Set tStub = tAtts.%Get("greet.txt")
    Do $$$AssertTrue($IsObject(tStub), "greet.txt entry exists")
    ; Should have data field with base64 content
    Set tData = tStub.%Get("data")
    Do $$$AssertTrue(tData '= "", "data field is present and non-empty")
    ; Decode and verify content
    Set tDecoded = $System.Encryption.Base64Decode(tData)
    Do $$$AssertEquals(tDecoded, "hello world", "Decoded base64 matches original content")
    ; stub should be removed when data is present
    Do $$$AssertTrue(tStub.%Get("stub") = "", "stub field is removed when data is present")
}

/// <p>AC #3: GET with ?atts_since returns newer attachment as data, older as stub.</p>
Method TestGetDocAttsSince()
{
    ; Update document to rev 2 and add a new attachment at revpos 2
    Set tRev1 = ##class(IRISCouch.Storage.RevTree).GetWinner("testretrhttp", "rdoc1")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testretrhttp", "rdoc1", "{""name"":""updated""}", tRev1)
    Do $$$AssertTrue(tRev2 '= "", "Document updated to rev 2")
    ; Copy old attachment forward
    Set tSC = ##class(IRISCouch.Storage.Attachment).CopyAttachments("testretrhttp", "rdoc1", tRev1, tRev2)
    Do $$$AssertStatusOK(tSC, "Attachments copied forward")
    ; Add new attachment at revpos 2
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("new data")
    Do tStream.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testretrhttp", "rdoc1", tRev2, "newfile.txt", "text/plain", tStream, 2, .tDig, .tLen)
    Do $$$AssertStatusOK(tSC, "New attachment stored at revpos 2")
    ; GET with atts_since=["1-xxx"] (generation 1)
    ; URL-encode the JSON array
    Set tAttsSince = "[""" _ tRev1 _ """]"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testretrhttp/rdoc1?atts_since=" _ tAttsSince, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with atts_since request completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns HTTP 200")
    Set tAtts = tBody.%Get("_attachments")
    Do $$$AssertTrue($IsObject(tAtts), "_attachments object exists")
    ; greet.txt (revpos=1) should remain as stub (1 is NOT > 1)
    Set tGreetStub = tAtts.%Get("greet.txt")
    Do $$$AssertTrue($IsObject(tGreetStub), "greet.txt exists")
    Do $$$AssertTrue(tGreetStub.%Get("stub") = 1, "greet.txt is still a stub")
    Do $$$AssertTrue(tGreetStub.%Get("data") = "", "greet.txt has no data field")
    ; newfile.txt (revpos=2) should have base64 data (2 > 1)
    Set tNewStub = tAtts.%Get("newfile.txt")
    Do $$$AssertTrue($IsObject(tNewStub), "newfile.txt exists")
    Do $$$AssertTrue(tNewStub.%Get("data") '= "", "newfile.txt has data field")
    Do $$$AssertTrue(tNewStub.%Get("stub") = "", "newfile.txt stub removed")
    ; Verify decoded content
    Set tDecoded = $System.Encryption.Base64Decode(tNewStub.%Get("data"))
    Do $$$AssertEquals(tDecoded, "new data", "newfile.txt decoded content matches")
}

/// <p>AC #4: GET with Accept: multipart/mixed and open_revs=all returns valid multipart.</p>
Method TestGetMultipartMixed()
{
    ; Make a raw HTTP request with Accept: multipart/mixed header
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "localhost"
    Set tReq.Port = 52773
    Set tReq.Username = "_SYSTEM"
    Set tReq.Password = "SYS"
    Do tReq.SetHeader("Accept", "multipart/mixed")
    Set tSC = tReq.Get("/iris-couch/testretrhttp/rdoc1?open_revs=all")
    Do $$$AssertStatusOK(tSC, "GET multipart/mixed request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "GET returns HTTP 200")
    ; Check Content-Type is multipart/mixed
    Set tRespCT = tReq.HttpResponse.ContentType
    Do $$$AssertTrue(tRespCT [ "multipart/mixed", "Content-Type is multipart/mixed")
    ; Extract boundary from Content-Type
    Set tBoundary = ""
    For tPI = 1:1:$Length(tRespCT, ";") {
        Set tPart = $ZStrip($Piece(tRespCT, ";", tPI), "<>W")
        If $Extract(tPart, 1, 9) = "boundary=" {
            Set tBoundary = $Extract(tPart, 10, *)
        }
    }
    Do $$$AssertTrue(tBoundary '= "", "Boundary string extracted from Content-Type")
    ; Read full response body
    Set tRespStr = tReq.HttpResponse.Data.Read()
    Do $$$AssertTrue(tRespStr '= "", "Response body is non-empty")
    ; Verify it contains boundary markers
    Do $$$AssertTrue(tRespStr [ ("--" _ tBoundary), "Response contains opening boundary")
    Do $$$AssertTrue(tRespStr [ ("--" _ tBoundary _ "--"), "Response contains closing boundary")
    ; Verify JSON part is present
    Do $$$AssertTrue(tRespStr [ "Content-Type: application/json", "Response contains JSON content type")
    ; Verify the document JSON is present
    Do $$$AssertTrue(tRespStr [ """_id"":""rdoc1""", "Response contains document _id")
    ; Verify attachment part is present with follows:true in the JSON
    Do $$$AssertTrue(tRespStr [ """follows"":true", "JSON part has follows:true for attachment")
    ; Verify binary attachment part
    Do $$$AssertTrue(tRespStr [ "Content-Disposition: attachment; filename=""greet.txt""", "Response contains attachment Content-Disposition")
    Do $$$AssertTrue(tRespStr [ "hello world", "Response contains attachment binary content")
}

/// <p>AC: GET with ?atts_since=invalid returns HTTP 400 with error envelope.</p>
Method TestGetDocInvalidAttsSinceReturns400()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testretrhttp/rdoc1?atts_since=not-json", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with invalid atts_since request completed")
    Do $$$AssertEquals(tStatus, 400, "GET returns HTTP 400 for invalid atts_since JSON")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertEquals(tBody.error, "bad_request", "Error slug is bad_request")
    Do $$$AssertTrue(tBody.reason [ "atts_since", "Error reason mentions atts_since")
}

/// <p>AC: GET with ?open_revs=all&attachments=true returns base64 data in JSON array path.</p>
Method TestGetOpenRevsWithAttachmentsTrue()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testretrhttp/rdoc1?open_revs=all&attachments=true", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET open_revs+attachments=true request completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON array")
    Do $$$AssertTrue(tBody.%Size() > 0, "Array has at least one entry")
    ; Get the first revision entry
    Set tEntry = tBody.%Get(0)
    Do $$$AssertTrue($IsObject(tEntry), "First entry is an object")
    Set tOk = tEntry.%Get("ok")
    Do $$$AssertTrue($IsObject(tOk), "Entry has ok field")
    ; Check _attachments has data (not stub)
    Set tAtts = tOk.%Get("_attachments")
    Do $$$AssertTrue($IsObject(tAtts), "_attachments object exists in open_revs response")
    Set tStub = tAtts.%Get("greet.txt")
    Do $$$AssertTrue($IsObject(tStub), "greet.txt entry exists")
    Set tData = tStub.%Get("data")
    Do $$$AssertTrue(tData '= "", "data field is present with base64 content")
    ; Decode and verify
    Set tDecoded = $System.Encryption.Base64Decode(tData)
    Do $$$AssertEquals(tDecoded, "hello world", "Decoded base64 matches original content")
    ; stub should be removed
    Do $$$AssertTrue(tStub.%Get("stub") = "", "stub field is removed when data is present")
}

/// <p>AC #4: Multipart response has correct boundaries and Content-Type headers.</p>
Method TestMultipartBoundaryFormat()
{
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "localhost"
    Set tReq.Port = 52773
    Set tReq.Username = "_SYSTEM"
    Set tReq.Password = "SYS"
    Do tReq.SetHeader("Accept", "multipart/mixed")
    Set tSC = tReq.Get("/iris-couch/testretrhttp/rdoc1?open_revs=all")
    Do $$$AssertStatusOK(tSC, "GET multipart/mixed request completed")
    Set tRespStr = tReq.HttpResponse.Data.Read()
    ; Count boundary occurrences — should have at least opening + attachment + closing
    ; With 1 revision and 1 attachment: JSON part boundary, attachment part boundary, closing boundary
    Set tRespCT = tReq.HttpResponse.ContentType
    Set tBoundary = ""
    For tPI = 1:1:$Length(tRespCT, ";") {
        Set tPart = $ZStrip($Piece(tRespCT, ";", tPI), "<>W")
        If $Extract(tPart, 1, 9) = "boundary=" {
            Set tBoundary = $Extract(tPart, 10, *)
        }
    }
    ; Count how many times the boundary marker appears
    Set tCount = 0
    Set tSearchStr = "--" _ tBoundary
    Set tPos = 1
    For {
        Set tFound = $Find(tRespStr, tSearchStr, tPos)
        If tFound = 0 Quit
        Set tCount = tCount + 1
        Set tPos = tFound
    }
    ; With 1 revision + 1 attachment: 2 opening boundaries + 1 closing = at least 3 markers
    Do $$$AssertTrue(tCount >= 3, "At least 3 boundary markers present (JSON part + attachment part + closing)")
}

/// <p>AC: Multipart/mixed response with conflicting revisions each having different attachments.</p>
/// <p>Creates a conflict by grafting an external revision (new_edits=false pattern),
/// attaches different files to each leaf, then verifies the multipart response
/// includes parts for both revisions with their respective attachment binaries.</p>
Method TestMultipartWithConflictingRevisions()
{
    ; Get the current winning rev for rdoc1 (rev 1)
    Set tRev1 = ##class(IRISCouch.Storage.RevTree).GetWinner("testretrhttp", "rdoc1")
    Do $$$AssertTrue(tRev1 '= "", "Rev1 exists: " _ tRev1)
    ; Create a conflicting revision by grafting a separate chain (simulates new_edits=false)
    Set tConflictRev = "1-conflicthash999"
    Set tSC = ##class(IRISCouch.Storage.Document).Write("testretrhttp", "rdoc1", tConflictRev, "{""name"":""conflict branch""}")
    Do $$$AssertStatusOK(tSC, "Conflict revision body written")
    ; Graft as an independent chain — creates a separate root, making 2 leaf revisions
    Set tChain = []
    Do tChain.%Push(tConflictRev)
    Set tSC = ##class(IRISCouch.Storage.RevTree).GraftChain("testretrhttp", "rdoc1", tChain, tConflictRev, 0)
    Do $$$AssertStatusOK(tSC, "Conflict branch grafted into rev tree")
    ; Verify we now have 2 leaf revisions
    Set tLeaves = ##class(IRISCouch.Storage.RevTree).GetLeafRevs("testretrhttp", "rdoc1")
    Do $$$AssertTrue(tLeaves.%Size() >= 2, "At least 2 leaf revisions exist (conflict)")
    ; Add attachment "b.txt" to the conflict revision
    Set tStream2 = ##class(%Stream.GlobalBinary).%New()
    Do tStream2.Write("conflict attachment data")
    Do tStream2.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("testretrhttp", "rdoc1", tConflictRev, "b.txt", "text/plain", tStream2, 1, .tDig2, .tLen2)
    Do $$$AssertStatusOK(tSC, "Attachment b.txt stored on conflict revision")
    ; Now GET with Accept: multipart/mixed and open_revs=all
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "localhost"
    Set tReq.Port = 52773
    Set tReq.Username = "_SYSTEM"
    Set tReq.Password = "SYS"
    Do tReq.SetHeader("Accept", "multipart/mixed")
    Set tSC = tReq.Get("/iris-couch/testretrhttp/rdoc1?open_revs=all")
    Do $$$AssertStatusOK(tSC, "GET multipart/mixed with conflicts completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "GET returns HTTP 200")
    ; Check Content-Type is multipart/mixed
    Set tRespCT = tReq.HttpResponse.ContentType
    Do $$$AssertTrue(tRespCT [ "multipart/mixed", "Content-Type is multipart/mixed")
    ; Extract boundary
    Set tBoundary = ""
    For tPI = 1:1:$Length(tRespCT, ";") {
        Set tPart = $ZStrip($Piece(tRespCT, ";", tPI), "<>W")
        If $Extract(tPart, 1, 9) = "boundary=" {
            Set tBoundary = $Extract(tPart, 10, *)
        }
    }
    Do $$$AssertTrue(tBoundary '= "", "Boundary extracted")
    ; Read full response body
    Set tRespStr = tReq.HttpResponse.Data.Read()
    ; Verify both revisions appear in the multipart response
    Do $$$AssertTrue(tRespStr [ """_rev"":""" _ tRev1 _ """", "Response contains rev1")
    Do $$$AssertTrue(tRespStr [ """_rev"":""" _ tConflictRev _ """", "Response contains conflict rev")
    ; Verify both attachments appear
    Do $$$AssertTrue(tRespStr [ "hello world", "Response contains greet.txt content from rev1")
    Do $$$AssertTrue(tRespStr [ "conflict attachment data", "Response contains b.txt content from conflict rev")
    ; Verify MIME boundaries are correct
    Do $$$AssertTrue(tRespStr [ ("--" _ tBoundary), "Response contains opening boundary")
    Do $$$AssertTrue(tRespStr [ ("--" _ tBoundary _ "--"), "Response contains closing boundary")
    ; Verify each part has proper Content-Type
    Do $$$AssertTrue(tRespStr [ "Content-Type: application/json", "Response has JSON Content-Type parts")
    Do $$$AssertTrue(tRespStr [ "Content-Type: text/plain", "Response has text/plain Content-Type for attachment parts")
    ; Verify Content-Disposition headers for both attachments
    Do $$$AssertTrue(tRespStr [ "filename=""greet.txt""", "Response has greet.txt Content-Disposition")
    Do $$$AssertTrue(tRespStr [ "filename=""b.txt""", "Response has b.txt Content-Disposition")
    ; Verify boundary contains only hex chars (no MIME-special characters)
    ; Strip "iriscouch_" prefix
    Set tHexPart = $Piece(tBoundary, "_", 2)
    Set tIsHex = 1
    For tCI = 1:1:$Length(tHexPart) {
        Set tChar = $Extract(tHexPart, tCI)
        If '((tChar?1N) || ((tChar >= "A") && (tChar <= "F")) || ((tChar >= "a") && (tChar <= "f"))) {
            Set tIsHex = 0
            Quit
        }
    }
    Do $$$AssertTrue(tIsHex, "Boundary hex part contains only hex characters (no +/= MIME-special chars)")
}

}

