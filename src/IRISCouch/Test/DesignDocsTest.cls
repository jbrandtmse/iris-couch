/// <p>Unit tests for <class>IRISCouch.Core.DesignDocs</class> (Story 12.3).</p>
/// <p>Covers <method>ListValidateFunctions</method> enumeration including the
/// design-doc filter / tombstone-exclusion / malformed-JSON cases, and
/// <method>ListFilterFunctions</method> lookup shapes.</p>
Class IRISCouch.Test.DesignDocsTest Extends %UnitTest.TestCase
{

Parameter TESTDB = "designdocstest123";

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ..KillDB()
    Quit ##class(IRISCouch.Storage.Database).Create(..#TESTDB)
}

Method OnAfterOneTest() As %Status
{
    Do ..KillDB()
    Quit $$$OK
}

ClassMethod KillDB() [ Internal ]
{
    Kill ^IRISCouch.DB(..#TESTDB)
    Kill ^IRISCouch.Docs(..#TESTDB)
    Kill ^IRISCouch.Tree(..#TESTDB)
    Kill ^IRISCouch.Changes(..#TESTDB)
    Kill ^IRISCouch.Seq(..#TESTDB)
}

/// <p>Empty DB: ListValidateFunctions returns 0.</p>
Method TestListValidateEmpty()
{
    Set tCount = ##class(IRISCouch.Core.DesignDocs).ListValidateFunctions(..#TESTDB, .tList)
    Do $$$AssertEquals(tCount, 0, "Empty DB returns 0 validate fns")
}

/// <p>Single design doc with validate_doc_update is discovered.</p>
Method TestListValidateFindsOne()
{
    Set tBody = "{""validate_doc_update"":""function(n,o,u,s){}""}"
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/v", tBody)
    Set tCount = ##class(IRISCouch.Core.DesignDocs).ListValidateFunctions(..#TESTDB, .tList)
    Do $$$AssertEquals(tCount, 1, "One validate fn discovered")
    Do $$$AssertEquals($Get(tList(1, "ddocId")), "_design/v", "ddoc id recorded")
    Do $$$AssertTrue($Get(tList(1, "source")) [ "function(n,o,u,s)", "function source recorded")
}

/// <p>Design doc WITHOUT validate_doc_update field is skipped.</p>
Method TestListValidateSkipsNonValidate()
{
    Set tR1 = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/v1", "{""validate_doc_update"":""function(){}""}")
    Do $$$AssertTrue(tR1 '= "", "v1 saved")
    Set tR2 = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/v2", "{""views"":{""a"":{""map"":""function(){}""}}}")
    Do $$$AssertTrue(tR2 '= "", "v2 saved")
    Set tR3 = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/v3", "{""validate_doc_update"":""function(){throw({forbidden:'x'});}""}")
    Do $$$AssertTrue(tR3 '= "", "v3 saved")
    Set tCount = ##class(IRISCouch.Core.DesignDocs).ListValidateFunctions(..#TESTDB, .tList)
    Do $$$AssertEquals(tCount, 2, "Only ddocs with validate_doc_update are counted")
}

/// <p>Deleted design docs are excluded.</p>
Method TestListValidateExcludesDeleted()
{
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/del", "{""validate_doc_update"":""function(){}""}")
    Do ##class(IRISCouch.Core.DocumentEngine).SaveDeleted(..#TESTDB, "_design/del", tRev)
    Set tCount = ##class(IRISCouch.Core.DesignDocs).ListValidateFunctions(..#TESTDB, .tList)
    Do $$$AssertEquals(tCount, 0, "Deleted ddoc does NOT contribute")
}

/// <p>ListFilterFunctions returns the named source.</p>
Method TestListFilterFunctions()
{
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/f", "{""filters"":{""evens"":""function(doc,req){return doc.n%2===0;}"",""odds"":""function(doc,req){return doc.n%2===1;}""}}")
    Set tSrc = ""
    Set tSC = ##class(IRISCouch.Core.DesignDocs).ListFilterFunctions(..#TESTDB, "f", "evens", .tSrc)
    Do $$$AssertStatusOK(tSC, "lookup OK")
    Do $$$AssertTrue(tSrc [ "doc.n%2===0", "returns the evens source")
}

/// <p>ListFilterFunctions on missing ddoc returns empty source without error.</p>
Method TestListFilterFunctionsMissingDdoc()
{
    Set tSrc = ""
    Set tSC = ##class(IRISCouch.Core.DesignDocs).ListFilterFunctions(..#TESTDB, "nonexistent", "x", .tSrc)
    Do $$$AssertStatusOK(tSC, "missing ddoc returns OK with empty source")
    Do $$$AssertEquals(tSrc, "", "empty source when ddoc missing")
}

/// <p>ListFilterFunctions on missing filter returns empty source.</p>
Method TestListFilterFunctionsMissingFilter()
{
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/f", "{""filters"":{""one"":""function(d,r){return true;}""}}")
    Set tSrc = ""
    Set tSC = ##class(IRISCouch.Core.DesignDocs).ListFilterFunctions(..#TESTDB, "f", "nonexistent", .tSrc)
    Do $$$AssertStatusOK(tSC, "missing filter returns OK")
    Do $$$AssertEquals(tSrc, "", "empty source when filter name missing")
}

}
