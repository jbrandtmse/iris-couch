/// <p>HTTP integration tests for IRISCouch attachment endpoints.</p>
/// <p>Tests <code>PUT /{db}/{docid}/{attname}</code>,
/// <code>GET /{db}/{docid}/{attname}</code>, and
/// <code>DELETE /{db}/{docid}/{attname}</code> via live HTTP requests.
/// Covers AC #1, #5, #8, #9, #12.</p>
Class IRISCouch.Test.AttachmentHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create a test database and document before each test.</p>
Method OnBeforeOneTest() As %Status
{
    ; Clean up any previous state
    Kill ^IRISCouch.DB("testatthttp")
    Kill ^IRISCouch.Docs("testatthttp")
    Kill ^IRISCouch.Tree("testatthttp")
    Kill ^IRISCouch.Changes("testatthttp")
    Kill ^IRISCouch.Seq("testatthttp")
    Kill ^IRISCouch.Atts("testatthttp")
    ; Create test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testatthttp")
    If $$$ISERR(tSC) Quit tSC
    ; Create a test document
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testatthttp", "testdoc", "{""name"":""attachment test""}")
    If tRev = "" Quit $$$ERROR($$$GeneralError, "Failed to create test document")
    Quit $$$OK
}

/// <p>Delete test database and kill all globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testatthttp")
    Kill ^IRISCouch.Docs("testatthttp")
    Kill ^IRISCouch.Tree("testatthttp")
    Kill ^IRISCouch.Changes("testatthttp")
    Kill ^IRISCouch.Seq("testatthttp")
    Kill ^IRISCouch.Atts("testatthttp")
    Quit $$$OK
}

/// <p>Helper to get current winner rev for test document.</p>
ClassMethod GetCurrentRev() As %String
{
    Quit ##class(IRISCouch.Storage.RevTree).GetWinner("testatthttp", "testdoc")
}

/// <p>Helper to make a binary HTTP request with custom content type.</p>
/// <p>Unlike the standard MakeRequest which sets application/json, this method
/// allows arbitrary content types for binary attachment uploads.</p>
/// @param pMethod HTTP method
/// @param pPath Request path
/// @param pContentType Content-Type header for the request
/// @param pBinaryContent Binary content string to send
/// @param Output pStatusCode HTTP status code
/// @param Output pRespBody Parsed response body or raw string
/// @return %Status
ClassMethod MakeBinaryRequest(pMethod As %String, pPath As %String, pContentType As %String, pBinaryContent As %String, Output pStatusCode As %Integer, Output pRespBody) As %Status
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
        ; Write binary body
        If pBinaryContent '= "" {
            Do tReq.EntityBody.Write(pBinaryContent)
        }
        ; Build full path with webapp prefix
        Set tFullPath = "/iris-couch" _ pPath
        If pMethod = "GET" {
            Set tSC = tReq.Get(tFullPath)
        } ElseIf pMethod = "PUT" {
            Set tSC = tReq.Put(tFullPath)
        } ElseIf pMethod = "DELETE" {
            Set tSC = tReq.Delete(tFullPath)
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

/// <p>AC #1: PUT attachment returns 201 with new rev.</p>
Method TestPutAttachment()
{
    Set tRev = ..GetCurrentRev()
    Set tContent = "Hello from attachment test!"
    Set tSC = ..MakeBinaryRequest("PUT", "/testatthttp/testdoc/hello.txt?rev="_tRev, "text/plain", tContent, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "PUT attachment request completed")
    Do $$$AssertEquals(tStatus, 201, "PUT attachment returns HTTP 201")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertTrue(tBody.ok, "Response has ok: true")
    Do $$$AssertEquals(tBody.id, "testdoc", "Response id matches")
    Do $$$AssertTrue(tBody.rev '= "", "Response has non-empty rev")
    Do $$$AssertEquals($Piece(tBody.rev, "-", 1), 2, "Rev is generation 2")
}

/// <p>AC #5: GET attachment returns binary content with correct Content-Type.</p>
Method TestGetAttachment()
{
    ; First PUT an attachment
    Set tRev = ..GetCurrentRev()
    Set tContent = "Get me back!"
    Set tSC = ..MakeBinaryRequest("PUT", "/testatthttp/testdoc/getme.txt?rev="_tRev, "text/plain", tContent, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "PUT attachment completed")
    Do $$$AssertEquals(tStatus, 201, "PUT returns 201")
    ; GET the attachment
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "localhost"
    Set tReq.Port = 52773
    Set tReq.Username = "_SYSTEM"
    Set tReq.Password = "SYS"
    Set tSC = tReq.Get("/iris-couch/testatthttp/testdoc/getme.txt")
    Do $$$AssertStatusOK(tSC, "GET attachment request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "GET attachment returns HTTP 200")
    ; Check content type
    Set tRespType = tReq.HttpResponse.ContentType
    Do $$$AssertTrue(tRespType [ "text/plain", "Content-Type is text/plain")
    ; Check content matches
    Set tRespContent = tReq.HttpResponse.Data.Read()
    Do $$$AssertEquals(tRespContent, "Get me back!", "Content matches original")
}

/// <p>AC #8: GET missing attachment returns 404.</p>
Method TestGetMissingAttachment()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testatthttp/testdoc/nonexistent.txt", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET missing attachment request completed")
    Do $$$AssertEquals(tStatus, 404, "GET missing attachment returns HTTP 404")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found")
}

/// <p>AC #12: DELETE attachment returns 200 with new rev.</p>
Method TestDeleteAttachment()
{
    ; PUT an attachment first
    Set tRev = ..GetCurrentRev()
    Set tContent = "Delete this!"
    Set tSC = ..MakeBinaryRequest("PUT", "/testatthttp/testdoc/deleteme.txt?rev="_tRev, "text/plain", tContent, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "PUT attachment completed")
    Do $$$AssertEquals(tStatus, 201, "PUT returns 201")
    Set tNewRev = tBody.rev
    ; DELETE the attachment
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testatthttp/testdoc/deleteme.txt?rev="_tNewRev, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "DELETE attachment request completed")
    Do $$$AssertEquals(tStatus, 200, "DELETE attachment returns HTTP 200")
    Do $$$AssertTrue(tBody.ok, "Response has ok: true")
    Do $$$AssertTrue(tBody.rev '= "", "Response has new rev")
    Do $$$AssertEquals($Piece(tBody.rev, "-", 1), 3, "Rev is generation 3")
    ; Verify GET now returns 404
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testatthttp/testdoc/deleteme.txt", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET deleted attachment request completed")
    Do $$$AssertEquals(tStatus, 404, "GET deleted attachment returns 404")
}

/// <p>AC #9: PUT without rev on existing doc returns 409.</p>
Method TestPutWithoutRevConflict()
{
    Set tContent = "conflict test"
    Set tSC = ..MakeBinaryRequest("PUT", "/testatthttp/testdoc/conflict.txt", "text/plain", tContent, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "PUT without rev request completed")
    Do $$$AssertEquals(tStatus, 409, "PUT without rev returns HTTP 409")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertEquals(tBody.error, "conflict", "Error slug is conflict")
}

/// <p>AC #8: PUT on non-existent database returns 404.</p>
Method TestPutNonExistentDatabase()
{
    Set tContent = "no db"
    Set tSC = ..MakeBinaryRequest("PUT", "/nosuchdb/doc1/file.txt", "text/plain", tContent, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "PUT to non-existent db request completed")
    Do $$$AssertEquals(tStatus, 404, "PUT to non-existent db returns HTTP 404")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found")
}

}
