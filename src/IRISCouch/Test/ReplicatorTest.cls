/// <p>Integration tests for IRISCouch bidirectional replication protocol.</p>
/// <p>Tests local-to-local replication including full replication,
/// checkpoint-based resume, attachment replication, and conflict handling
/// (AC #1, #2, #4, #5, #6).</p>
Class IRISCouch.Test.ReplicatorTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up test databases before each test.</p>
Method OnBeforeOneTest() As %Status
{
    ; Clean up both source and target test databases
    Do ..CleanDB("replsrc")
    Do ..CleanDB("repltgt")
    ; Create source and target databases
    Set tSC = ##class(IRISCouch.Storage.Database).Create("replsrc")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(IRISCouch.Storage.Database).Create("repltgt")
    Quit tSC
}

/// <p>Clean up test databases after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ..CleanDB("replsrc")
    Do ..CleanDB("repltgt")
    Quit $$$OK
}

/// <p>Clean all globals for a test database.</p>
Method CleanDB(pDB As %String)
{
    Kill ^IRISCouch.DB(pDB)
    Kill ^IRISCouch.Docs(pDB)
    Kill ^IRISCouch.Tree(pDB)
    Kill ^IRISCouch.Changes(pDB)
    Kill ^IRISCouch.Seq(pDB)
    Kill ^IRISCouch.Local(pDB)
    Kill ^IRISCouch.Atts(pDB)
    Kill ^IRISCouch.Proj(pDB)
    Kill ^IRISCouch.MangoIdx(pDB)
    Kill ^IRISCouch.MangoIdxD(pDB)
}

/// <p>AC #1: Full local-to-local replication — all source docs present in target.</p>
Method TestLocalToLocalReplication()
{
    ; Create documents in source
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "doc1", "{""name"":""Alice""}")
    Do $$$AssertTrue(tRev1 '= "", "doc1 created in source")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "doc2", "{""name"":""Bob""}")
    Do $$$AssertTrue(tRev2 '= "", "doc2 created in source")
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "doc3", "{""name"":""Charlie""}")
    Do $$$AssertTrue(tRev3 '= "", "doc3 created in source")
    ; Replicate source -> target
    Set tSC = ##class(IRISCouch.Replication.Replicator).Replicate("replsrc", "repltgt")
    Do $$$AssertStatusOK(tSC, "Replication completes successfully")
    ; Verify all documents present in target
    Set tBody1 = ##class(IRISCouch.Storage.Document).Read("repltgt", "doc1", tRev1)
    Do $$$AssertTrue(tBody1 '= "", "doc1 present in target")
    Set tDoc1 = ##class(%DynamicObject).%FromJSON(tBody1)
    Do $$$AssertEquals(tDoc1.%Get("name"), "Alice", "doc1 content correct in target")
    Set tBody2 = ##class(IRISCouch.Storage.Document).Read("repltgt", "doc2", tRev2)
    Do $$$AssertTrue(tBody2 '= "", "doc2 present in target")
    Set tBody3 = ##class(IRISCouch.Storage.Document).Read("repltgt", "doc3", tRev3)
    Do $$$AssertTrue(tBody3 '= "", "doc3 present in target")
    ; Verify revision trees exist in target
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("repltgt", "doc1", tRev1), "doc1 rev exists in target tree")
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("repltgt", "doc2", tRev2), "doc2 rev exists in target tree")
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("repltgt", "doc3", tRev3), "doc3 rev exists in target tree")
    ; FR59: Verify revision hashes match source (deterministic from content)
    Do $$$AssertEquals(##class(IRISCouch.Storage.RevTree).GetWinner("repltgt", "doc1"), tRev1, "doc1 winner rev matches source (FR59)")
    Do $$$AssertEquals(##class(IRISCouch.Storage.RevTree).GetWinner("repltgt", "doc2"), tRev2, "doc2 winner rev matches source (FR59)")
}

/// <p>AC #4: Replicate, add more docs, replicate again — checkpoint used.</p>
Method TestLocalToLocalResume()
{
    ; Create initial documents
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "doc1", "{""v"":1}")
    Do $$$AssertTrue(tRev1 '= "", "doc1 created in source")
    ; First replication
    Set tSC = ##class(IRISCouch.Replication.Replicator).Replicate("replsrc", "repltgt")
    Do $$$AssertStatusOK(tSC, "First replication succeeds")
    ; Verify checkpoint exists
    Set tRepId = ##class(IRISCouch.Replication.ReplicationId).Compute("replsrc", "repltgt")
    Set tSourceCkpt = ##class(IRISCouch.Replication.Checkpoint).Read("replsrc", tRepId, 1)
    Do $$$AssertTrue($IsObject(tSourceCkpt), "Source checkpoint exists after first replication")
    Set tFirstLastSeq = +tSourceCkpt.%Get("source_last_seq")
    Do $$$AssertTrue(tFirstLastSeq > 0, "Checkpoint recorded a non-zero sequence")
    ; Add more documents to source
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "doc2", "{""v"":2}")
    Do $$$AssertTrue(tRev2 '= "", "doc2 created in source after first replication")
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "doc3", "{""v"":3}")
    Do $$$AssertTrue(tRev3 '= "", "doc3 created in source after first replication")
    ; Second replication (should only transfer doc2 and doc3)
    Set tSC2 = ##class(IRISCouch.Replication.Replicator).Replicate("replsrc", "repltgt")
    Do $$$AssertStatusOK(tSC2, "Second replication succeeds")
    ; Verify all docs present in target
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("repltgt", "doc1", tRev1), "doc1 still present from first replication")
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("repltgt", "doc2", tRev2), "doc2 present from second replication")
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("repltgt", "doc3", tRev3), "doc3 present from second replication")
    ; Verify checkpoint was updated
    Set tSourceCkpt2 = ##class(IRISCouch.Replication.Checkpoint).Read("replsrc", tRepId, 1)
    Set tSecondLastSeq = +tSourceCkpt2.%Get("source_last_seq")
    Do $$$AssertTrue(tSecondLastSeq > tFirstLastSeq, "Checkpoint advanced to newer sequence")
}

/// <p>AC #1: Replicate documents with attachments.</p>
Method TestLocalToLocalWithAttachments()
{
    ; Create a document with an inline attachment in source
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "attdoc", "{""type"":""file""}")
    Do $$$AssertTrue(tRev1 '= "", "attdoc created in source")
    ; Store an attachment on the document
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("Hello, replication attachment test!")
    Do tStream.%Save()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("replsrc", "attdoc", tRev1, "readme.txt", "text/plain", tStream, 1)
    Do $$$AssertStatusOK(tSC, "Attachment stored in source")
    ; Replicate
    Set tSC2 = ##class(IRISCouch.Replication.Replicator).Replicate("replsrc", "repltgt")
    Do $$$AssertStatusOK(tSC2, "Replication with attachment succeeds")
    ; Verify document present in target
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("repltgt", "attdoc", tRev1), "attdoc present in target")
    ; Verify attachment present in target
    Set tSC3 = ##class(IRISCouch.Storage.Attachment).Get("repltgt", "attdoc", "readme.txt", .tTargetStream, .tContentType, .tLength, .tDigest, tRev1)
    Do $$$AssertStatusOK(tSC3, "Attachment retrieved from target")
    Do $$$AssertTrue($IsObject(tTargetStream), "Target attachment stream exists")
    Do $$$AssertEquals(tContentType, "text/plain", "Attachment content type correct")
    Do $$$AssertTrue(tLength > 0, "Attachment has non-zero length")
}

/// <p>AC #1, #6: Replicate conflicting branches — both branches exist in target.</p>
Method TestLocalToLocalConflict()
{
    ; Create doc1 in both source and target with same initial content
    Set tRev1S = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "conflictdoc", "{""v"":1}")
    Do $$$AssertTrue(tRev1S '= "", "conflictdoc created in source")
    ; Replicate initial state
    Set tSC = ##class(IRISCouch.Replication.Replicator).Replicate("replsrc", "repltgt")
    Do $$$AssertStatusOK(tSC, "Initial replication succeeds")
    ; Now create different updates on source and target (diverging branches)
    Set tRev2S = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "conflictdoc", "{""v"":""source-branch""}", tRev1S)
    Do $$$AssertTrue(tRev2S '= "", "Source branch created")
    Set tRev2T = ##class(IRISCouch.Core.DocumentEngine).Save("repltgt", "conflictdoc", "{""v"":""target-branch""}", tRev1S)
    Do $$$AssertTrue(tRev2T '= "", "Target branch created")
    ; Replicate again — should merge branches (both exist)
    Set tSC2 = ##class(IRISCouch.Replication.Replicator).Replicate("replsrc", "repltgt")
    Do $$$AssertStatusOK(tSC2, "Conflict replication succeeds (NFR-R1: no corruption)")
    ; Both revisions should exist in target
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("repltgt", "conflictdoc", tRev2S), "Source branch exists in target")
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("repltgt", "conflictdoc", tRev2T), "Target branch still exists in target")
    ; One of them should be the winner
    Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner("repltgt", "conflictdoc")
    Do $$$AssertTrue(tWinner '= "", "Winner is determined after conflict replication")
    ; The other should be in conflicts
    Set tConflicts = ##class(IRISCouch.Storage.RevTree).GetConflicts("repltgt", "conflictdoc")
    Do $$$AssertTrue(tConflicts.%Size() > 0, "Conflict branches are preserved")
}

/// <p>AC #3: Replication ID is deterministic (same source/target = same ID).</p>
Method TestReplicationIdDeterministic()
{
    ; Replicate first time
    Set tSC1 = ##class(IRISCouch.Replication.Replicator).Replicate("replsrc", "repltgt")
    Do $$$AssertStatusOK(tSC1, "First replication ok")
    Set tRepId1 = ##class(IRISCouch.Replication.ReplicationId).Compute("replsrc", "repltgt")
    ; Replicate second time
    Set tSC2 = ##class(IRISCouch.Replication.Replicator).Replicate("replsrc", "repltgt")
    Do $$$AssertStatusOK(tSC2, "Second replication ok")
    Set tRepId2 = ##class(IRISCouch.Replication.ReplicationId).Compute("replsrc", "repltgt")
    Do $$$AssertEquals(tRepId1, tRepId2, "Replication ID is deterministic across runs (FR57)")
}

/// <p>AC #1: Replication of an empty source to empty target succeeds.</p>
Method TestLocalToLocalEmptyDatabases()
{
    ; Both databases exist but have no documents
    Set tSC = ##class(IRISCouch.Replication.Replicator).Replicate("replsrc", "repltgt")
    Do $$$AssertStatusOK(tSC, "Replication of empty databases succeeds gracefully")
}

/// <p>Error handling: Non-existent source database produces error.</p>
Method TestNonExistentSource()
{
    Kill ^IRISCouch.DB("nonexist")
    Set tSC = ##class(IRISCouch.Replication.Replicator).Replicate("nonexist", "repltgt")
    Do $$$AssertStatusNotOK(tSC, "Non-existent source returns error")
}

/// <p>Error handling: Non-existent target database produces error.</p>
Method TestNonExistentTarget()
{
    Kill ^IRISCouch.DB("nonexist2")
    Set tSC = ##class(IRISCouch.Replication.Replicator).Replicate("replsrc", "nonexist2")
    Do $$$AssertStatusNotOK(tSC, "Non-existent target returns error")
}

/// <p>AC #1: Replicate documents with updates (multi-revision docs).</p>
Method TestLocalToLocalMultiRevision()
{
    ; Create a doc and update it multiple times in source
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "multidoc", "{""v"":1}")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "multidoc", "{""v"":2}", tRev1)
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).Save("replsrc", "multidoc", "{""v"":3}", tRev2)
    Do $$$AssertTrue(tRev3 '= "", "Multi-revision doc created in source")
    ; Replicate
    Set tSC = ##class(IRISCouch.Replication.Replicator).Replicate("replsrc", "repltgt")
    Do $$$AssertStatusOK(tSC, "Multi-revision replication succeeds")
    ; Verify the latest revision exists in target
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("repltgt", "multidoc", tRev3), "Latest revision present in target")
    ; Verify the full revision history is in target
    Set tRevisions = ##class(IRISCouch.Storage.RevTree).GetRevisions("repltgt", "multidoc", tRev3)
    Do $$$AssertTrue($IsObject(tRevisions), "Revision history present in target")
    Do $$$AssertEquals(+tRevisions.%Get("start"), 3, "Revision start is 3 (3 generations)")
    Do $$$AssertEquals(tRevisions.%Get("ids").%Size(), 3, "Full 3-revision history in target")
}

}
