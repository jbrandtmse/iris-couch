/// <p>Unit tests for IRISCouch per-database security configuration.</p>
/// <p>Tests Auth.Security Put/Get/Delete/Exists/CheckAccess methods
/// including open access, member enforcement, admin enforcement,
/// server admin bypass, and role matching.</p>
Class IRISCouch.Test.SecurityTest Extends %UnitTest.TestCase
{

/// <p>Test database name used for security tests.</p>
Parameter TESTDB = "securitytestdb";

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Set up a test database before each test.</p>
Method OnBeforeOneTest() As %Status
{
    ; Create test database if it doesn't exist
    If '##class(IRISCouch.Storage.Database).Exists(..#TESTDB) {
        Do ##class(IRISCouch.Storage.Database).Create(..#TESTDB)
    }
    ; Clean up any security config from previous test
    Kill ^IRISCouch.Security(..#TESTDB)
    Quit $$$OK
}

/// <p>Clean up test database after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.Security(..#TESTDB)
    If ##class(IRISCouch.Storage.Database).Exists(..#TESTDB) {
        Do ##class(IRISCouch.Storage.Database).Delete(..#TESTDB)
    }
    Quit $$$OK
}

/// <p>Test storing and retrieving a security object.</p>
/// <p>AC #1, #2: PUT stores security config, GET retrieves it correctly.</p>
Method TestPutAndGetSecurity()
{
    ; Build security object
    Set tSecObj = {"admins":{"names":["admin1"],"roles":["db-admin"]},"members":{"names":["user1"],"roles":["reader"]}}
    ; Store it
    Set tSC = ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Do $$$AssertStatusOK(tSC, "Put security config succeeds")
    ; Retrieve it
    Set tResult = ##class(IRISCouch.Auth.Security).Get(..#TESTDB)
    Do $$$AssertTrue($IsObject(tResult), "Get returns an object")
    ; Verify admins
    Do $$$AssertEquals(tResult.admins.names.%Get(0), "admin1", "Admin name matches")
    Do $$$AssertEquals(tResult.admins.roles.%Get(0), "db-admin", "Admin role matches")
    ; Verify members
    Do $$$AssertEquals(tResult.members.names.%Get(0), "user1", "Member name matches")
    Do $$$AssertEquals(tResult.members.roles.%Get(0), "reader", "Member role matches")
}

/// <p>Test that Get on a DB with no security returns defaults (empty arrays).</p>
/// <p>AC #5: Empty security = open access.</p>
Method TestEmptySecurityReturnsDefaults()
{
    ; Get on DB with no security set
    Set tResult = ##class(IRISCouch.Auth.Security).Get(..#TESTDB)
    Do $$$AssertTrue($IsObject(tResult), "Get returns an object for empty DB")
    Do $$$AssertTrue($IsObject(tResult.admins), "admins exists")
    Do $$$AssertTrue($IsObject(tResult.members), "members exists")
    Do $$$AssertEquals(tResult.admins.names.%Size(), 0, "admins.names is empty")
    Do $$$AssertEquals(tResult.admins.roles.%Size(), 0, "admins.roles is empty")
    Do $$$AssertEquals(tResult.members.names.%Size(), 0, "members.names is empty")
    Do $$$AssertEquals(tResult.members.roles.%Size(), 0, "members.roles is empty")
}

/// <p>Test that CheckAccess on a DB with no security config allows any user.</p>
/// <p>AC #5: No _security config = open access.</p>
Method TestCheckAccessOpenDB()
{
    ; No security config set on test DB
    Set tRoles = ["regularuser"]
    Set tAllowed = ##class(IRISCouch.Auth.Security).CheckAccess(..#TESTDB, "anyuser", tRoles, 0)
    Do $$$AssertTrue(tAllowed, "Open DB allows any user")
    ; Even admin operations should pass on open DB
    Set tAllowed2 = ##class(IRISCouch.Auth.Security).CheckAccess(..#TESTDB, "anyuser", tRoles, 1)
    Do $$$AssertTrue(tAllowed2, "Open DB allows admin ops from any user")
}

/// <p>Test that a user in members.names is allowed member access.</p>
/// <p>AC #3: Member in names list is allowed.</p>
Method TestCheckAccessMemberAllowed()
{
    ; Set security with member restrictions
    Set tSecObj = {"admins":{"names":["admin1"],"roles":[]},"members":{"names":["user1","user2"],"roles":[]}}
    Set tSC = ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Do $$$AssertStatusOK(tSC, "Put security config succeeds")
    ; user1 should be allowed member access
    Set tRoles = []
    Set tAllowed = ##class(IRISCouch.Auth.Security).CheckAccess(..#TESTDB, "user1", tRoles, 0)
    Do $$$AssertTrue(tAllowed, "Member in names list is allowed access")
}

/// <p>Test that a user NOT in members is denied member access.</p>
/// <p>AC #3: Non-member is denied access.</p>
Method TestCheckAccessMemberDenied()
{
    ; Set security with member restrictions
    Set tSecObj = {"admins":{"names":["admin1"],"roles":[]},"members":{"names":["user1"],"roles":["reader"]}}
    Set tSC = ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Do $$$AssertStatusOK(tSC, "Put security config succeeds")
    ; stranger should be denied member access
    Set tRoles = ["otherrole"]
    Set tAllowed = ##class(IRISCouch.Auth.Security).CheckAccess(..#TESTDB, "stranger", tRoles, 0)
    Do $$$AssertTrue('tAllowed, "Non-member is denied access")
}

/// <p>Test that a user in admins.names is allowed admin operations.</p>
/// <p>AC #4: Admin in names list is allowed admin ops.</p>
Method TestCheckAccessAdminAllowed()
{
    ; Set security with admin restrictions
    Set tSecObj = {"admins":{"names":["admin1"],"roles":["db-admin"]},"members":{"names":["user1"],"roles":[]}}
    Set tSC = ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Do $$$AssertStatusOK(tSC, "Put security config succeeds")
    ; admin1 should be allowed admin operations
    Set tRoles = []
    Set tAllowed = ##class(IRISCouch.Auth.Security).CheckAccess(..#TESTDB, "admin1", tRoles, 1)
    Do $$$AssertTrue(tAllowed, "DB admin in names list is allowed admin operations")
}

/// <p>Test that a member user is denied admin operations.</p>
/// <p>AC #4: Member (non-admin) is denied admin ops.</p>
Method TestCheckAccessAdminDenied()
{
    ; Set security with admin restrictions
    Set tSecObj = {"admins":{"names":["admin1"],"roles":[]},"members":{"names":["user1"],"roles":[]}}
    Set tSC = ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Do $$$AssertStatusOK(tSC, "Put security config succeeds")
    ; user1 (member only) should be denied admin operations
    Set tRoles = []
    Set tAllowed = ##class(IRISCouch.Auth.Security).CheckAccess(..#TESTDB, "user1", tRoles, 1)
    Do $$$AssertTrue('tAllowed, "Member is denied admin operations")
}

/// <p>Test that a server admin (_admin role) bypasses all security restrictions.</p>
/// <p>AC #7: Server admins bypass _security.</p>
Method TestCheckAccessServerAdminBypass()
{
    ; Set strict security — no one in names/roles
    Set tSecObj = {"admins":{"names":["admin1"],"roles":[]},"members":{"names":["user1"],"roles":[]}}
    Set tSC = ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Do $$$AssertStatusOK(tSC, "Put security config succeeds")
    ; Server admin with _admin role should bypass
    Set tAdminRoles = ["_admin"]
    Set tAllowed = ##class(IRISCouch.Auth.Security).CheckAccess(..#TESTDB, "serveradmin", tAdminRoles, 1)
    Do $$$AssertTrue(tAllowed, "Server admin with _admin role bypasses security")
    ; Server admin with %All role should bypass
    Set tAllRoles = ["%All"]
    Set tAllowed2 = ##class(IRISCouch.Auth.Security).CheckAccess(..#TESTDB, "_SYSTEM", tAllRoles, 1)
    Do $$$AssertTrue(tAllowed2, "Server admin with %All role bypasses security")
}

/// <p>Test that a user with matching role (not name) is allowed access.</p>
/// <p>AC #3: Role match grants access.</p>
Method TestCheckAccessRoleMatch()
{
    ; Set security with role-based member restrictions
    Set tSecObj = {"admins":{"names":[],"roles":["db-admin"]},"members":{"names":[],"roles":["reader","writer"]}}
    Set tSC = ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Do $$$AssertStatusOK(tSC, "Put security config succeeds")
    ; User with matching member role should be allowed
    Set tRoles = ["reader"]
    Set tAllowed = ##class(IRISCouch.Auth.Security).CheckAccess(..#TESTDB, "roleuser", tRoles, 0)
    Do $$$AssertTrue(tAllowed, "User with matching member role is allowed")
    ; User with matching admin role should be allowed admin ops
    Set tAdminRoles = ["db-admin"]
    Set tAllowed2 = ##class(IRISCouch.Auth.Security).CheckAccess(..#TESTDB, "roleadmin", tAdminRoles, 1)
    Do $$$AssertTrue(tAllowed2, "User with matching admin role is allowed admin ops")
}

/// <p>Test that security config is deleted when DB is deleted.</p>
/// <p>AC #8: _security cleanup on database delete.</p>
Method TestDeleteSecurityOnDBDelete()
{
    ; Set security
    Set tSecObj = {"admins":{"names":["admin1"],"roles":[]},"members":{"names":["user1"],"roles":[]}}
    Set tSC = ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Do $$$AssertStatusOK(tSC, "Put security config succeeds")
    ; Verify it exists
    Do $$$AssertTrue(##class(IRISCouch.Auth.Security).Exists(..#TESTDB), "Security config exists before delete")
    ; Delete the database (which should also delete security)
    Set tSC = ##class(IRISCouch.Storage.Database).Delete(..#TESTDB)
    Do $$$AssertStatusOK(tSC, "Database delete succeeds")
    ; Verify security config is gone
    Do $$$AssertTrue('##class(IRISCouch.Auth.Security).Exists(..#TESTDB), "Security config removed after DB delete")
}

/// <p>Test that admins are automatically treated as super-members.</p>
/// <p>Admins should have access to member operations too.</p>
Method TestAdminIsSuperMember()
{
    ; Set security with member restrictions
    Set tSecObj = {"admins":{"names":["admin1"],"roles":[]},"members":{"names":["user1"],"roles":["reader"]}}
    Set tSC = ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Do $$$AssertStatusOK(tSC, "Put security config succeeds")
    ; admin1 should have member access (admins are super-members)
    Set tRoles = []
    Set tAllowed = ##class(IRISCouch.Auth.Security).CheckAccess(..#TESTDB, "admin1", tRoles, 0)
    Do $$$AssertTrue(tAllowed, "DB admin has member access (super-member)")
}

/// <p>Test Exists method.</p>
Method TestExistsMethod()
{
    ; Before setting, should not exist
    Do $$$AssertTrue('##class(IRISCouch.Auth.Security).Exists(..#TESTDB), "Exists returns false before Put")
    ; After setting, should exist
    Set tSecObj = {"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}
    Set tSC = ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Do $$$AssertStatusOK(tSC, "Put succeeds")
    Do $$$AssertTrue(##class(IRISCouch.Auth.Security).Exists(..#TESTDB), "Exists returns true after Put")
    ; After delete, should not exist
    Do ##class(IRISCouch.Auth.Security).Delete(..#TESTDB)
    Do $$$AssertTrue('##class(IRISCouch.Auth.Security).Exists(..#TESTDB), "Exists returns false after Delete")
}

}
