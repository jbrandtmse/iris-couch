/// <p>Unit tests for <class>IRISCouch.Storage.ViewIndex</class> and
/// <class>IRISCouch.Core.ViewIndexUpdater</class> (Story 12.5).</p>
/// <p>Exercises the storage layer directly -- no HTTP, no sandbox -- so
/// these tests run in any environment (no Node required). The HTTP-level
/// and runaway-timeout tests live in
/// <class>IRISCouch.Test.ViewIndexHttpTest</class>.</p>
Class IRISCouch.Test.ViewIndexTest Extends %UnitTest.TestCase
{

Parameter TESTDB = "viewidxunit";

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
    Kill ^IRISCouch.ViewIndex(..#TESTDB)
    Kill ^IRISCouch.ViewIndexById(..#TESTDB)
    Kill ^IRISCouch.ViewIndexMeta(..#TESTDB)
    Kill ^IRISCouch.ViewIndexCounter(..#TESTDB)
}

/// <p>AddEntry + QueryRange roundtrip: scalar string key.</p>
Method TestAddEntryStringKey()
{
    Set tSC = ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/x", "v1", "apple", "doc1", 1)
    Do $$$AssertStatusOK(tSC, "AddEntry returns OK")
    Set tSC = ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/x", "v1", "banana", "doc2", 2)
    Do $$$AssertStatusOK(tSC, "AddEntry second row OK")
    Set tSC = ##class(IRISCouch.Storage.ViewIndex).QueryRange(..#TESTDB, "_design/x", "v1", .tRows)
    Do $$$AssertStatusOK(tSC, "QueryRange OK")
    Do $$$AssertEquals(tRows.%Size(), 2, "Two rows returned")
    Do $$$AssertEquals(tRows.%Get(0).%Get("id"), "doc1", "apple < banana: doc1 first")
    Do $$$AssertEquals(tRows.%Get(1).%Get("id"), "doc2", "banana second")
}

/// <p>RemoveEntriesForDoc purges forward and reverse entries.</p>
Method TestRemoveEntriesForDoc()
{
    Do ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/x", "v1", "apple", "doc1", 1)
    Do ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/x", "v1", "banana", "doc2", 2)
    Set tSC = ##class(IRISCouch.Storage.ViewIndex).RemoveEntriesForDoc(..#TESTDB, "_design/x", "v1", "doc1")
    Do $$$AssertStatusOK(tSC, "Remove OK")
    Set tSC = ##class(IRISCouch.Storage.ViewIndex).QueryRange(..#TESTDB, "_design/x", "v1", .tRows)
    Do $$$AssertEquals(tRows.%Size(), 1, "Only doc2 row remains")
    Do $$$AssertEquals(tRows.%Get(0).%Get("id"), "doc2", "doc1 removed")
    ; Reverse map should be clean for doc1
    Do $$$AssertTrue('$Data(^IRISCouch.ViewIndexById(..#TESTDB, "_design/x", "v1", "doc1")), "reverse map cleared")
}

/// <p>Multi-emit (one doc emits same view multiple times) is preserved.</p>
Method TestMultiEmit()
{
    Do ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/x", "v1", "k", "docA", "v1val")
    Do ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/x", "v1", "k", "docA", "v2val")
    Set tSC = ##class(IRISCouch.Storage.ViewIndex).QueryRange(..#TESTDB, "_design/x", "v1", .tRows)
    Do $$$AssertEquals(tRows.%Size(), 2, "Both emissions preserved")
}

/// <p>Numeric keys collate numerically, not lexicographically.</p>
Method TestNumericKeyCollation()
{
    Do ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/x", "v1", 2, "doc2", 0)
    Do ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/x", "v1", 10, "doc10", 0)
    Do ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/x", "v1", 1, "doc1", 0)
    Set tSC = ##class(IRISCouch.Storage.ViewIndex).QueryRange(..#TESTDB, "_design/x", "v1", .tRows)
    Do $$$AssertEquals(tRows.%Size(), 3, "Three rows")
    Do $$$AssertEquals(tRows.%Get(0).%Get("id"), "doc1", "1 first")
    Do $$$AssertEquals(tRows.%Get(1).%Get("id"), "doc2", "2 second (not lexical)")
    Do $$$AssertEquals(tRows.%Get(2).%Get("id"), "doc10", "10 third")
}

/// <p>SetMeta / GetLastUpdatedSeq / GetViewDefinitionHash roundtrip.</p>
Method TestMetaRoundtrip()
{
    Do $$$AssertEquals(##class(IRISCouch.Storage.ViewIndex).GetLastUpdatedSeq(..#TESTDB, "_design/x", "v1"), 0, "default seq is 0")
    Do $$$AssertEquals(##class(IRISCouch.Storage.ViewIndex).GetViewDefinitionHash(..#TESTDB, "_design/x", "v1"), "", "default hash is empty")
    Do ##class(IRISCouch.Storage.ViewIndex).SetMeta(..#TESTDB, "_design/x", "v1", 42, "abc123")
    Do $$$AssertEquals(##class(IRISCouch.Storage.ViewIndex).GetLastUpdatedSeq(..#TESTDB, "_design/x", "v1"), 42, "seq roundtrip")
    Do $$$AssertEquals(##class(IRISCouch.Storage.ViewIndex).GetViewDefinitionHash(..#TESTDB, "_design/x", "v1"), "abc123", "hash roundtrip")
}

/// <p>ViewDefinitionHash is deterministic and responds to reduce source.</p>
Method TestViewDefinitionHashDeterministic()
{
    Set tH1 = ##class(IRISCouch.Storage.ViewIndex).ViewDefinitionHash("function(d){emit(d._id,1);}", "")
    Set tH2 = ##class(IRISCouch.Storage.ViewIndex).ViewDefinitionHash("function(d){emit(d._id,1);}", "")
    Do $$$AssertEquals(tH1, tH2, "deterministic")
    Set tH3 = ##class(IRISCouch.Storage.ViewIndex).ViewDefinitionHash("function(d){emit(d._id,1);}", "_sum")
    Do $$$AssertNotEquals(tH1, tH3, "reduce changes hash")
    Do $$$AssertEquals($Length(tH1), 40, "SHA-1 hex is 40 chars")
}

/// <p>DropForDesignDoc clears every entry under the ddoc.</p>
Method TestDropForDesignDoc()
{
    Do ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/x", "v1", "k", "docA", 1)
    Do ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/x", "v2", "k", "docA", 1)
    Do ##class(IRISCouch.Storage.ViewIndex).AddEntry(..#TESTDB, "_design/y", "v1", "k", "docA", 1)
    Set tSC = ##class(IRISCouch.Storage.ViewIndex).DropForDesignDoc(..#TESTDB, "_design/x")
    Do $$$AssertStatusOK(tSC, "Drop OK")
    Do ##class(IRISCouch.Storage.ViewIndex).QueryRange(..#TESTDB, "_design/x", "v1", .tRowsX1)
    Do ##class(IRISCouch.Storage.ViewIndex).QueryRange(..#TESTDB, "_design/y", "v1", .tRowsY1)
    Do $$$AssertEquals(tRowsX1.%Size(), 0, "x views cleared")
    Do $$$AssertEquals(tRowsY1.%Size(), 1, "y views preserved")
}

/// <p>ListDesignDocIds returns only live design docs, ordered.</p>
Method TestListDesignDocIds()
{
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "regular-doc", "{}")
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/a", "{""views"":{}}")
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/b", "{""views"":{}}")
    Set tIds = ##class(IRISCouch.Core.ViewIndexUpdater).ListDesignDocIds(..#TESTDB)
    Do $$$AssertEquals(tIds.%Size(), 2, "Two design docs")
}

}
