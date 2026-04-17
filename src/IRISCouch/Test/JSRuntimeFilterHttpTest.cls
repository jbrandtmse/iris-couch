/// <p>HTTP integration tests for custom changes-feed filters under the
/// Subprocess JSRuntime backend (Story 12.3).</p>
/// <p>Every test creates a fresh <code>testflthttp123</code> database, sets
/// <code>JSRUNTIME=Subprocess</code>, seeds a handful of documents and a
/// filter-defining design doc, and issues <code>_changes</code> requests with
/// <code>filter=ddoc/name</code>. Tests skip gracefully if no launchable
/// interpreter is available.</p>
Class IRISCouch.Test.JSRuntimeFilterHttpTest Extends %UnitTest.TestCase
{

Parameter TESTDB = "testflthttp123";

Parameter NODEPATH = "C:\Program Files\nodejs\node.exe";

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ..KillDB()
    Set tSC = ##class(IRISCouch.Storage.Database).Create(..#TESTDB)
    If $$$ISERR(tSC) Quit tSC
    Set ^IRISCouch.Config("JSRUNTIME") = "Subprocess"
    Set ^IRISCouch.Config("JSRUNTIMESUBPROCESSPATH") = ..#NODEPATH
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..KillDB()
    Kill ^IRISCouch.Config("JSRUNTIME")
    Kill ^IRISCouch.Config("JSRUNTIMESUBPROCESSPATH")
    Kill ^IRISCouch.Config("JSRUNTIMESUBPROCESSENTRY")
    Quit $$$OK
}

ClassMethod KillDB() [ Internal ]
{
    Kill ^IRISCouch.DB(..#TESTDB)
    Kill ^IRISCouch.Docs(..#TESTDB)
    Kill ^IRISCouch.Tree(..#TESTDB)
    Kill ^IRISCouch.Changes(..#TESTDB)
    Kill ^IRISCouch.Seq(..#TESTDB)
    Kill ^IRISCouch.Security(..#TESTDB)
}

ClassMethod CanLaunchSubprocess() As %Boolean [ Internal ]
{
    Set tSandbox = ##class(IRISCouch.JSRuntime.Subprocess).%New()
    Quit tSandbox.IsAvailable()
}

/// Seed three docs — two "public", one "private".
Method SeedPublicPrivateDocs() [ Internal ]
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/pub1", .tStatus, .tBody, "{""public"":true}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/priv1", .tStatus, .tBody, "{""public"":false}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/pub2", .tStatus, .tBody, "{""public"":true}")
}

/// AC #3: custom filter returns only the docs the function approved.
Method TestCustomFilterIncludesMatches()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter")
        Quit
    }
    Set tDDoc = "{""filters"":{""publics"":""function(doc,req){return doc.public===true;}""}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/f", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT filter ddoc")
    Do ..SeedPublicPrivateDocs()
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_changes?filter=f/publics", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "changes returns 200")
    Set tResults = tBody.results
    Do $$$AssertEquals(tResults.%Size(), 2, "Only 2 public docs (pub1 + pub2) pass filter")
    ; IDs should be pub1 and pub2 (deterministic insertion order)
    Set tHitPub1 = 0
    Set tHitPub2 = 0
    Set tI = 0
    While tI < tResults.%Size() {
        Set tEntry = tResults.%Get(tI)
        Set tI = tI + 1
        If tEntry.id = "pub1" Set tHitPub1 = 1
        If tEntry.id = "pub2" Set tHitPub2 = 1
    }
    Do $$$AssertTrue(tHitPub1, "pub1 included")
    Do $$$AssertTrue(tHitPub2, "pub2 included")
}

/// AC #3: always-false filter returns zero results, last_seq still correct.
Method TestCustomFilterExcludesAll()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter")
        Quit
    }
    Set tDDoc = "{""filters"":{""none"":""function(doc,req){return false;}""}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/f", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT filter ddoc")
    Do ..SeedPublicPrivateDocs()
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_changes?filter=f/none", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "changes 200")
    Do $$$AssertEquals(tBody.results.%Size(), 0, "Empty results from always-false filter")
    Do $$$AssertTrue((+tBody."last_seq") > 0, "last_seq still reflects processed docs")
}

/// AC #3: filter=ddoc/missing → HTTP 404.
Method TestCustomFilterMissingDocReturns404()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter")
        Quit
    }
    ; No filter ddoc exists. Request should 404.
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_changes?filter=nope/missing", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 404, "Unknown filter ddoc/name → 404")
    Do $$$AssertEquals(tBody.error, "not_found", "error = not_found")
}

/// AC #3 regression: the built-in filters keep working under Subprocess.
Method TestBuiltinFiltersRegressGreen()
{
    ; This test runs even without Node because built-in filters never touch
    ; the JSRuntime. Skip check is defensive — filter branch must still be
    ; safe to exercise under Subprocess config.
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/a", .tStatus, .tBody, "{""k"":1}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/b", .tStatus, .tBody, "{""k"":2}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/ignored", .tStatus, .tBody, "{""extra"":true}")
    ; _doc_ids filter
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_changes?filter=_doc_ids&doc_ids=" _ $ZConvert("[""a""]", "O", "URL"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "_doc_ids returns 200 under Subprocess")
    Do $$$AssertEquals(tBody.results.%Size(), 1, "_doc_ids returns only the listed id")
    ; _design filter
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_changes?filter=_design", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "_design 200")
    Do $$$AssertEquals(tBody.results.%Size(), 1, "_design returns only the ddoc")
}

}
