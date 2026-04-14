/// <p>Unit tests for IRISCouch replication ID computation.</p>
/// <p>Tests deterministic replication ID generation, different inputs
/// producing different IDs, and option effects on the ID (AC #3, FR57).</p>
Class IRISCouch.Test.ReplicationIdTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>AC #3, FR57: Same inputs produce same replication ID across calls.</p>
Method TestComputeDeterministic()
{
    Set tId1 = ##class(IRISCouch.Replication.ReplicationId).Compute("sourcedb", "targetdb")
    Set tId2 = ##class(IRISCouch.Replication.ReplicationId).Compute("sourcedb", "targetdb")
    Do $$$AssertEquals(tId1, tId2, "Same inputs produce same replication ID (deterministic)")
    Do $$$AssertTrue(tId1 '= "", "Replication ID is non-empty")
    Do $$$AssertEquals($Length(tId1), 32, "Replication ID is 32-character hex MD5")
}

/// <p>AC #3: Different source/target combinations produce different IDs.</p>
Method TestComputeDifferentInputs()
{
    Set tId1 = ##class(IRISCouch.Replication.ReplicationId).Compute("sourcedb", "targetdb")
    Set tId2 = ##class(IRISCouch.Replication.ReplicationId).Compute("otherdb", "targetdb")
    Set tId3 = ##class(IRISCouch.Replication.ReplicationId).Compute("sourcedb", "otherdb")
    Do $$$AssertTrue(tId1 '= tId2, "Different source produces different ID")
    Do $$$AssertTrue(tId1 '= tId3, "Different target produces different ID")
    Do $$$AssertTrue(tId2 '= tId3, "All three IDs are unique")
}

/// <p>AC #3: Options (filter, doc_ids) affect the replication ID.</p>
Method TestComputeWithOptions()
{
    Set tIdNoOpts = ##class(IRISCouch.Replication.ReplicationId).Compute("sourcedb", "targetdb")
    ; With filter option
    Set tOpts1 = {}
    Do tOpts1.%Set("filter", "mydesign/myfilter")
    Set tIdFilter = ##class(IRISCouch.Replication.ReplicationId).Compute("sourcedb", "targetdb", tOpts1)
    Do $$$AssertTrue(tIdNoOpts '= tIdFilter, "Filter option changes the replication ID")
    ; With doc_ids option
    Set tOpts2 = {}
    Set tDocIds = ["doc1", "doc2"]
    Do tOpts2.%Set("doc_ids", tDocIds)
    Set tIdDocIds = ##class(IRISCouch.Replication.ReplicationId).Compute("sourcedb", "targetdb", tOpts2)
    Do $$$AssertTrue(tIdNoOpts '= tIdDocIds, "doc_ids option changes the replication ID")
    Do $$$AssertTrue(tIdFilter '= tIdDocIds, "Different options produce different IDs")
    ; With continuous option
    Set tOpts3 = {}
    Do tOpts3.%Set("continuous", 1, "boolean")
    Set tIdCont = ##class(IRISCouch.Replication.ReplicationId).Compute("sourcedb", "targetdb", tOpts3)
    Do $$$AssertTrue(tIdNoOpts '= tIdCont, "continuous option changes the replication ID")
}

/// <p>FR57: Same options in different order produce same ID (option key sorting).</p>
Method TestComputeOptionOrdering()
{
    ; Options added in different order should produce same ID
    Set tOpts1 = {}
    Do tOpts1.%Set("continuous", 1, "boolean")
    Do tOpts1.%Set("filter", "myfilter")
    Set tOpts2 = {}
    Do tOpts2.%Set("filter", "myfilter")
    Do tOpts2.%Set("continuous", 1, "boolean")
    Set tId1 = ##class(IRISCouch.Replication.ReplicationId).Compute("src", "tgt", tOpts1)
    Set tId2 = ##class(IRISCouch.Replication.ReplicationId).Compute("src", "tgt", tOpts2)
    Do $$$AssertEquals(tId1, tId2, "Options in different order produce same ID (sorted)")
}

/// <p>IsLocalDB correctly identifies local vs remote databases.</p>
Method TestIsLocalDB()
{
    Do $$$AssertTrue(##class(IRISCouch.Replication.ReplicationId).IsLocalDB("mydb"), "Simple name is local")
    Do $$$AssertTrue(##class(IRISCouch.Replication.ReplicationId).IsLocalDB("test-db"), "Hyphenated name is local")
    Do $$$AssertTrue('##class(IRISCouch.Replication.ReplicationId).IsLocalDB("http://localhost:5984/mydb"), "HTTP URL is remote")
    Do $$$AssertTrue('##class(IRISCouch.Replication.ReplicationId).IsLocalDB("https://couch.example.com/mydb"), "HTTPS URL is remote")
    Do $$$AssertTrue('##class(IRISCouch.Replication.ReplicationId).IsLocalDB("HTTP://HOST/db"), "Case-insensitive HTTP detection")
}

/// <p>Non-identity options (arbitrary keys) do not affect the replication ID.</p>
Method TestComputeIgnoresNonIdentityOptions()
{
    Set tIdBase = ##class(IRISCouch.Replication.ReplicationId).Compute("src", "tgt")
    Set tOpts = {}
    Do tOpts.%Set("batch_size", 50, "number")
    Do tOpts.%Set("worker_processes", 4, "number")
    Set tIdWithOpts = ##class(IRISCouch.Replication.ReplicationId).Compute("src", "tgt", tOpts)
    Do $$$AssertEquals(tIdBase, tIdWithOpts, "Non-identity options do not change replication ID")
}

}
