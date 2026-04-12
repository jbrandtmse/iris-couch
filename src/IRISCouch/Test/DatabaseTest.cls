/// <p>Unit tests for IRISCouch database lifecycle operations.</p>
/// <p>Tests <class>IRISCouch.Storage.Database</class> create, delete, exists,
/// and name validation methods. Covers AC #1, #2, #3, #4, #5.</p>
Class IRISCouch.Test.DatabaseTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up test database globals before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.DB("testdb")
    Kill ^IRISCouch.Docs("testdb")
    Kill ^IRISCouch.Tree("testdb")
    Kill ^IRISCouch.Changes("testdb")
    Kill ^IRISCouch.Seq("testdb")
    Kill ^IRISCouch.DB("aaa")
    Kill ^IRISCouch.Seq("aaa")
    Kill ^IRISCouch.DB("bbb")
    Kill ^IRISCouch.Seq("bbb")
    Kill ^IRISCouch.DB("ccc")
    Kill ^IRISCouch.Seq("ccc")
    Quit $$$OK
}

/// <p>Clean up test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testdb")
    Kill ^IRISCouch.Docs("testdb")
    Kill ^IRISCouch.Tree("testdb")
    Kill ^IRISCouch.Changes("testdb")
    Kill ^IRISCouch.Seq("testdb")
    Kill ^IRISCouch.DB("aaa")
    Kill ^IRISCouch.Seq("aaa")
    Kill ^IRISCouch.DB("bbb")
    Kill ^IRISCouch.Seq("bbb")
    Kill ^IRISCouch.DB("ccc")
    Kill ^IRISCouch.Seq("ccc")
    Quit $$$OK
}

/// <p>AC #1: Create a database and verify metadata globals are initialized.</p>
Method TestCreateDatabase()
{
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testdb")
    Do $$$AssertStatusOK(tSC, "Create returns OK status")
    Do $$$AssertTrue(##class(IRISCouch.Storage.Database).Exists("testdb"), "Database exists after creation")
    ; Verify metadata subscripts
    Do $$$AssertTrue($Data(^IRISCouch.DB("testdb", "created"))>0, "Created timestamp is set")
    Do $$$AssertEquals($Get(^IRISCouch.DB("testdb", "doc_count")), 0, "doc_count initialized to 0")
    Do $$$AssertEquals($Get(^IRISCouch.DB("testdb", "update_seq")), 0, "update_seq initialized to 0")
    Do $$$AssertEquals($Get(^IRISCouch.DB("testdb", "disk_size")), 0, "disk_size initialized to 0")
    Do $$$AssertEquals($Get(^IRISCouch.DB("testdb", "purge_seq")), 0, "purge_seq initialized to 0")
    Do $$$AssertEquals($Get(^IRISCouch.DB("testdb", "revs_limit")), 1000, "revs_limit initialized to 1000")
    ; Verify sequence counter
    Do $$$AssertEquals($Get(^IRISCouch.Seq("testdb")), 0, "Sequence counter initialized to 0")
}

/// <p>AC #2: Creating an already-existing database returns error status.</p>
Method TestCreateDatabaseAlreadyExists()
{
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testdb")
    Do $$$AssertStatusOK(tSC, "First create succeeds")
    ; Second create should fail
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testdb")
    Do $$$AssertStatusNotOK(tSC, "Second create returns error status")
}

/// <p>AC #3: Delete a database and verify all globals are removed.</p>
Method TestDeleteDatabase()
{
    ; Create first
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testdb")
    Do $$$AssertStatusOK(tSC, "Create succeeds before delete test")
    ; Simulate some data in associated globals
    Set ^IRISCouch.Docs("testdb", "doc1") = "test"
    Set ^IRISCouch.Tree("testdb", "doc1") = "rev"
    Set ^IRISCouch.Changes("testdb", 1) = "change"
    ; Delete
    Set tSC = ##class(IRISCouch.Storage.Database).Delete("testdb")
    Do $$$AssertStatusOK(tSC, "Delete returns OK status")
    Do $$$AssertTrue('##class(IRISCouch.Storage.Database).Exists("testdb"), "Database does not exist after deletion")
    ; Verify all associated globals are gone
    Do $$$AssertEquals($Data(^IRISCouch.DB("testdb")), 0, "DB global is killed")
    Do $$$AssertEquals($Data(^IRISCouch.Docs("testdb")), 0, "Docs global is killed")
    Do $$$AssertEquals($Data(^IRISCouch.Tree("testdb")), 0, "Tree global is killed")
    Do $$$AssertEquals($Data(^IRISCouch.Changes("testdb")), 0, "Changes global is killed")
    Do $$$AssertEquals($Data(^IRISCouch.Seq("testdb")), 0, "Seq global is killed")
}

/// <p>AC #4: Deleting a non-existent database returns error status.</p>
Method TestDeleteDatabaseNotFound()
{
    Set tSC = ##class(IRISCouch.Storage.Database).Delete("testdb")
    Do $$$AssertStatusNotOK(tSC, "Delete non-existent database returns error status")
}

/// <p>AC #5: Valid database names pass validation.</p>
Method TestValidateNameValid()
{
    ; Lowercase letters
    Do $$$AssertStatusOK(##class(IRISCouch.Storage.Database).ValidateName("mydb"), "Lowercase letters valid")
    ; With digits
    Do $$$AssertStatusOK(##class(IRISCouch.Storage.Database).ValidateName("mydb123"), "With digits valid")
    ; With hyphens
    Do $$$AssertStatusOK(##class(IRISCouch.Storage.Database).ValidateName("my-db"), "With hyphens valid")
    ; With underscores
    Do $$$AssertStatusOK(##class(IRISCouch.Storage.Database).ValidateName("my_db"), "With underscores valid")
    ; System database (leading underscore)
    Do $$$AssertStatusOK(##class(IRISCouch.Storage.Database).ValidateName("_replicator"), "System db _replicator valid")
    Do $$$AssertStatusOK(##class(IRISCouch.Storage.Database).ValidateName("_users"), "System db _users valid")
    ; With allowed special chars
    Do $$$AssertStatusOK(##class(IRISCouch.Storage.Database).ValidateName("my+db"), "With plus valid")
    Do $$$AssertStatusOK(##class(IRISCouch.Storage.Database).ValidateName("my/db"), "With slash valid")
}

/// <p>AC #5: Invalid database names fail validation.</p>
Method TestValidateNameInvalid()
{
    ; Empty string
    Set tSC = ##class(IRISCouch.Storage.Database).ValidateName("")
    Do $$$AssertStatusNotOK(tSC, "Empty string invalid")
    ; Uppercase letters
    Set tSC = ##class(IRISCouch.Storage.Database).ValidateName("MyDB")
    Do $$$AssertStatusNotOK(tSC, "Uppercase letters invalid")
    ; Starts with number
    Set tSC = ##class(IRISCouch.Storage.Database).ValidateName("1db")
    Do $$$AssertStatusNotOK(tSC, "Starting with number invalid")
    ; Contains spaces
    Set tSC = ##class(IRISCouch.Storage.Database).ValidateName("my db")
    Do $$$AssertStatusNotOK(tSC, "Spaces invalid")
    ; Contains special chars
    Set tSC = ##class(IRISCouch.Storage.Database).ValidateName("my*db")
    Do $$$AssertStatusNotOK(tSC, "Asterisk invalid")
    Set tSC = ##class(IRISCouch.Storage.Database).ValidateName("my:db")
    Do $$$AssertStatusNotOK(tSC, "Colon invalid")
    ; Just underscore
    Set tSC = ##class(IRISCouch.Storage.Database).ValidateName("_")
    Do $$$AssertStatusNotOK(tSC, "Single underscore invalid")
}

/// <p>AC #1/#2: ListAll returns empty array when no databases exist.</p>
Method TestListAllEmpty()
{
    ; Ensure no databases exist by killing all test dbs
    Kill ^IRISCouch.DB("aaa")
    Kill ^IRISCouch.DB("bbb")
    Kill ^IRISCouch.DB("ccc")
    Kill ^IRISCouch.DB("testdb")
    ; Kill any other test dbs that might exist
    Set tName = ""
    For {
        Set tName = $Order(^IRISCouch.DB(tName))
        Quit:tName=""
        Kill ^IRISCouch.DB(tName)
    }
    Set tResult = ##class(IRISCouch.Storage.Database).ListAll()
    Do $$$AssertTrue($IsObject(tResult), "ListAll returns an object")
    Do $$$AssertEquals(tResult.%Size(), 0, "ListAll returns empty array when no databases")
}

/// <p>AC #1: ListAll returns sorted array of database names.</p>
Method TestListAllWithDatabases()
{
    ; Create 3 databases in non-alphabetical order
    Set tSC = ##class(IRISCouch.Storage.Database).Create("ccc")
    Do $$$AssertStatusOK(tSC, "Create ccc succeeds")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("aaa")
    Do $$$AssertStatusOK(tSC, "Create aaa succeeds")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("bbb")
    Do $$$AssertStatusOK(tSC, "Create bbb succeeds")
    Set tResult = ##class(IRISCouch.Storage.Database).ListAll()
    Do $$$AssertTrue($IsObject(tResult), "ListAll returns an object")
    Do $$$AssertTrue(tResult.%Size() >= 3, "ListAll returns at least 3 databases")
    ; Find the positions of our test databases and verify order
    Set tFirst = tResult.%Get(0)
    Set tSecond = tResult.%Get(1)
    Set tThird = tResult.%Get(2)
    Do $$$AssertEquals(tFirst, "aaa", "First database is aaa (alphabetical)")
    Do $$$AssertEquals(tSecond, "bbb", "Second database is bbb (alphabetical)")
    Do $$$AssertEquals(tThird, "ccc", "Third database is ccc (alphabetical)")
}

/// <p>AC #3: GetInfo returns metadata for existing database.</p>
Method TestGetInfo()
{
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testdb")
    Do $$$AssertStatusOK(tSC, "Create testdb succeeds for GetInfo test")
    Set tInfo = ##class(IRISCouch.Storage.Database).GetInfo("testdb")
    Do $$$AssertTrue($IsObject(tInfo), "GetInfo returns an object")
    ; Verify all required CouchDB metadata fields
    Do $$$AssertEquals(tInfo."db_name", "testdb", "db_name is testdb")
    Do $$$AssertEquals(tInfo."doc_count", 0, "doc_count is 0")
    Do $$$AssertEquals(tInfo."doc_del_count", 0, "doc_del_count is 0")
    Do $$$AssertEquals(tInfo."update_seq", 0, "update_seq is 0")
    Do $$$AssertEquals(tInfo."purge_seq", 0, "purge_seq is 0")
    Do $$$AssertEquals(tInfo."compact_running", 0, "compact_running is false")
    Do $$$AssertEquals(tInfo."disk_size", 0, "disk_size is 0")
    Do $$$AssertEquals(tInfo."data_size", 0, "data_size is 0")
    Do $$$AssertEquals(tInfo."instance_start_time", "0", "instance_start_time is 0")
    Do $$$AssertEquals(tInfo."disk_format_version", 1, "disk_format_version is 1")
    Do $$$AssertEquals(tInfo."committed_update_seq", 0, "committed_update_seq matches update_seq")
}

/// <p>AC #4: GetInfo returns empty string for non-existent database.</p>
Method TestGetInfoNotFound()
{
    Set tInfo = ##class(IRISCouch.Storage.Database).GetInfo("nonexistentdb")
    Do $$$AssertEquals(tInfo, "", "GetInfo returns empty string for non-existent database")
}

}
