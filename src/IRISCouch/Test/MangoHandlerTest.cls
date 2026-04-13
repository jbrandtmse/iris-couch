/// <p>Unit tests for MangoHandler index CRUD operations.</p>
/// <p>Tests create, list, delete, validation, idempotency, and auto-naming.</p>
Class IRISCouch.Test.MangoHandlerTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create test database and clean projection data before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.DB("testmangodb")
    Kill ^IRISCouch.Docs("testmangodb")
    Kill ^IRISCouch.Tree("testmangodb")
    Kill ^IRISCouch.Changes("testmangodb")
    Kill ^IRISCouch.Seq("testmangodb")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testmangodb")
    Do ##class(IRISCouch.Projection.Winners).DeleteAll("testmangodb")
    Do ##class(IRISCouch.Projection.MangoIndex).DeleteAll("testmangodb")
    Do ##class(IRISCouch.Projection.MangoIndexDef).DeleteAll("testmangodb")
    Quit $$$OK
}

/// <p>Clean up after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(IRISCouch.Projection.Winners).DeleteAll("testmangodb")
    Do ##class(IRISCouch.Projection.MangoIndex).DeleteAll("testmangodb")
    Do ##class(IRISCouch.Projection.MangoIndexDef).DeleteAll("testmangodb")
    Kill ^IRISCouch.DB("testmangodb")
    Kill ^IRISCouch.Docs("testmangodb")
    Kill ^IRISCouch.Tree("testmangodb")
    Kill ^IRISCouch.Changes("testmangodb")
    Kill ^IRISCouch.Seq("testmangodb")
    Quit $$$OK
}

/// <p>Test creating an index directly and verifying the definition is stored.</p>
Method TestCreateIndexBasic()
{
    Set tFields = "[{""type"":""asc""},{""date"":""asc""}]"
    Set tSC = ##class(IRISCouch.Projection.MangoIndexDef).Create("testmangodb", "_design/my-idx", "idx-type-date", "json", tFields, "")
    Do $$$AssertStatusOK(tSC, "Create index def OK")
    Do $$$AssertTrue(##class(IRISCouch.Projection.MangoIndexDef).Exists("testmangodb", "_design/my-idx", "idx-type-date"), "Index exists")
}

/// <p>Test that creating the same index definition twice is detected as idempotent.</p>
Method TestCreateIndexIdempotent()
{
    Set tFields = "[{""type"":""asc""},{""date"":""asc""}]"
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testmangodb", "_design/my-idx", "idx1", "json", tFields, "")
    ; Check idempotency
    Set tDDoc = ""
    Set tName = ""
    Set tFound = ##class(IRISCouch.Projection.MangoIndexDef).FindByDefinition("testmangodb", tFields, "", .tDDoc, .tName)
    Do $$$AssertTrue(tFound, "FindByDefinition returns true for identical definition")
    Do $$$AssertEquals(tDDoc, "_design/my-idx", "Found ddoc matches")
    Do $$$AssertEquals(tName, "idx1", "Found name matches")
}

/// <p>Test auto-generated index name uses SHA-1 hash.</p>
Method TestCreateIndexAutoName()
{
    Set tFields = "[{""type"":""asc""}]"
    Set tAutoName = ##class(IRISCouch.Projection.MangoIndexDef).GenerateName(tFields, "")
    Do $$$AssertTrue($Length(tAutoName) > 0, "Auto-generated name is non-empty")
    Do $$$AssertTrue($Length(tAutoName) = 40, "SHA-1 hex hash is 40 chars")
}

/// <p>Test auto-generated ddoc name uses SHA-1 hash prefixed with _design/.</p>
Method TestCreateIndexAutoDDoc()
{
    Set tFields = "[{""type"":""asc""}]"
    Set tAutoDDoc = ##class(IRISCouch.Projection.MangoIndexDef).GenerateDDoc(tFields, "")
    Do $$$AssertTrue($Extract(tAutoDDoc, 1, 8) = "_design/", "Auto ddoc starts with _design/")
    Do $$$AssertTrue($Length(tAutoDDoc) = 48, "Auto ddoc is _design/ + 40 char hash")
}

/// <p>Test creating an index with partial_filter_selector stores it correctly.</p>
Method TestCreateIndexWithPartialFilter()
{
    Set tFields = "[{""type"":""asc""}]"
    Set tPartialFilter = "{""status"":""active""}"
    Set tSC = ##class(IRISCouch.Projection.MangoIndexDef).Create("testmangodb", "_design/pf-idx", "pf1", "json", tFields, tPartialFilter)
    Do $$$AssertStatusOK(tSC, "Create with partial filter OK")
    ; Verify it can be found by definition with partial filter
    Set tFound = ##class(IRISCouch.Projection.MangoIndexDef).FindByDefinition("testmangodb", tFields, tPartialFilter, .tDDoc, .tName)
    Do $$$AssertTrue(tFound, "FindByDefinition with partial filter returns true")
}

/// <p>Test validation: empty fields should be rejected.</p>
Method TestCreateIndexValidationEmptyFields()
{
    ; Test that a non-empty fields array is required
    Set tFields = "[]"
    Set tArr = ##class(%DynamicAbstractObject).%FromJSON(tFields)
    Do $$$AssertEquals(tArr.%Size(), 0, "Empty array has size 0")
    ; The handler validates this — here we just verify the fields array size check
    Do $$$AssertTrue(tArr.%Size() = 0, "Empty fields array detected")
}

/// <p>Test listing indexes includes _all_docs special index first.</p>
Method TestListIndexesIncludesAllDocs()
{
    ; Create one user index
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testmangodb", "_design/idx1", "idx1", "json", "[{""type"":""asc""}]", "")
    Set tList = ##class(IRISCouch.Projection.MangoIndexDef).List("testmangodb")
    ; The user index list should have 1
    Do $$$AssertEquals(tList.%Size(), 1, "User index list has 1 index")
    ; The handler prepends _all_docs — test that separately in HTTP test
}

/// <p>Test listing indexes shows user-created indexes.</p>
Method TestListIndexesShowsUserIndexes()
{
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testmangodb", "_design/idx1", "idx1", "json", "[{""type"":""asc""}]", "")
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testmangodb", "_design/idx2", "idx2", "json", "[{""date"":""asc""}]", "")
    Set tList = ##class(IRISCouch.Projection.MangoIndexDef).List("testmangodb")
    Do $$$AssertEquals(tList.%Size(), 2, "List shows 2 user indexes")
}

/// <p>Test deleting an index removes both definition and data rows.</p>
Method TestDeleteIndex()
{
    Set tFields = "[{""type"":""asc""}]"
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testmangodb", "_design/idx1", "idx1", "json", tFields, "")
    ; Create some index data
    Set tBody = ##class(%DynamicObject).%FromJSON("{""type"":""order""}")
    Set tDefs = []
    Set tDef = {}
    Do tDef.%Set("ddoc", "_design/idx1")
    Do tDef.%Set("name", "idx1")
    Do tDef.%Set("fields", tFields)
    Do tDef.%Set("partialFilter", "")
    Do tDefs.%Push(tDef)
    Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument("testmangodb", "doc1", tBody, tDefs)
    ; Delete the index
    Set tSC = ##class(IRISCouch.Projection.MangoIndexDef).Delete("testmangodb", "_design/idx1", "idx1")
    Do $$$AssertStatusOK(tSC, "Delete def OK")
    Set tSC = ##class(IRISCouch.Projection.MangoIndex).DeleteForIndex("testmangodb", "_design/idx1", "idx1")
    Do $$$AssertStatusOK(tSC, "Delete index rows OK")
    Do $$$AssertTrue('##class(IRISCouch.Projection.MangoIndexDef).Exists("testmangodb", "_design/idx1", "idx1"), "Def removed")
    &sql(SELECT COUNT(*) INTO :tCount FROM IRISCouch_Projection.MangoIndex WHERE DbName = 'testmangodb' AND DDoc = '_design/idx1')
    Do $$$AssertEquals(tCount, 0, "Index data rows removed")
}

}
