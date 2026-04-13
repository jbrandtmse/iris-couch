/// <p>HTTP integration tests for IRISCouch inline attachment operations.</p>
/// <p>Tests PUT and POST with inline <code>_attachments</code> in JSON body,
/// stub preservation on document updates, and attachment retrieval.
/// Covers AC #1, #5, #6, #7, #8, #9, #10.</p>
Class IRISCouch.Test.InlineAttachmentHttpTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testinlhttp")
    Kill ^IRISCouch.Docs("testinlhttp")
    Kill ^IRISCouch.Tree("testinlhttp")
    Kill ^IRISCouch.Changes("testinlhttp")
    Kill ^IRISCouch.Seq("testinlhttp")
    Kill ^IRISCouch.Atts("testinlhttp")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testinlhttp")
    Quit tSC
}

/// <p>Delete test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testinlhttp")
    Kill ^IRISCouch.Docs("testinlhttp")
    Kill ^IRISCouch.Tree("testinlhttp")
    Kill ^IRISCouch.Changes("testinlhttp")
    Kill ^IRISCouch.Seq("testinlhttp")
    Kill ^IRISCouch.Atts("testinlhttp")
    Quit $$$OK
}

/// <p>AC #8: PUT with inline attachment returns 201 and new rev.</p>
Method TestPutWithInlineAttachment()
{
    Set tBody = "{""name"":""test"",""_attachments"":{""hello.txt"":{""content_type"":""text/plain"",""data"":""aGVsbG8=""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testinlhttp/inldoc1", .tStatus, .tResp, tBody)
    Do $$$AssertStatusOK(tSC, "PUT with inline attachment request completed")
    Do $$$AssertEquals(tStatus, 201, "PUT returns HTTP 201")
    Do $$$AssertTrue($IsObject(tResp), "Response is JSON object")
    Do $$$AssertTrue(tResp.ok, "Response has ok: true")
    Do $$$AssertEquals(tResp.id, "inldoc1", "Response id matches")
    Do $$$AssertTrue(tResp.rev '= "", "Response has non-empty rev")
    Do $$$AssertEquals($Piece(tResp.rev, "-", 1), 1, "Rev is generation 1")
}

/// <p>AC #7: POST with inline attachment returns 201 and new rev.</p>
Method TestPostWithInlineAttachment()
{
    Set tBody = "{""name"":""posted"",""_attachments"":{""data.bin"":{""content_type"":""application/octet-stream"",""data"":""AQIDBA==""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testinlhttp", .tStatus, .tResp, tBody)
    Do $$$AssertStatusOK(tSC, "POST with inline attachment request completed")
    Do $$$AssertEquals(tStatus, 201, "POST returns HTTP 201")
    Do $$$AssertTrue($IsObject(tResp), "Response is JSON object")
    Do $$$AssertTrue(tResp.ok, "Response has ok: true")
    Do $$$AssertTrue(tResp.id '= "", "Response has non-empty id")
    Do $$$AssertTrue(tResp.rev '= "", "Response has non-empty rev")
}

/// <p>AC #1: GET document after inline PUT verifies body stored without raw data.</p>
Method TestGetDocShowsAttachmentStubs()
{
    Set tBody = "{""title"":""stubtest"",""_attachments"":{""notes.txt"":{""content_type"":""text/plain"",""data"":""bm90ZXM=""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testinlhttp/stubdoc", .tStatus, .tResp, tBody)
    Do $$$AssertStatusOK(tSC, "PUT completed")
    Do $$$AssertEquals(tStatus, 201, "PUT returns 201")
    ; GET the document
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testinlhttp/stubdoc", .tStatus, .tResp)
    Do $$$AssertStatusOK(tSC, "GET completed")
    Do $$$AssertEquals(tStatus, 200, "GET returns 200")
    Do $$$AssertEquals(tResp.%Get("title"), "stubtest", "Document body field preserved")
    ; Verify document body was stored without raw base64 data
    Set tBodyStr = ##class(IRISCouch.Storage.Document).Read("testinlhttp", "stubdoc", tResp.%Get("_rev"))
    Do $$$AssertTrue(tBodyStr '[ "bm90ZXM=", "Stored body does not contain raw base64 data")
}

/// <p>AC #5, #6: Update document with stub plus new attachment preserves both.</p>
Method TestUpdateWithStubAndNewAttachment()
{
    ; Create doc with initial attachment
    Set tBody1 = "{""v"":1,""_attachments"":{""orig.txt"":{""content_type"":""text/plain"",""data"":""b3JpZ2luYWw=""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testinlhttp/stubupdate", .tStatus, .tResp1, tBody1)
    Do $$$AssertStatusOK(tSC, "Initial PUT completed")
    Do $$$AssertEquals(tStatus, 201, "Initial PUT returns 201")
    Set tRev1 = tResp1.rev
    ; Update with stub for orig.txt plus new attachment
    Set tBody2 = "{""v"":2,""_rev"":"""_tRev1_""",""_attachments"":{""orig.txt"":{""stub"":true},""added.txt"":{""content_type"":""text/html"",""data"":""PGI+aGk8L2I+""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testinlhttp/stubupdate", .tStatus, .tResp2, tBody2)
    Do $$$AssertStatusOK(tSC, "Update PUT completed")
    Do $$$AssertEquals(tStatus, 201, "Update PUT returns 201")
    Do $$$AssertEquals($Piece(tResp2.rev, "-", 1), 2, "Rev is generation 2")
    ; Verify orig.txt accessible
    Set tSC = ##class(IRISCouch.Test.AttachmentHttpTest).MakeBinaryRequest("GET", "/testinlhttp/stubupdate/orig.txt", "", "", .tGetStatus, .tGetBody)
    Do $$$AssertStatusOK(tSC, "GET orig.txt completed")
    Do $$$AssertEquals(tGetStatus, 200, "GET orig.txt returns 200")
    Do $$$AssertEquals(tGetBody, "original", "orig.txt content preserved via stub")
    ; Verify added.txt accessible
    Set tSC = ##class(IRISCouch.Test.AttachmentHttpTest).MakeBinaryRequest("GET", "/testinlhttp/stubupdate/added.txt", "", "", .tGetStatus2, .tGetBody2)
    Do $$$AssertStatusOK(tSC, "GET added.txt completed")
    Do $$$AssertEquals(tGetStatus2, 200, "GET added.txt returns 200")
}

/// <p>AC #1, #10: GET individual attachment returns correct binary content.</p>
Method TestGetIndividualAttachmentContent()
{
    Set tBody = "{""_attachments"":{""data.txt"":{""content_type"":""text/plain"",""data"":""dGVzdCBkYXRh""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testinlhttp/getattdoc", .tStatus, .tResp, tBody)
    Do $$$AssertStatusOK(tSC, "PUT completed")
    Do $$$AssertEquals(tStatus, 201, "PUT returns 201")
    ; GET the individual attachment
    Set tSC = ##class(IRISCouch.Test.AttachmentHttpTest).MakeBinaryRequest("GET", "/testinlhttp/getattdoc/data.txt", "", "", .tGetStatus, .tGetBody)
    Do $$$AssertStatusOK(tSC, "GET attachment completed")
    Do $$$AssertEquals(tGetStatus, 200, "GET attachment returns 200")
    Do $$$AssertEquals(tGetBody, "test data", "Attachment content matches")
}

/// <p>AC #3: PUT multipart/related with JSON plus binary part returns 201.</p>
Method TestPutMultipartRelated()
{
    Set tBoundary = "----IRISCouchTestBoundary"
    Set tCRLF = $Char(13, 10)
    Set tJsonPart = "{""name"":""multipart test""}"
    Set tAttContent = "Binary attachment data"
    ; Build the multipart body
    Set tMultiBody = ""
    Set tMultiBody = tMultiBody _ "--" _ tBoundary _ tCRLF
    Set tMultiBody = tMultiBody _ "Content-Type: application/json" _ tCRLF
    Set tMultiBody = tMultiBody _ tCRLF
    Set tMultiBody = tMultiBody _ tJsonPart _ tCRLF
    Set tMultiBody = tMultiBody _ "--" _ tBoundary _ tCRLF
    Set tMultiBody = tMultiBody _ "Content-Type: text/plain" _ tCRLF
    Set tDisp = "Content-Disposition: attachment; filename=" _ $Char(34) _ "upload.txt" _ $Char(34)
    Set tMultiBody = tMultiBody _ tDisp _ tCRLF
    Set tMultiBody = tMultiBody _ tCRLF
    Set tMultiBody = tMultiBody _ tAttContent _ tCRLF
    Set tMultiBody = tMultiBody _ "--" _ tBoundary _ "--" _ tCRLF
    ; Send request
    Set tContentType = "multipart/related; boundary=" _ tBoundary
    Set tSC = ..MakeMultipartRequest("PUT", "/testinlhttp/mpdoc1", tContentType, tMultiBody, .tStatus, .tResp)
    Do $$$AssertStatusOK(tSC, "PUT multipart/related request completed")
    Do $$$AssertEquals(tStatus, 201, "PUT multipart/related returns 201")
    Do $$$AssertTrue($IsObject(tResp), "Response is JSON")
    Do $$$AssertTrue(tResp.ok, "Response has ok: true")
    Do $$$AssertEquals(tResp.id, "mpdoc1", "Response id matches")
}

/// <p>AC #3: Multiple binary parts in multipart/related stored correctly.</p>
Method TestMultipartMultipleParts()
{
    Set tBoundary = "----IRISCouchMultiParts"
    Set tCRLF = $Char(13, 10)
    Set tJsonPart = "{""title"":""multi-binary""}"
    Set tAtt1 = "First file content"
    Set tAtt2 = "Second file content"
    Set tMultiBody = ""
    Set tMultiBody = tMultiBody _ "--" _ tBoundary _ tCRLF
    Set tMultiBody = tMultiBody _ "Content-Type: application/json" _ tCRLF
    Set tMultiBody = tMultiBody _ tCRLF
    Set tMultiBody = tMultiBody _ tJsonPart _ tCRLF
    Set tMultiBody = tMultiBody _ "--" _ tBoundary _ tCRLF
    Set tMultiBody = tMultiBody _ "Content-Type: text/plain" _ tCRLF
    Set tDisp1 = "Content-Disposition: attachment; filename=" _ $Char(34) _ "first.txt" _ $Char(34)
    Set tMultiBody = tMultiBody _ tDisp1 _ tCRLF
    Set tMultiBody = tMultiBody _ tCRLF
    Set tMultiBody = tMultiBody _ tAtt1 _ tCRLF
    Set tMultiBody = tMultiBody _ "--" _ tBoundary _ tCRLF
    Set tMultiBody = tMultiBody _ "Content-Type: text/plain" _ tCRLF
    Set tDisp2 = "Content-Disposition: attachment; filename=" _ $Char(34) _ "second.txt" _ $Char(34)
    Set tMultiBody = tMultiBody _ tDisp2 _ tCRLF
    Set tMultiBody = tMultiBody _ tCRLF
    Set tMultiBody = tMultiBody _ tAtt2 _ tCRLF
    Set tMultiBody = tMultiBody _ "--" _ tBoundary _ "--" _ tCRLF
    Set tContentType = "multipart/related; boundary=" _ tBoundary
    Set tSC = ..MakeMultipartRequest("PUT", "/testinlhttp/mpmulti", tContentType, tMultiBody, .tStatus, .tResp)
    Do $$$AssertStatusOK(tSC, "PUT multipart multi-parts completed")
    Do $$$AssertEquals(tStatus, 201, "PUT returns 201")
    ; Verify both attachments retrievable
    Set tSC = ##class(IRISCouch.Test.AttachmentHttpTest).MakeBinaryRequest("GET", "/testinlhttp/mpmulti/first.txt", "", "", .tGetStatus1, .tGetBody1)
    Do $$$AssertStatusOK(tSC, "GET first.txt completed")
    Do $$$AssertEquals(tGetStatus1, 200, "GET first.txt returns 200")
    Do $$$AssertEquals(tGetBody1, "First file content", "first.txt content correct")
    Set tSC = ##class(IRISCouch.Test.AttachmentHttpTest).MakeBinaryRequest("GET", "/testinlhttp/mpmulti/second.txt", "", "", .tGetStatus2, .tGetBody2)
    Do $$$AssertStatusOK(tSC, "GET second.txt completed")
    Do $$$AssertEquals(tGetStatus2, 200, "GET second.txt returns 200")
    Do $$$AssertEquals(tGetBody2, "Second file content", "second.txt content correct")
}

/// <p>Helper to make multipart HTTP request.</p>
ClassMethod MakeMultipartRequest(pMethod As %String, pPath As %String, pContentType As %String, pBody As %String, Output pStatusCode As %Integer, Output pRespBody) As %Status
{
    Set tSC = $$$OK
    Set pStatusCode = 0
    Set pRespBody = ""
    Try {
        Set tReq = ##class(%Net.HttpRequest).%New()
        Set tReq.Server = "localhost"
        Set tReq.Port = 52773
        Set tReq.Username = "_SYSTEM"
        Set tReq.Password = "SYS"
        Set tReq.ContentType = pContentType
        If pBody '= "" {
            Do tReq.EntityBody.Write(pBody)
        }
        Set tFullPath = "/iris-couch" _ pPath
        If pMethod = "PUT" {
            Set tSC = tReq.Put(tFullPath)
        } ElseIf pMethod = "POST" {
            Set tSC = tReq.Post(tFullPath)
        }
        If $$$ISERR(tSC) Quit
        Set pStatusCode = tReq.HttpResponse.StatusCode
        Set tRespStr = tReq.HttpResponse.Data.Read()
        If tRespStr '= "" {
            Set tFirstChar = $Extract($ZStrip(tRespStr, "<W"), 1)
            If (tFirstChar = "{") || (tFirstChar = "[") {
                Set pRespBody = ##class(%DynamicAbstractObject).%FromJSON(tRespStr)
            } Else {
                Set pRespBody = tRespStr
            }
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

}
