/// <p>HTTP integration tests for IRISCouch _users database management.</p>
/// <p>Tests user creation, password update, user deletion, metadata presence,
/// and password stripping via live HTTP requests against the REST API.
/// Covers end-to-end flow through Router, DocumentHandler, DocumentEngine,
/// and Auth.Users.</p>
Class IRISCouch.Test.UsersHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up _users database and test IRIS users after each test.</p>
Method OnAfterOneTest() As %Status
{
    Try {
        ; Clean up test IRIS users
        Do ..CleanupTestUser("ichttpuser1")
        Do ..CleanupTestUser("ichttpuser2")
        Do ..CleanupTestUser("ichttpupd1")
        Do ..CleanupTestUser("ichttpdel1")
        Do ..CleanupTestUser("ichttpmeta1")
        ; Clean up _users database
        If ##class(IRISCouch.Storage.Database).Exists("_users") {
            Do ##class(IRISCouch.Storage.Database).Delete("_users")
        }
    }
    Catch ex {
        ; Swallow cleanup errors
    }
    Quit $$$OK
}

/// <p>Test PUT /_users creates the _users database like any other database.</p>
/// <p>AC #6: The _users database is a real IRISCouch database.</p>
Method TestCreateUsersDatabase()
{
    ; Create the _users database via HTTP
    Set tReq = ..CreateRequest()
    Set tSC = tReq.Put("/iris-couch/_users")
    Do $$$AssertStatusOK(tSC, "PUT /_users request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 201, "PUT /_users returns 201")
    ; Verify database exists
    Do $$$AssertTrue(##class(IRISCouch.Storage.Database).Exists("_users"), "_users database exists after PUT")
}

/// <p>Test creating a user via PUT to _users database.</p>
/// <p>AC #1: PUT user doc creates IRIS user. AC #7: GET returns doc without password.</p>
Method TestCreateUser()
{
    ; Create the _users database first
    Set tReq1 = ..CreateRequest()
    Do tReq1.Put("/iris-couch/_users")
    ; Create a user document
    Set tReq = ..CreateRequest()
    Set tUserBody = "{""name"":""ichttpuser1"",""password"":""httptestpass"",""roles"":[],""type"":""user""}"
    Do tReq.EntityBody.Write(tUserBody)
    Set tSC = tReq.Put("/iris-couch/_users/org.couchdb.user:ichttpuser1")
    Do $$$AssertStatusOK(tSC, "PUT user doc request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 201, "PUT user doc returns 201")
    ; GET the document back and verify no password
    Set tReq2 = ..CreateRequest()
    Set tSC2 = tReq2.Get("/iris-couch/_users/org.couchdb.user:ichttpuser1")
    Do $$$AssertStatusOK(tSC2, "GET user doc request completed")
    Do $$$AssertEquals(tReq2.HttpResponse.StatusCode, 200, "GET user doc returns 200")
    Set tBodyStr = tReq2.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertTrue(tBody.%Get("password") = "", "GET response has no password field")
    Do $$$AssertEquals(tBody.%Get("password_scheme"), "pbkdf2", "GET response has password_scheme")
}

/// <p>Test updating a user document with a new password updates IRIS user.</p>
/// <p>AC #4: Updating user doc with new password updates IRIS user record.</p>
Method TestUpdateUserPassword()
{
    ; Create the _users database
    Set tReq0 = ..CreateRequest()
    Do tReq0.Put("/iris-couch/_users")
    ; Create initial user
    Set tReq1 = ..CreateRequest()
    Do tReq1.EntityBody.Write("{""name"":""ichttpupd1"",""password"":""oldpass1"",""roles"":[],""type"":""user""}")
    Set tSC1 = tReq1.Put("/iris-couch/_users/org.couchdb.user:ichttpupd1")
    Do $$$AssertStatusOK(tSC1, "Create user request completed")
    Do $$$AssertEquals(tReq1.HttpResponse.StatusCode, 201, "Create user returns 201")
    ; Get the rev for the update
    Set tRespBody = ##class(%DynamicObject).%FromJSON(tReq1.HttpResponse.Data.Read())
    Set tRev = tRespBody.rev
    Do $$$AssertTrue(tRev '= "", "Got revision from create response: " _ tRev)
    ; Read back first version to get derived_key
    Set tReq2 = ..CreateRequest()
    Do tReq2.Get("/iris-couch/_users/org.couchdb.user:ichttpupd1")
    Set tBody1 = ##class(%DynamicObject).%FromJSON(tReq2.HttpResponse.Data.Read())
    Set tOldDK = tBody1.%Get("derived_key")
    ; Update with new password (include _rev)
    Set tReq3 = ..CreateRequest()
    Set tUpdateBody = "{""name"":""ichttpupd1"",""password"":""newpass2"",""roles"":[],""type"":""user"",""_rev"":""" _ tRev _ """}"
    Do tReq3.EntityBody.Write(tUpdateBody)
    Set tSC3 = tReq3.Put("/iris-couch/_users/org.couchdb.user:ichttpupd1")
    Do $$$AssertStatusOK(tSC3, "Update user request completed")
    Do $$$AssertEquals(tReq3.HttpResponse.StatusCode, 201, "Update user returns 201")
    ; Read back updated version
    Set tReq4 = ..CreateRequest()
    Do tReq4.Get("/iris-couch/_users/org.couchdb.user:ichttpupd1")
    Set tBody2 = ##class(%DynamicObject).%FromJSON(tReq4.HttpResponse.Data.Read())
    Set tNewDK = tBody2.%Get("derived_key")
    Do $$$AssertTrue(tNewDK '= tOldDK, "Derived key changed after password update")
    Do $$$AssertTrue(tBody2.%Get("password") = "", "Password still stripped after update")
}

/// <p>Test deleting a user document removes the IRIS user.</p>
/// <p>AC #5: Deleting a user document removes the corresponding IRIS user record.</p>
Method TestDeleteUser()
{
    ; Create the _users database
    Set tReq0 = ..CreateRequest()
    Do tReq0.Put("/iris-couch/_users")
    ; Create a user
    Set tReq1 = ..CreateRequest()
    Do tReq1.EntityBody.Write("{""name"":""ichttpdel1"",""password"":""delpass"",""roles"":[],""type"":""user""}")
    Set tSC1 = tReq1.Put("/iris-couch/_users/org.couchdb.user:ichttpdel1")
    Do $$$AssertStatusOK(tSC1, "Create user for deletion completed")
    Do $$$AssertEquals(tReq1.HttpResponse.StatusCode, 201, "Create user returns 201")
    ; Verify IRIS user exists
    Set tOrigNS = $Namespace
    Set $Namespace = "%SYS"
    Set tExists = ""
    Do ##class(Security.Users).Exists("ichttpdel1", .tExists)
    Set $Namespace = tOrigNS
    Do $$$AssertTrue(tExists '= "", "IRIS user exists after creation")
    ; Get the rev for deletion
    Set tRespBody = ##class(%DynamicObject).%FromJSON(tReq1.HttpResponse.Data.Read())
    Set tRev = tRespBody.rev
    ; Delete the user document (pass rev as query parameter)
    Set tReq2 = ..CreateRequest()
    Set tSC2 = tReq2.Delete("/iris-couch/_users/org.couchdb.user:ichttpdel1?rev=" _ tRev)
    Do $$$AssertStatusOK(tSC2, "DELETE user request completed")
    Do $$$AssertEquals(tReq2.HttpResponse.StatusCode, 200, "DELETE user returns 200")
    ; Verify IRIS user removed
    Set tOrigNS = $Namespace
    Set $Namespace = "%SYS"
    Set tExists2 = ""
    Do ##class(Security.Users).Exists("ichttpdel1", .tExists2)
    Set $Namespace = tOrigNS
    Do $$$AssertTrue(tExists2 = "", "IRIS user removed after document deletion")
}

/// <p>Test that user doc has all expected CouchDB-compatible metadata fields.</p>
/// <p>AC #3: Document stores password_scheme, derived_key, salt, iterations, pbkdf2_prf.</p>
Method TestUserDocHasMetadata()
{
    ; Create the _users database
    Set tReq0 = ..CreateRequest()
    Do tReq0.Put("/iris-couch/_users")
    ; Create a user
    Set tReq1 = ..CreateRequest()
    Do tReq1.EntityBody.Write("{""name"":""ichttpmeta1"",""password"":""metapass"",""roles"":[],""type"":""user""}")
    Do tReq1.Put("/iris-couch/_users/org.couchdb.user:ichttpmeta1")
    ; GET the document
    Set tReq2 = ..CreateRequest()
    Set tSC = tReq2.Get("/iris-couch/_users/org.couchdb.user:ichttpmeta1")
    Do $$$AssertStatusOK(tSC, "GET user doc request completed")
    Do $$$AssertEquals(tReq2.HttpResponse.StatusCode, 200, "GET user doc returns 200")
    Set tBody = ##class(%DynamicObject).%FromJSON(tReq2.HttpResponse.Data.Read())
    ; Verify all metadata fields
    Do $$$AssertEquals(tBody.%Get("password_scheme"), "pbkdf2", "password_scheme is pbkdf2")
    Do $$$AssertEquals(tBody.%Get("pbkdf2_prf"), "sha256", "pbkdf2_prf is sha256")
    Do $$$AssertTrue(tBody.%Get("derived_key") '= "", "derived_key is present and non-empty")
    Do $$$AssertTrue(tBody.%Get("salt") '= "", "salt is present and non-empty")
    Do $$$AssertEquals(tBody.iterations, 10000, "iterations is 10000")
    ; Verify no password
    Do $$$AssertTrue(tBody.%Get("password") = "", "No password field in response")
    ; Verify original fields preserved
    Do $$$AssertEquals(tBody.%Get("name"), "ichttpmeta1", "name field preserved")
    Do $$$AssertEquals(tBody.%Get("type"), "user", "type field preserved")
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

/// <p>Helper: Clean up a test IRIS user if it exists.</p>
ClassMethod CleanupTestUser(pUsername As %String)
{
    Try {
        Set tOrigNS = $Namespace
        Set $Namespace = "%SYS"
        Set tExists = ""
        Do ##class(Security.Users).Exists(pUsername, .tExists)
        If tExists '= "" {
            Do ##class(Security.Users).Delete(pUsername)
        }
        Set $Namespace = tOrigNS
    }
    Catch ex {
        If $Get(tOrigNS) '= "" Set $Namespace = tOrigNS
    }
}

}
