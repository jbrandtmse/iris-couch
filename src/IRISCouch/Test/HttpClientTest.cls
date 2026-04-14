/// <p>Unit tests for IRISCouch replication HTTP client.</p>
/// <p>Tests URL parsing into server/port/basePath components
/// and basic client configuration.</p>
Class IRISCouch.Test.HttpClientTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Verify URL parsing for standard HTTP URL with port.</p>
Method TestFromUrlParsing()
{
    Set tClient = ##class(IRISCouch.Replication.HttpClient).FromUrl("http://localhost:5984/mydb")
    Do $$$AssertTrue($IsObject(tClient), "FromUrl returns an object")
    Do $$$AssertEquals(tClient.Server, "localhost", "Server parsed correctly")
    Do $$$AssertEquals(tClient.Port, 5984, "Port parsed correctly")
    Do $$$AssertEquals(tClient.BasePath, "/mydb", "BasePath parsed correctly")
    Do $$$AssertEquals(tClient.UseSSL, 0, "UseSSL is false for HTTP")
}

/// <p>Verify HTTPS URL parsing.</p>
Method TestFromUrlHTTPS()
{
    Set tClient = ##class(IRISCouch.Replication.HttpClient).FromUrl("https://couch.example.com/production")
    Do $$$AssertTrue($IsObject(tClient), "FromUrl returns an object for HTTPS")
    Do $$$AssertEquals(tClient.Server, "couch.example.com", "Server parsed correctly for HTTPS")
    Do $$$AssertEquals(tClient.Port, 443, "Port defaults to 443 for HTTPS")
    Do $$$AssertEquals(tClient.BasePath, "/production", "BasePath parsed correctly")
    Do $$$AssertEquals(tClient.UseSSL, 1, "UseSSL is true for HTTPS")
}

/// <p>Verify URL parsing with embedded credentials.</p>
Method TestFromUrlWithCredentials()
{
    Set tClient = ##class(IRISCouch.Replication.HttpClient).FromUrl("http://admin:secret@localhost:5984/mydb")
    Do $$$AssertTrue($IsObject(tClient), "FromUrl returns an object with credentials")
    Do $$$AssertEquals(tClient.Server, "localhost", "Server parsed with credentials")
    Do $$$AssertEquals(tClient.Port, 5984, "Port parsed with credentials")
    Do $$$AssertEquals(tClient.Username, "admin", "Username extracted from URL")
    Do $$$AssertEquals(tClient.Password, "secret", "Password extracted from URL")
    Do $$$AssertEquals(tClient.BasePath, "/mydb", "BasePath correct with credentials")
}

/// <p>Verify auth override via pAuth object.</p>
Method TestFromUrlWithAuthObject()
{
    Set tAuth = {}
    Do tAuth.%Set("username", "override_user")
    Do tAuth.%Set("password", "override_pass")
    Set tClient = ##class(IRISCouch.Replication.HttpClient).FromUrl("http://admin:secret@localhost:5984/db", tAuth)
    Do $$$AssertTrue($IsObject(tClient), "FromUrl with auth override returns an object")
    Do $$$AssertEquals(tClient.Username, "override_user", "Auth object overrides URL username")
    Do $$$AssertEquals(tClient.Password, "override_pass", "Auth object overrides URL password")
}

/// <p>Verify URL parsing without port (default ports).</p>
Method TestFromUrlDefaultPort()
{
    Set tClient = ##class(IRISCouch.Replication.HttpClient).FromUrl("http://example.com/db")
    Do $$$AssertEquals(tClient.Port, 80, "Default HTTP port is 80")
    Set tClientSSL = ##class(IRISCouch.Replication.HttpClient).FromUrl("https://example.com/db")
    Do $$$AssertEquals(tClientSSL.Port, 443, "Default HTTPS port is 443")
}

/// <p>Verify URL parsing with trailing slash.</p>
Method TestFromUrlTrailingSlash()
{
    Set tClient = ##class(IRISCouch.Replication.HttpClient).FromUrl("http://localhost:5984/mydb/")
    Do $$$AssertEquals(tClient.BasePath, "/mydb", "Trailing slash is removed from BasePath")
}

}
