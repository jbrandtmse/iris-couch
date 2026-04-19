/// <p>HTTP integration tests for trailing-slash URL normalization (Story 13.4 Task 1).</p>
/// <p>Covers AC #1: <code>IRISCouch.API.Router.OnPreDispatch</code> must strip
/// a single trailing slash from non-root request URLs so PouchDB default
/// constructors (which emit <code>PUT /{db}/</code>) and copy-paste adopters
/// both route correctly. Every trailing-slash path must behave identically
/// to its no-slash counterpart; the root path <code>/</code> must NOT be
/// normalized (that would make it empty and drop the welcome route).</p>
Class IRISCouch.Test.TrailingSlashRoutingTest Extends %UnitTest.TestCase
{

/// <p>Per-story-convention TESTDB base name.</p>
Parameter TESTDB = "tsrouting";

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up test database state before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Do ..DeleteIfExists(..#TESTDB)
    Quit $$$OK
}

/// <p>Clean up test database state after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ..DeleteIfExists(..#TESTDB)
    Quit $$$OK
}

/// <p>Helper to DELETE the test DB via HTTP if it exists. Swallows 404.</p>
ClassMethod DeleteIfExists(pDB As %String) [ Internal ]
{
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/" _ pDB, .tStatus, .tBody)
    Quit
}

/// <p>PUT /{db} then PUT /{db}/ — second call returns 412 file_exists (NOT 404).</p>
/// <p>AC #1 core assertion: the trailing-slash form must reach the same
/// handler as the no-slash form. We accept 412 as the "reached handler" signal
/// because it means <code>HandleDatabaseCreate</code> ran and rejected the
/// duplicate PUT — whereas 404 would mean the router did not match at all.</p>
Method TestDatabaseEndpointsTrailingSlashOK()
{
    ; First create: /{db} no slash, expect 201
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB, .tS1, .tB1)
    Do $$$AssertStatusOK(tSC, "PUT /{db} request completed")
    Do $$$AssertEquals(tS1, 201, "PUT /{db} returns 201")
    ; Second create: /{db}/ trailing slash, expect 412 (file_exists) — NOT 404
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/", .tS2, .tB2)
    Do $$$AssertStatusOK(tSC, "PUT /{db}/ request completed")
    Do $$$AssertEquals(tS2, 412, "PUT /{db}/ reaches handler (412 file_exists), NOT 404")
}

/// <p>GET /{db}/ returns 200 with the same body shape as GET /{db}.</p>
Method TestDatabaseGetTrailingSlash()
{
    ; Create DB first
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB, .tS0, .tB0)
    ; GET /{db}
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB, .tS1, .tB1)
    Do $$$AssertEquals(tS1, 200, "GET /{db} returns 200")
    ; GET /{db}/
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/", .tS2, .tB2)
    Do $$$AssertEquals(tS2, 200, "GET /{db}/ returns 200")
    Do $$$AssertTrue($IsObject(tB2), "GET /{db}/ returns a JSON object")
    Do $$$AssertEquals(tB1."db_name", tB2."db_name", "GET /{db}/ body db_name matches GET /{db}")
}

/// <p>PUT /{db}/{docid}/ deeper trailing slash still reaches document handler.</p>
Method TestDocumentEndpointsTrailingSlash()
{
    ; Create DB first
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB, .tS0, .tB0)
    ; PUT /{db}/doc1/  — trailing slash
    Set tReqBody = "{""x"":1}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc1/", .tS1, .tB1, tReqBody)
    Do $$$AssertEquals(tS1, 201, "PUT /{db}/{docid}/ returns 201")
    Do $$$AssertTrue($IsObject(tB1), "Response body is a JSON object")
    Do $$$AssertTrue(tB1.ok, "Response ok:true")
    Do $$$AssertEquals(tB1.id, "doc1", "Response id matches path")
    ; GET /{db}/{docid}/
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/doc1/", .tS2, .tB2)
    Do $$$AssertEquals(tS2, 200, "GET /{db}/{docid}/ returns 200")
    Do $$$AssertTrue($IsObject(tB2), "GET doc body is object")
    Do $$$AssertEquals(tB2."_id", "doc1", "GET doc _id matches path")
}

/// <p>System endpoints under /{db}/_all_docs/ and /{db}/_design/{ddoc}/ still route.</p>
Method TestSystemEndpointsTrailingSlash()
{
    ; Create DB first
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB, .tS0, .tB0)
    ; GET /{db}/_all_docs/
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_all_docs/", .tS1, .tB1)
    Do $$$AssertEquals(tS1, 200, "GET /{db}/_all_docs/ returns 200")
    ; Create a design doc so the /_design/{ddoc}/ GET returns 200 (not 404)
    Set tDdocBody = "{""views"":{}}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/foo", .tS2, .tB2, tDdocBody)
    ; GET /{db}/_design/foo/
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/foo/", .tS3, .tB3)
    Do $$$AssertEquals(tS3, 200, "GET /{db}/_design/{ddoc}/ returns 200")
}

/// <p>The bare root path <code>/</code> must NOT be trailing-slash-normalized.</p>
/// <p>If OnPreDispatch stripped the root slash it would rewrite "/" to ""
/// and the welcome route would no longer match. This test ensures the
/// root-path exemption works.</p>
Method TestRootPathNotNormalized()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/", .tS1, .tB1)
    Do $$$AssertEquals(tS1, 200, "GET / returns 200 (root welcome)")
    Do $$$AssertTrue($IsObject(tB1), "Root returns a JSON object")
    Do $$$AssertEquals(tB1.couchdb, "Welcome", "Root body contains couchdb: Welcome")
}

}
