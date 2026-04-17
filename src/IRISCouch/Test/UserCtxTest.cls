/// <p>Unit tests for the Story 12.3 userCtx / secObj builders.</p>
Class IRISCouch.Test.UserCtxTest Extends %UnitTest.TestCase
{

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Kill %IRISCouchUser, %IRISCouchRoles
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Kill %IRISCouchUser, %IRISCouchRoles
    Quit $$$OK
}

/// <p>Anonymous → admin-party default: name=null, roles=["_admin"].</p>
Method TestBuildUserCtxAnonymous()
{
    Set tCtx = ##class(IRISCouch.Auth.Session).BuildUserCtx()
    Do $$$AssertTrue($IsObject(tCtx), "Returns an object")
    ; name should be JSON null (emitted as "null" type)
    Set tJson = tCtx.%ToJSON()
    Do $$$AssertTrue(tJson [ "\""name\"":null" || (tJson [ """name"":null"), "Anonymous → name JSON null")
    Set tRoles = tCtx.roles
    Do $$$AssertEquals(tRoles.%Size(), 1, "One default role")
    Do $$$AssertEquals(tRoles.%Get(0), "_admin", "admin-party default role")
}

/// <p>Authenticated → name and roles reflect %IRISCouch* process-private vars.</p>
Method TestBuildUserCtxAuthenticated()
{
    Set %IRISCouchUser = "alice"
    Set %IRISCouchRoles = []
    Do %IRISCouchRoles.%Push("reader")
    Do %IRISCouchRoles.%Push("writer")
    Set tCtx = ##class(IRISCouch.Auth.Session).BuildUserCtx()
    Do $$$AssertEquals(tCtx.name, "alice", "name = %IRISCouchUser")
    Set tRoles = tCtx.roles
    Do $$$AssertEquals(tRoles.%Size(), 2, "two roles")
    Do $$$AssertEquals(tRoles.%Get(0), "reader", "first role")
    Do $$$AssertEquals(tRoles.%Get(1), "writer", "second role")
}

/// <p>Auth.Security.Get returns the empty/default secObj when never set.</p>
Method TestSecurityGetDefault()
{
    Kill ^IRISCouch.Security("ucsectest123")
    Set tSec = ##class(IRISCouch.Auth.Security).Get("ucsectest123")
    Do $$$AssertTrue($IsObject(tSec.admins), "admins object present")
    Do $$$AssertTrue($IsObject(tSec.members), "members object present")
    Do $$$AssertEquals(tSec.admins.names.%Size(), 0, "admins.names empty")
    Do $$$AssertEquals(tSec.admins.roles.%Size(), 0, "admins.roles empty")
    Do $$$AssertEquals(tSec.members.names.%Size(), 0, "members.names empty")
    Do $$$AssertEquals(tSec.members.roles.%Size(), 0, "members.roles empty")
}

}
