/// <p>Unit tests for IRISCouch _users database management.</p>
/// <p>Tests username extraction, _users database detection, password hashing,
/// IRIS user synchronization, and password stripping from documents.
/// Covers <class>IRISCouch.Auth.Users</class> methods.</p>
Class IRISCouch.Test.UsersTest Extends %UnitTest.TestCase
{

/// <p>Test username used during tests.</p>
Property TestUsername As %String [ InitialExpression = "ictestuser73" ];

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up test IRIS users after each test to avoid polluting security config.</p>
Method OnAfterOneTest() As %Status
{
    Try {
        ; Clean up any test IRIS users
        Do ..CleanupTestUser(..TestUsername)
        Do ..CleanupTestUser("ictestalice")
        Do ..CleanupTestUser("ictestbob")
        Do ..CleanupTestUser("ictestupdpwd")
        ; Clean up _users database if it exists
        If ##class(IRISCouch.Storage.Database).Exists("_users") {
            Do ##class(IRISCouch.Storage.Database).Delete("_users")
        }
    }
    Catch ex {
        ; Swallow cleanup errors
    }
    Quit $$$OK
}

/// <p>Test extracting username from valid CouchDB user document IDs.</p>
/// <p>AC #1: org.couchdb.user:alice -> alice</p>
Method TestExtractUsername()
{
    ; Valid format
    Do $$$AssertEquals(##class(IRISCouch.Auth.Users).ExtractUsername("org.couchdb.user:alice"), "alice", "Extract 'alice' from valid doc ID")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Users).ExtractUsername("org.couchdb.user:bob"), "bob", "Extract 'bob' from valid doc ID")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Users).ExtractUsername("org.couchdb.user:admin_user"), "admin_user", "Extract 'admin_user' from valid doc ID")
    ; Invalid formats
    Do $$$AssertEquals(##class(IRISCouch.Auth.Users).ExtractUsername("alice"), "", "Plain name returns empty")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Users).ExtractUsername(""), "", "Empty string returns empty")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Users).ExtractUsername("org.couchdb.user:"), "", "Prefix only with no name returns empty")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Users).ExtractUsername("wrongprefix:alice"), "", "Wrong prefix returns empty")
}

/// <p>Test IsUsersDB identifies _users database correctly.</p>
Method TestIsUsersDB()
{
    Do $$$AssertTrue(##class(IRISCouch.Auth.Users).IsUsersDB("_users"), "_users returns true")
    Do $$$AssertTrue('##class(IRISCouch.Auth.Users).IsUsersDB("mydb"), "mydb returns false")
    Do $$$AssertTrue('##class(IRISCouch.Auth.Users).IsUsersDB("users"), "users (no underscore) returns false")
    Do $$$AssertTrue('##class(IRISCouch.Auth.Users).IsUsersDB("_replicator"), "_replicator returns false")
    Do $$$AssertTrue('##class(IRISCouch.Auth.Users).IsUsersDB(""), "empty string returns false")
}

/// <p>Test that OnUserDocSave strips password and adds metadata fields.</p>
/// <p>AC #3: Document stores password_scheme, derived_key, salt, iterations, pbkdf2_prf
/// but NOT the plaintext password.</p>
Method TestOnUserDocSaveStripsPassword()
{
    Set tBody = ##class(%DynamicObject).%FromJSON("{""name"":""ictestalice"",""password"":""mysecret"",""roles"":[],""type"":""user""}")
    Set tResult = ##class(IRISCouch.Auth.Users).OnUserDocSave("_users", "org.couchdb.user:ictestalice", tBody)
    ; Password must be stripped
    Do $$$AssertTrue(tResult.%Get("password") = "", "Password field is stripped from result")
    ; Metadata fields must be present
    Do $$$AssertEquals(tResult.%Get("password_scheme"), "pbkdf2", "password_scheme is pbkdf2")
    Do $$$AssertEquals(tResult.%Get("pbkdf2_prf"), "sha256", "pbkdf2_prf is sha256")
    Do $$$AssertEquals(tResult.iterations, 10000, "iterations is 10000")
    Do $$$AssertTrue(tResult.%Get("derived_key") '= "", "derived_key is non-empty")
    Do $$$AssertTrue(tResult.%Get("salt") '= "", "salt is non-empty")
    ; Original fields preserved
    Do $$$AssertEquals(tResult.%Get("name"), "ictestalice", "name field preserved")
    Do $$$AssertEquals(tResult.%Get("type"), "user", "type field preserved")
}

/// <p>Test that OnUserDocSave creates a corresponding IRIS user.</p>
/// <p>AC #1: PUT to _users creates a corresponding IRIS user record via Security.Users.</p>
Method TestOnUserDocSaveCreatesIRISUser()
{
    Set tBody = ##class(%DynamicObject).%FromJSON("{""name"":""ictestbob"",""password"":""bobpass123"",""roles"":[],""type"":""user""}")
    Set tResult = ##class(IRISCouch.Auth.Users).OnUserDocSave("_users", "org.couchdb.user:ictestbob", tBody)
    ; Verify IRIS user was created
    Set tOrigNS = $Namespace
    Set $Namespace = "%SYS"
    Set tExists = ""
    Do ##class(Security.Users).Exists("ictestbob", .tExists)
    Set $Namespace = tOrigNS
    Do $$$AssertTrue(tExists '= "", "IRIS user 'ictestbob' was created via Security.Users")
}

/// <p>Test that OnUserDocDelete removes the IRIS user.</p>
/// <p>AC #5: Deleting a user document removes the corresponding IRIS user record.</p>
Method TestOnUserDocDeleteRemovesIRISUser()
{
    ; First create the user
    Set tBody = ##class(%DynamicObject).%FromJSON("{""name"":""ictestalice"",""password"":""alicepass"",""roles"":[],""type"":""user""}")
    Do ##class(IRISCouch.Auth.Users).OnUserDocSave("_users", "org.couchdb.user:ictestalice", tBody)
    ; Verify user exists
    Set tOrigNS = $Namespace
    Set $Namespace = "%SYS"
    Set tExists = ""
    Do ##class(Security.Users).Exists("ictestalice", .tExists)
    Set $Namespace = tOrigNS
    Do $$$AssertTrue(tExists '= "", "IRIS user 'ictestalice' exists before delete")
    ; Delete the user
    Do ##class(IRISCouch.Auth.Users).OnUserDocDelete("_users", "org.couchdb.user:ictestalice")
    ; Verify user was removed
    Set tOrigNS = $Namespace
    Set $Namespace = "%SYS"
    Set tExists2 = ""
    Do ##class(Security.Users).Exists("ictestalice", .tExists2)
    Set $Namespace = tOrigNS
    Do $$$AssertTrue(tExists2 = "", "IRIS user 'ictestalice' was removed after delete")
}

/// <p>Test that saving a user document via DocumentEngine strips the password.</p>
/// <p>AC #7: GET returns the user document WITHOUT any plaintext password.</p>
Method TestPasswordNotInDocument()
{
    ; Create the _users database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("_users")
    Do $$$AssertStatusOK(tSC, "_users database created")
    ; Save a user document via DocumentEngine
    Set tDocId = "org.couchdb.user:" _ ..TestUsername
    Set tBody = "{""name"":""" _ ..TestUsername _ """,""password"":""testpass"",""roles"":[],""type"":""user""}"
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("_users", tDocId, tBody)
    Do $$$AssertTrue(tRev '= "", "Document saved with revision: " _ tRev)
    ; Read the document back
    Set tStored = ##class(IRISCouch.Storage.Document).Read("_users", tDocId, tRev)
    Do $$$AssertTrue(tStored '= "", "Stored document is non-empty")
    ; Parse and verify no password
    Set tObj = ##class(%DynamicObject).%FromJSON(tStored)
    Do $$$AssertTrue(tObj.%Get("password") = "", "Stored document has no password field")
    Do $$$AssertEquals(tObj.%Get("password_scheme"), "pbkdf2", "Stored document has password_scheme")
    Do $$$AssertTrue(tObj.%Get("derived_key") '= "", "Stored document has derived_key")
    Do $$$AssertTrue(tObj.%Get("salt") '= "", "Stored document has salt")
}

/// <p>Test that updating a user document with a new password updates the IRIS user.</p>
/// <p>AC #4: Updating a user document with a new password field updates the IRIS user record.</p>
Method TestPasswordUpdate()
{
    ; Create the _users database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("_users")
    Do $$$AssertStatusOK(tSC, "_users database created")
    ; Create initial user
    Set tDocId = "org.couchdb.user:ictestupdpwd"
    Set tBody1 = "{""name"":""ictestupdpwd"",""password"":""oldpass"",""roles"":[],""type"":""user""}"
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("_users", tDocId, tBody1)
    Do $$$AssertTrue(tRev1 '= "", "Initial user document saved")
    ; Read back first version
    Set tStored1 = ##class(IRISCouch.Storage.Document).Read("_users", tDocId, tRev1)
    Set tObj1 = ##class(%DynamicObject).%FromJSON(tStored1)
    Set tOldDK = tObj1.%Get("derived_key")
    ; Update with new password
    Set tBody2 = "{""name"":""ictestupdpwd"",""password"":""newpass"",""roles"":[],""type"":""user""}"
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("_users", tDocId, tBody2, tRev1)
    Do $$$AssertTrue(tRev2 '= "", "Updated user document saved")
    ; Read back updated version
    Set tStored2 = ##class(IRISCouch.Storage.Document).Read("_users", tDocId, tRev2)
    Set tObj2 = ##class(%DynamicObject).%FromJSON(tStored2)
    ; New derived_key should be different (new salt + new password)
    Set tNewDK = tObj2.%Get("derived_key")
    Do $$$AssertTrue(tNewDK '= tOldDK, "Derived key changed after password update")
    ; Password still stripped
    Do $$$AssertTrue(tObj2.%Get("password") = "", "Password still stripped after update")
}

/// <p>Test PBKDF2-SHA256 with known test vector.</p>
Method TestPBKDF2SHA256KnownVector()
{
    ; RFC 6070 / known test vector: password="password", salt="salt", c=1, dkLen=20
    ; Expected: 120fb6cffcf8b32c43e7225256c4f837a86548c9
    Set tDK = ##class(IRISCouch.Auth.Users).PBKDF2SHA256("password", "salt", 1, 20)
    Set tHex = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD(tDK), "L")
    Do $$$AssertEquals(tHex, "120fb6cffcf8b32c43e7225256c4f837a86548c9", "PBKDF2-SHA256 matches known test vector")
}

/// <p>Test ExtractRoles with various role arrays.</p>
Method TestExtractRoles()
{
    ; Empty roles
    Set tBody1 = ##class(%DynamicObject).%FromJSON("{""roles"":[]}")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Users).ExtractRoles(tBody1), "", "Empty roles array returns empty string")
    ; Single role
    Set tBody2 = ##class(%DynamicObject).%FromJSON("{""roles"":[""admin""]}")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Users).ExtractRoles(tBody2), "admin", "Single role extracted correctly")
    ; Multiple roles
    Set tBody3 = ##class(%DynamicObject).%FromJSON("{""roles"":[""admin"",""editor""]}")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Users).ExtractRoles(tBody3), "admin,editor", "Multiple roles comma-separated")
    ; No roles field
    Set tBody4 = ##class(%DynamicObject).%FromJSON("{""name"":""test""}")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Users).ExtractRoles(tBody4), "", "Missing roles field returns empty string")
}

/// <p>Test that non-_users databases are not affected.</p>
Method TestNonUsersDatabaseNotAffected()
{
    ; OnUserDocSave on a regular database should return body unchanged
    Set tBody = ##class(%DynamicObject).%FromJSON("{""name"":""alice"",""password"":""secret"",""type"":""user""}")
    Set tResult = ##class(IRISCouch.Auth.Users).OnUserDocSave("mydb", "org.couchdb.user:alice", tBody)
    ; Body should be returned as-is (password NOT stripped for non-_users)
    Do $$$AssertEquals(tResult.%Get("password"), "secret", "Password not stripped for non-_users database")
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
