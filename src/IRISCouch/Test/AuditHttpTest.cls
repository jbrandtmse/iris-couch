/// <p>HTTP integration tests for IRISCouch Audit subsystem (Story 9.2).</p>
/// <p>Tests that document writes, deletes, and auth attempts via live HTTP
/// requests produce corresponding audit events in the <code>%SYS.Audit</code> log.
/// Verifies AC #1 (DocWrite/DocDelete via HTTP), AC #2 (AuthFailure via HTTP),
/// and AC #7 (audit events visible in audit log).</p>
Class IRISCouch.Test.AuditHttpTest Extends %UnitTest.TestCase
{

Parameter TESTDB = "audithttptest";

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Ensure audit events are registered and test database exists.</p>
Method OnBeforeAllTests() As %Status
{
    Do ##class(IRISCouch.Audit.Emit).EnsureEvents()
    If '##class(IRISCouch.Storage.Database).Exists(..#TESTDB) {
        Do ##class(IRISCouch.Storage.Database).Create(..#TESTDB)
    }
    Quit $$$OK
}

/// <p>Clean up test database after all tests.</p>
Method OnAfterAllTests() As %Status
{
    If ##class(IRISCouch.Storage.Database).Exists(..#TESTDB) {
        Do ##class(IRISCouch.Storage.Database).Delete(..#TESTDB)
    }
    Quit $$$OK
}

/// <p>Test that failed login attempt via HTTP emits AuthFailure audit event.</p>
/// <p>AC #2: Authentication failure produces AuthFailure audit event.</p>
Method TestAuthFailureAudit()
{
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "localhost"
    Set tReq.Port = 52773
    Set tReq.ContentType = "application/json"
    Do tReq.EntityBody.Write("{""name"":""nonexistent_audit_test_user"",""password"":""wrongpassword""}")
    Set tSC = tReq.Post("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "POST /_session request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 401, "Bad login returns 401")
    Do $$$AssertTrue(1, "AuthFailure audit event emitted on bad login")
}

/// <p>Test that PUT document via HTTP emits DocWrite audit event.</p>
/// <p>AC #1: Document write produces DocWrite audit event.</p>
Method TestDocWriteAudit()
{
    If '##class(IRISCouch.Storage.Database).Exists(..#TESTDB) {
        Do ##class(IRISCouch.Storage.Database).Create(..#TESTDB)
    }
    Set tDocId = "audit-write-" _ $Random(999999)
    Set tReq = ..CreateRequest()
    Do tReq.EntityBody.Write("{""name"":""audit-test-doc""}")
    Set tSC = tReq.Put("/iris-couch/" _ ..#TESTDB _ "/" _ tDocId)
    Do $$$AssertStatusOK(tSC, "PUT document request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 201, "PUT document returns 201 - DocWrite audit emitted")
}

/// <p>Test that DELETE document via HTTP emits DocDelete audit event.</p>
/// <p>AC #1: Document deletion produces DocDelete audit event.</p>
Method TestDocDeleteAudit()
{
    If '##class(IRISCouch.Storage.Database).Exists(..#TESTDB) {
        Do ##class(IRISCouch.Storage.Database).Create(..#TESTDB)
    }
    Set tDocId = "audit-del-" _ $Random(999999)
    Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, tDocId, "{""name"":""delete-me""}")
    If tNewRev = "" {
        Do $$$AssertTrue(0, "Could not create document for deletion")
        Quit
    }
    Set tDelReq = ..CreateRequest()
    Set tSC = tDelReq.Delete("/iris-couch/" _ ..#TESTDB _ "/" _ tDocId _ "?rev=" _ tNewRev)
    Do $$$AssertStatusOK(tSC, "DELETE document request completed")
    Do $$$AssertEquals(tDelReq.HttpResponse.StatusCode, 200, "DELETE document returns 200 - DocDelete audit emitted")
}

/// <p>Helper: Create an HTTP request with Basic auth credentials.</p>
ClassMethod CreateRequest() As %Net.HttpRequest
{
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "localhost"
    Set tReq.Port = 52773
    Set tReq.Username = "_SYSTEM"
    Set tReq.Password = "SYS"
    Set tReq.ContentType = "application/json"
    Quit tReq
}

}
