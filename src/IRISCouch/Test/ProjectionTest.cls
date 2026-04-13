/// <p>Unit tests for Projection.Winners, Projection.MangoIndexDef, and Projection.MangoIndex classes.</p>
/// <p>Tests CRUD operations, idempotency, field extraction, and JSON type detection.</p>
Class IRISCouch.Test.ProjectionTest Extends %UnitTest.TestCase
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
    ; Ensure test database exists
    Kill ^IRISCouch.DB("testprojdb")
    Kill ^IRISCouch.Docs("testprojdb")
    Kill ^IRISCouch.Tree("testprojdb")
    Kill ^IRISCouch.Changes("testprojdb")
    Kill ^IRISCouch.Seq("testprojdb")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testprojdb")
    ; Clean up projection data
    Do ##class(IRISCouch.Projection.Winners).DeleteAll("testprojdb")
    Do ##class(IRISCouch.Projection.MangoIndex).DeleteAll("testprojdb")
    Do ##class(IRISCouch.Projection.MangoIndexDef).DeleteAll("testprojdb")
    Quit $$$OK
}

/// <p>Clean up after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(IRISCouch.Projection.Winners).DeleteAll("testprojdb")
    Do ##class(IRISCouch.Projection.MangoIndex).DeleteAll("testprojdb")
    Do ##class(IRISCouch.Projection.MangoIndexDef).DeleteAll("testprojdb")
    Kill ^IRISCouch.DB("testprojdb")
    Kill ^IRISCouch.Docs("testprojdb")
    Kill ^IRISCouch.Tree("testprojdb")
    Kill ^IRISCouch.Changes("testprojdb")
    Kill ^IRISCouch.Seq("testprojdb")
    Quit $$$OK
}

/// <p>Test Winners upsert and get body retrieval.</p>
Method TestWinnersUpsertAndGet()
{
    Set tBody = "{""type"":""order"",""total"":42}"
    Set tSC = ##class(IRISCouch.Projection.Winners).Upsert("testprojdb", "doc1", "1-abc", tBody, 0)
    Do $$$AssertStatusOK(tSC, "Upsert returns OK")
    Set tResult = ##class(IRISCouch.Projection.Winners).GetBody("testprojdb", "doc1")
    Do $$$AssertEquals(tResult, tBody, "GetBody returns correct body")
    ; Update with new rev
    Set tBody2 = "{""type"":""order"",""total"":99}"
    Set tSC = ##class(IRISCouch.Projection.Winners).Upsert("testprojdb", "doc1", "2-def", tBody2, 0)
    Do $$$AssertStatusOK(tSC, "Second upsert returns OK")
    Set tResult2 = ##class(IRISCouch.Projection.Winners).GetBody("testprojdb", "doc1")
    Do $$$AssertEquals(tResult2, tBody2, "GetBody returns updated body")
}

/// <p>Test Winners delete removes row.</p>
Method TestWinnersDelete()
{
    Set tSC = ##class(IRISCouch.Projection.Winners).Upsert("testprojdb", "doc1", "1-abc", "{""x"":1}", 0)
    Do $$$AssertStatusOK(tSC, "Upsert OK")
    Set tSC = ##class(IRISCouch.Projection.Winners).Delete("testprojdb", "doc1")
    Do $$$AssertStatusOK(tSC, "Delete OK")
    Set tResult = ##class(IRISCouch.Projection.Winners).GetBody("testprojdb", "doc1")
    Do $$$AssertEquals(tResult, "", "GetBody returns empty after delete")
}

/// <p>Test Winners DeleteAll removes all rows for a database.</p>
Method TestWinnersDeleteAll()
{
    Do ##class(IRISCouch.Projection.Winners).Upsert("testprojdb", "doc1", "1-a", "{}", 0)
    Do ##class(IRISCouch.Projection.Winners).Upsert("testprojdb", "doc2", "1-b", "{}", 0)
    Set tSC = ##class(IRISCouch.Projection.Winners).DeleteAll("testprojdb")
    Do $$$AssertStatusOK(tSC, "DeleteAll OK")
    Do $$$AssertEquals(##class(IRISCouch.Projection.Winners).GetBody("testprojdb", "doc1"), "", "doc1 gone")
    Do $$$AssertEquals(##class(IRISCouch.Projection.Winners).GetBody("testprojdb", "doc2"), "", "doc2 gone")
}

/// <p>Test MangoIndexDef create and persistence.</p>
Method TestMangoIndexDefCreate()
{
    Set tFields = "[{""type"":""asc""},{""date"":""asc""}]"
    Set tSC = ##class(IRISCouch.Projection.MangoIndexDef).Create("testprojdb", "_design/my-idx", "idx1", "json", tFields, "")
    Do $$$AssertStatusOK(tSC, "Create returns OK")
    Do $$$AssertTrue(##class(IRISCouch.Projection.MangoIndexDef).Exists("testprojdb", "_design/my-idx", "idx1"), "Index exists after create")
}

/// <p>Test MangoIndexDef idempotency via ExistsByDefinition.</p>
Method TestMangoIndexDefIdempotency()
{
    Set tFields = "[{""type"":""asc""},{""date"":""asc""}]"
    Set tSC = ##class(IRISCouch.Projection.MangoIndexDef).Create("testprojdb", "_design/my-idx", "idx1", "json", tFields, "")
    Do $$$AssertStatusOK(tSC, "Create OK")
    Do $$$AssertTrue(##class(IRISCouch.Projection.MangoIndexDef).ExistsByDefinition("testprojdb", tFields, ""), "ExistsByDefinition returns true for identical definition")
}

/// <p>Test MangoIndexDef list returns all indexes.</p>
Method TestMangoIndexDefList()
{
    Set tFields1 = "[{""type"":""asc""}]"
    Set tFields2 = "[{""date"":""asc""}]"
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testprojdb", "_design/idx1", "idx1", "json", tFields1, "")
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testprojdb", "_design/idx2", "idx2", "json", tFields2, "")
    Set tList = ##class(IRISCouch.Projection.MangoIndexDef).List("testprojdb")
    Do $$$AssertEquals(tList.%Size(), 2, "List returns 2 indexes")
}

/// <p>Test MangoIndexDef delete.</p>
Method TestMangoIndexDefDelete()
{
    Set tFields = "[{""type"":""asc""}]"
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testprojdb", "_design/idx1", "idx1", "json", tFields, "")
    Set tSC = ##class(IRISCouch.Projection.MangoIndexDef).Delete("testprojdb", "_design/idx1", "idx1")
    Do $$$AssertStatusOK(tSC, "Delete OK")
    Do $$$AssertTrue('##class(IRISCouch.Projection.MangoIndexDef).Exists("testprojdb", "_design/idx1", "idx1"), "Index gone after delete")
}

/// <p>Test MangoIndexDef auto-generated name is deterministic SHA-1.</p>
Method TestMangoIndexDefAutoName()
{
    Set tFields = "[{""type"":""asc""},{""date"":""asc""}]"
    Set tName1 = ##class(IRISCouch.Projection.MangoIndexDef).GenerateName(tFields, "")
    Set tName2 = ##class(IRISCouch.Projection.MangoIndexDef).GenerateName(tFields, "")
    Do $$$AssertEquals(tName1, tName2, "SHA-1 name is deterministic")
    Do $$$AssertTrue($Length(tName1) > 0, "Generated name is non-empty")
    ; Different fields produce different name
    Set tName3 = ##class(IRISCouch.Projection.MangoIndexDef).GenerateName("[{""x"":""asc""}]", "")
    Do $$$AssertTrue(tName1 '= tName3, "Different fields produce different names")
}

/// <p>Test MangoIndex upsert for a document with field extraction.</p>
Method TestMangoIndexUpsert()
{
    Set tBody = ##class(%DynamicObject).%FromJSON("{""type"":""order"",""date"":""2024-01-15""}")
    Set tIndexDefs = []
    Set tDef = {}
    Do tDef.%Set("ddoc", "_design/idx1")
    Do tDef.%Set("name", "idx1")
    Do tDef.%Set("fields", "[{""type"":""asc""},{""date"":""asc""}]")
    Do tDef.%Set("partialFilter", "")
    Do tIndexDefs.%Push(tDef)
    Set tSC = ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument("testprojdb", "doc1", tBody, tIndexDefs)
    Do $$$AssertStatusOK(tSC, "UpsertForDocument OK")
    ; Verify rows were created via SQL
    &sql(SELECT COUNT(*) INTO :tCount FROM IRISCouch_Projection.MangoIndex WHERE DbName = 'testprojdb' AND DocId = 'doc1')
    Do $$$AssertEquals(tCount, 2, "Two index rows created (type and date)")
}

/// <p>Test MangoIndex delete for document.</p>
Method TestMangoIndexDeleteForDocument()
{
    Set tBody = ##class(%DynamicObject).%FromJSON("{""type"":""order""}")
    Set tIndexDefs = []
    Set tDef = {}
    Do tDef.%Set("ddoc", "_design/idx1")
    Do tDef.%Set("name", "idx1")
    Do tDef.%Set("fields", "[{""type"":""asc""}]")
    Do tDef.%Set("partialFilter", "")
    Do tIndexDefs.%Push(tDef)
    Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument("testprojdb", "doc1", tBody, tIndexDefs)
    Set tSC = ##class(IRISCouch.Projection.MangoIndex).DeleteForDocument("testprojdb", "doc1")
    Do $$$AssertStatusOK(tSC, "DeleteForDocument OK")
    &sql(SELECT COUNT(*) INTO :tCount FROM IRISCouch_Projection.MangoIndex WHERE DbName = 'testprojdb' AND DocId = 'doc1')
    Do $$$AssertEquals(tCount, 0, "No rows remain after DeleteForDocument")
}

/// <p>Test MangoIndex delete for a specific index.</p>
Method TestMangoIndexDeleteForIndex()
{
    Set tBody = ##class(%DynamicObject).%FromJSON("{""type"":""order""}")
    Set tIndexDefs = []
    Set tDef = {}
    Do tDef.%Set("ddoc", "_design/idx1")
    Do tDef.%Set("name", "idx1")
    Do tDef.%Set("fields", "[{""type"":""asc""}]")
    Do tDef.%Set("partialFilter", "")
    Do tIndexDefs.%Push(tDef)
    Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument("testprojdb", "doc1", tBody, tIndexDefs)
    Set tSC = ##class(IRISCouch.Projection.MangoIndex).DeleteForIndex("testprojdb", "_design/idx1", "idx1")
    Do $$$AssertStatusOK(tSC, "DeleteForIndex OK")
    &sql(SELECT COUNT(*) INTO :tCount FROM IRISCouch_Projection.MangoIndex WHERE DbName = 'testprojdb' AND DDoc = '_design/idx1')
    Do $$$AssertEquals(tCount, 0, "No rows remain after DeleteForIndex")
}

/// <p>Test MangoIndex field extraction with dot-notation, nested objects, missing fields.</p>
Method TestMangoIndexFieldExtraction()
{
    Set tBody = ##class(%DynamicObject).%FromJSON("{""name"":""Alice"",""address"":{""city"":""NYC"",""zip"":""10001""},""tags"":[""a"",""b""]}")
    ; Simple field
    Set tVal = ##class(IRISCouch.Projection.MangoIndex).ExtractFieldValue(tBody, "name")
    Do $$$AssertEquals(tVal, "Alice", "Simple field extraction")
    ; Nested dot-notation
    Set tVal = ##class(IRISCouch.Projection.MangoIndex).ExtractFieldValue(tBody, "address.city")
    Do $$$AssertEquals(tVal, "NYC", "Nested field extraction")
    ; Missing field
    Set tVal = ##class(IRISCouch.Projection.MangoIndex).ExtractFieldValue(tBody, "missing")
    Do $$$AssertEquals(tVal, "", "Missing field returns empty string")
    ; Missing nested field
    Set tVal = ##class(IRISCouch.Projection.MangoIndex).ExtractFieldValue(tBody, "address.state")
    Do $$$AssertEquals(tVal, "", "Missing nested field returns empty string")
    ; Array field
    Set tVal = ##class(IRISCouch.Projection.MangoIndex).ExtractFieldValue(tBody, "tags")
    Do $$$AssertTrue($IsObject(tVal), "Array field returns object")
}

/// <p>Test MangoIndex JSON type detection with type hints from %GetTypeOf().</p>
Method TestMangoIndexJsonTypeDetection()
{
    ; With type hints (primary path used during field extraction)
    Do $$$AssertEquals(##class(IRISCouch.Projection.MangoIndex).GetJsonType("hello", "string"), "string", "String type with hint")
    Do $$$AssertEquals(##class(IRISCouch.Projection.MangoIndex).GetJsonType(42, "number"), "number", "Number type with hint")
    Do $$$AssertEquals(##class(IRISCouch.Projection.MangoIndex).GetJsonType(1, "boolean"), "boolean", "Boolean true with hint")
    Do $$$AssertEquals(##class(IRISCouch.Projection.MangoIndex).GetJsonType(0, "boolean"), "boolean", "Boolean false with hint")
    Do $$$AssertEquals(##class(IRISCouch.Projection.MangoIndex).GetJsonType("", "null"), "null", "Null with hint")
    Set tArr = []
    Do $$$AssertEquals(##class(IRISCouch.Projection.MangoIndex).GetJsonType(tArr, "array"), "array", "Array type with hint")
    Set tObj = {}
    Do $$$AssertEquals(##class(IRISCouch.Projection.MangoIndex).GetJsonType(tObj, "object"), "object", "Object type with hint")
    ; Fallback without hints
    Do $$$AssertEquals(##class(IRISCouch.Projection.MangoIndex).GetJsonType("hello"), "string", "String type without hint")
    Do $$$AssertEquals(##class(IRISCouch.Projection.MangoIndex).GetJsonType(42), "number", "Number type without hint")
    Do $$$AssertEquals(##class(IRISCouch.Projection.MangoIndex).GetJsonType(""), "null", "Empty string as null without hint")
}

/// <p>Test MangoIndex with complex partial filter selector using $in operator.</p>
/// <p>Verifies that documents not matching the partial filter are excluded from indexing.</p>
Method TestPartialFilterComplexSelector()
{
    ; Create index with complex partial_filter_selector: {"status":{"$in":["active","pending"]}}
    Set tFields = "[{""type"":""asc""}]"
    Set tPartialFilter = "{""status"":{""$in"":[""active"",""pending""]}}"
    Set tSC = ##class(IRISCouch.Projection.MangoIndexDef).Create("testprojdb", "_design/pf-idx", "pfidx1", "json", tFields, tPartialFilter)
    Do $$$AssertStatusOK(tSC, "Create index with partial filter OK")
    ; Build index defs array matching what UpsertForDocument expects
    Set tIndexDefs = []
    Set tDef = {}
    Do tDef.%Set("ddoc", "_design/pf-idx")
    Do tDef.%Set("name", "pfidx1")
    Do tDef.%Set("fields", tFields)
    Do tDef.%Set("partialFilter", tPartialFilter)
    Do tIndexDefs.%Push(tDef)
    ; Document 1: status=active — should be indexed
    Set tBodyActive = ##class(%DynamicObject).%FromJSON("{""type"":""order"",""status"":""active""}")
    Set tSC = ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument("testprojdb", "doc-active", tBodyActive, tIndexDefs)
    Do $$$AssertStatusOK(tSC, "UpsertForDocument active OK")
    ; Document 2: status=archived — should NOT be indexed
    Set tBodyArchived = ##class(%DynamicObject).%FromJSON("{""type"":""order"",""status"":""archived""}")
    Set tSC = ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument("testprojdb", "doc-archived", tBodyArchived, tIndexDefs)
    Do $$$AssertStatusOK(tSC, "UpsertForDocument archived OK")
    ; Verify: doc-active should have index rows
    &sql(SELECT COUNT(*) INTO :tActiveCount FROM IRISCouch_Projection.MangoIndex WHERE %EXACT(DbName) = 'testprojdb' AND %EXACT(DocId) = 'doc-active' AND %EXACT(IndexName) = 'pfidx1')
    Do $$$AssertTrue(tActiveCount > 0, "Active document is indexed")
    ; Verify: doc-archived should NOT have index rows
    &sql(SELECT COUNT(*) INTO :tArchivedCount FROM IRISCouch_Projection.MangoIndex WHERE %EXACT(DbName) = 'testprojdb' AND %EXACT(DocId) = 'doc-archived' AND %EXACT(IndexName) = 'pfidx1')
    Do $$$AssertEquals(tArchivedCount, 0, "Archived document is NOT indexed (filtered by partial filter)")
}

}
