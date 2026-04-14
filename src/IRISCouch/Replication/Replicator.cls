/// <p>CouchDB replication protocol state machine for IRISCouch.</p>
/// <p>Implements the full 6-phase CouchDB replication protocol for bidirectional
/// replication between IRISCouch databases (local-to-local) and between IRISCouch
/// and remote CouchDB 3.x peers (local-to-remote, remote-to-local).</p>
/// <h4>Replication Phases:</h4>
/// <ol>
/// <li>Verify Peers</li>
/// <li>Get Peer Info</li>
/// <li>Compute Replication ID (FR57: deterministic)</li>
/// <li>Find Common Ancestry (checkpoint-based resume)</li>
/// <li>Locate Changes (_changes + _revs_diff)</li>
/// <li>Replicate Changes (_bulk_get + _bulk_docs + checkpoint update)</li>
/// </ol>
/// <p>NFR-R1: Rev-tree corruption after SaveWithHistory is flagged as error.</p>
/// <p>FR59: Revision hashes preserved from source via new_edits=false.</p>
Class IRISCouch.Replication.Replicator Extends %RegisteredObject
{

/// <p>Source database name or URL.</p>
Property Source As %String;

/// <p>Target database name or URL.</p>
Property Target As %String;

/// <p>Replication options (%DynamicObject).</p>
Property Options As %DynamicObject;

/// <p>Computed replication ID (deterministic).</p>
Property ReplicationId As %String;

/// <p>Session UUID for this replication run.</p>
Property SessionId As %String;

/// <p>Replication statistics.</p>
Property Stats As %DynamicObject;

/// <p>Default batch size for document transfer.</p>
Parameter BATCHSIZE = 100;

/// <p>Main entry point for one-shot replication.</p>
/// <p>Detects local vs. remote for source and target, then dispatches
/// to the appropriate replication method. Returns status with stats.</p>
/// @param pSource The source database name or URL
/// @param pTarget The target database name or URL
/// @param pOptions Optional replication options
/// @return %Status
ClassMethod Replicate(pSource As %String, pTarget As %String, pOptions As %DynamicObject = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSourceLocal = ##class(IRISCouch.Replication.ReplicationId).IsLocalDB(pSource)
        Set tTargetLocal = ##class(IRISCouch.Replication.ReplicationId).IsLocalDB(pTarget)
        If tSourceLocal && tTargetLocal {
            ; Local-to-local: both databases are in IRISCouch
            Set tSC = ..ReplicateLocalToLocal(pSource, pTarget, pOptions)
            Quit
        }
        If tSourceLocal && 'tTargetLocal {
            ; Push: local source to remote target
            Set tTargetClient = ##class(IRISCouch.Replication.HttpClient).FromUrl(pTarget)
            If '$IsObject(tTargetClient) {
                Set tSC = $$$ERROR($$$GeneralError, "Failed to parse target URL: " _ pTarget)
                Quit
            }
            Set tSC = ..ReplicateLocal(pSource, tTargetClient, pOptions)
            Quit
        }
        If 'tSourceLocal && tTargetLocal {
            ; Pull: remote source to local target
            Set tSourceClient = ##class(IRISCouch.Replication.HttpClient).FromUrl(pSource)
            If '$IsObject(tSourceClient) {
                Set tSC = $$$ERROR($$$GeneralError, "Failed to parse source URL: " _ pSource)
                Quit
            }
            Set tSC = ..ReplicateRemote(tSourceClient, pTarget, pOptions)
            Quit
        }
        ; Remote-to-remote: not supported by this implementation
        Set tSC = $$$ERROR($$$GeneralError, "Remote-to-remote replication not supported")
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Local-to-local replication between two IRISCouch databases.</p>
/// <p>This is the primary test path. Uses direct storage method calls
/// instead of HTTP. Implements all 6 phases of the CouchDB protocol.</p>
/// @param pSourceDB The source database name
/// @param pTargetDB The target database name
/// @param pOptions Optional replication options
/// @return %Status
ClassMethod ReplicateLocalToLocal(pSourceDB As %String, pTargetDB As %String, pOptions As %DynamicObject = "") As %Status
{
    Set tSC = $$$OK
    Try {
        ; ---- Phase 1: Verify Peers ----
        If '##class(IRISCouch.Storage.Database).Exists(pSourceDB) {
            Set tSC = $$$ERROR($$$GeneralError, "Source database does not exist: " _ pSourceDB)
            Quit
        }
        If '##class(IRISCouch.Storage.Database).Exists(pTargetDB) {
            ; Check create_target option
            If $IsObject(pOptions) && (pOptions.%Get("create_target") = 1) {
                Set tSC = ##class(IRISCouch.Storage.Database).Create(pTargetDB)
                If $$$ISERR(tSC) Quit
            } Else {
                Set tSC = $$$ERROR($$$GeneralError, "Target database does not exist: " _ pTargetDB)
                Quit
            }
        }
        ; ---- Phase 2: Get Peer Info ----
        ; (For local, we just verify existence — metadata already accessible)
        ; ---- Phase 3: Compute Replication ID (FR57: deterministic) ----
        Set tRepId = ##class(IRISCouch.Replication.ReplicationId).Compute(pSourceDB, pTargetDB, pOptions)
        ; ---- Phase 4: Find Common Ancestry (checkpoint resume) ----
        Set tSessionId = ##class(IRISCouch.Util.UUID).Generate()
        Set tSourceCkpt = ##class(IRISCouch.Replication.Checkpoint).Read(pSourceDB, tRepId, 1)
        Set tTargetCkpt = ##class(IRISCouch.Replication.Checkpoint).Read(pTargetDB, tRepId, 1)
        Set tSince = ##class(IRISCouch.Replication.Checkpoint).FindCommonAncestry(tSourceCkpt, tTargetCkpt)
        ; Coerce to integer for ListChanges
        Set tSince = +tSince
        ; ---- Phase 5: Locate Changes ----
        Set tChanges = ##class(IRISCouch.Storage.Changes).ListChanges(pSourceDB, tSince, 0, 0)
        Set tResults = tChanges.%Get("results")
        Set tLastSeq = tChanges.%Get("lastSeq")
        ; If no changes, nothing to do — but still update checkpoint
        If tResults.%Size() = 0 {
            ; No new changes to replicate
            Quit
        }
        ; ---- Phase 5b: _revs_diff on target ----
        ; Build revs_diff request: {docId: [rev1, rev2, ...]}
        Set tRevsDiffReq = {}
        Set tI = 0
        While tI < tResults.%Size() {
            Set tChange = tResults.%Get(tI)
            Set tDocId = tChange.%Get("id")
            Set tChangeRevs = tChange.%Get("changes")
            Set tRevArray = []
            Set tJ = 0
            While tJ < tChangeRevs.%Size() {
                Do tRevArray.%Push(tChangeRevs.%Get(tJ).%Get("rev"))
                Set tJ = tJ + 1
            }
            Do tRevsDiffReq.%Set(tDocId, tRevArray)
            Set tI = tI + 1
        }
        ; Compute revs_diff locally against target
        Set tMissing = ..ComputeRevsDiffLocal(pTargetDB, tRevsDiffReq)
        ; If nothing missing, skip transfer
        Set tMissingIter = tMissing.%GetIterator()
        Set tHasMissing = 0
        While tMissingIter.%GetNext(.tKey, .tVal) {
            Set tHasMissing = 1
            Quit
        }
        If 'tHasMissing {
            ; All revisions already present in target; update checkpoint
        } Else {
            ; ---- Phase 6: Replicate Changes ----
            ; Collect all missing doc/rev pairs
            Set tBatch = []
            Set tMissingIter2 = tMissing.%GetIterator()
            While tMissingIter2.%GetNext(.tDocId, .tDocResult) {
                Set tMissingRevs = tDocResult.%Get("missing")
                If '$IsObject(tMissingRevs) Continue
                Set tK = 0
                While tK < tMissingRevs.%Size() {
                    Set tPair = {}
                    Do tPair.%Set("id", tDocId)
                    Do tPair.%Set("rev", tMissingRevs.%Get(tK))
                    Do tBatch.%Push(tPair)
                    Set tK = tK + 1
                }
            }
            ; Process in batches
            Set tBatchSize = ..#BATCHSIZE
            If $IsObject(pOptions) && (pOptions.%IsDefined("batch_size")) {
                Set tBatchSize = +pOptions.%Get("batch_size")
                If tBatchSize < 1 Set tBatchSize = ..#BATCHSIZE
            }
            Set tDocsRead = 0
            Set tDocsWritten = 0
            Set tDocWriteFailures = 0
            Set tBatchIdx = 0
            While tBatchIdx < tBatch.%Size() {
                ; Process this batch
                Set tBatchEnd = tBatchIdx + tBatchSize - 1
                If tBatchEnd >= tBatch.%Size() Set tBatchEnd = tBatch.%Size() - 1
                ; Fetch and write each doc in the batch
                Set tBI = tBatchIdx
                While tBI <= tBatchEnd {
                    Set tPair = tBatch.%Get(tBI)
                    Set tDocId = tPair.%Get("id")
                    Set tRev = tPair.%Get("rev")
                    Set tDocsRead = tDocsRead + 1
                    ; Fetch doc body from source
                    Set tBody = ##class(IRISCouch.Storage.Document).Read(pSourceDB, tDocId, tRev)
                    ; Get revisions history from source
                    Set tRevisions = ##class(IRISCouch.Storage.RevTree).GetRevisions(pSourceDB, tDocId, tRev)
                    ; Check if deleted
                    Set tDeleted = ##class(IRISCouch.Storage.RevTree).IsDeleted(pSourceDB, tDocId, tRev)
                    ; Write to target via SaveWithHistory (new_edits=false semantics)
                    Set tSC2 = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory(pTargetDB, tDocId, tBody, tRev, tRevisions, tDeleted)
                    If $$$ISERR(tSC2) {
                        Set tDocWriteFailures = tDocWriteFailures + 1
                    } Else {
                        Set tDocsWritten = tDocsWritten + 1
                        ; NFR-R1: Verify rev was stored correctly
                        If '##class(IRISCouch.Storage.RevTree).RevExists(pTargetDB, tDocId, tRev) {
                            Set tSC = $$$ERROR($$$GeneralError, "NFR-R1: Rev-tree corruption detected for " _ tDocId _ " rev " _ tRev)
                            Quit
                        }
                        ; Replicate attachments for this doc/rev
                        Set tSC3 = ..ReplicateAttachmentsLocal(pSourceDB, pTargetDB, tDocId, tRev)
                        If $$$ISERR(tSC3) {
                            Set tDocWriteFailures = tDocWriteFailures + 1
                        }
                    }
                    Set tBI = tBI + 1
                }
                ; Check for NFR-R1 corruption error
                If $$$ISERR(tSC) Quit
                Set tBatchIdx = tBatchEnd + 1
            }
        }
        ; ---- Phase 9: Update Checkpoints ----
        If $$$ISOK(tSC) {
            ; Build history entry for this session
            Set tHistoryEntry = {}
            Do tHistoryEntry.%Set("session_id", tSessionId)
            Do tHistoryEntry.%Set("start_last_seq", tSince, "number")
            Do tHistoryEntry.%Set("end_last_seq", tLastSeq, "number")
            Do tHistoryEntry.%Set("recorded_seq", tLastSeq, "number")
            ; Build history array — prepend new entry
            Set tHistory = []
            Do tHistory.%Push(tHistoryEntry)
            ; Add prior history from existing checkpoint (up to 5 entries)
            If $IsObject(tSourceCkpt) {
                Set tOldHistory = tSourceCkpt.%Get("history")
                If $IsObject(tOldHistory) {
                    Set tOH = 0
                    While (tOH < tOldHistory.%Size()) && (tOH < 4) {
                        Do tHistory.%Push(tOldHistory.%Get(tOH))
                        Set tOH = tOH + 1
                    }
                }
            }
            Set tCheckpoint = ##class(IRISCouch.Replication.Checkpoint).BuildCheckpointDoc(tRepId, tSessionId, tLastSeq, tHistory)
            ; Write checkpoint to both source and target
            Set tSC2 = ##class(IRISCouch.Replication.Checkpoint).Write(pSourceDB, tRepId, tCheckpoint, 1)
            If $$$ISERR(tSC2) Set tSC = tSC2
            Set tSC3 = ##class(IRISCouch.Replication.Checkpoint).Write(pTargetDB, tRepId, tCheckpoint, 1)
            If $$$ISERR(tSC3) && $$$ISOK(tSC) Set tSC = tSC3
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Compute _revs_diff locally against a target database.</p>
/// <p>Equivalent to HandleRevsDiff but called directly without HTTP.
/// Returns only documents with missing revisions.</p>
/// @param pTargetDB The target database name
/// @param pRevsDiffReq The revs_diff request object {docId: [rev1, ...]}
/// @return %DynamicObject The revs_diff response
ClassMethod ComputeRevsDiffLocal(pTargetDB As %String, pRevsDiffReq As %DynamicObject) As %DynamicObject
{
    Set tResponse = {}
    Set tIter = pRevsDiffReq.%GetIterator()
    While tIter.%GetNext(.tDocId, .tRevArray) {
        If '$IsObject(tRevArray) Continue
        Set tMissing = []
        Set tRevIter = tRevArray.%GetIterator()
        While tRevIter.%GetNext(.tIdx, .tRev) {
            If '##class(IRISCouch.Storage.RevTree).RevExists(pTargetDB, tDocId, tRev) {
                Do tMissing.%Push(tRev)
            }
        }
        If tMissing.%Size() > 0 {
            Set tDocResult = {}
            Do tDocResult.%Set("missing", tMissing)
            Set tLeaves = ##class(IRISCouch.Storage.RevTree).GetLeafRevs(pTargetDB, tDocId)
            If tLeaves.%Size() > 0 {
                Do tDocResult.%Set("possible_ancestors", tLeaves)
            }
            Do tResponse.%Set(tDocId, tDocResult)
        }
    }
    Quit tResponse
}

/// <p>Replicate attachments for a specific document revision from source to target.</p>
/// <p>Copies all attachment data from source database to target database
/// for the specified document and revision.</p>
/// @param pSourceDB The source database name
/// @param pTargetDB The target database name
/// @param pDocId The document identifier
/// @param pRev The revision string
/// @return %Status
ClassMethod ReplicateAttachmentsLocal(pSourceDB As %String, pTargetDB As %String, pDocId As %String, pRev As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Use Storage.Attachment.GetMetadata to enumerate attachments (storage encapsulation)
        Set tSourceMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata(pSourceDB, pDocId, pRev)
        If '$IsObject(tSourceMeta) Quit
        ; Get target metadata once for comparison
        Set tTargetMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata(pTargetDB, pDocId, pRev)
        ; Iterate attachment names from metadata
        Set tIter = tSourceMeta.%GetIterator()
        While tIter.%GetNext(.tAttName, .tStub) {
            ; Check if attachment already exists in target
            If $IsObject(tTargetMeta) && tTargetMeta.%IsDefined(tAttName) Continue
            ; Get attachment from source
            Set tSC2 = ##class(IRISCouch.Storage.Attachment).Get(pSourceDB, pDocId, tAttName, .tStream, .tContentType, .tLength, .tDigest, pRev)
            If $$$ISERR(tSC2) Continue
            If '$IsObject(tStream) Continue
            ; Store in target
            Set tRevPos = +$Piece(pRev, "-", 1)
            Set tSC3 = ##class(IRISCouch.Storage.Attachment).Store(pTargetDB, pDocId, pRev, tAttName, tContentType, tStream, tRevPos)
            If $$$ISERR(tSC3) {
                Set tSC = tSC3
                Quit
            }
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Push replication: local source to remote target via HTTP.</p>
/// @param pSourceDB The local source database name
/// @param pTargetClient The HttpClient for the remote target
/// @param pOptions Optional replication options
/// @return %Status
ClassMethod ReplicateLocal(pSourceDB As %String, pTargetClient As IRISCouch.Replication.HttpClient, pOptions As %DynamicObject = "") As %Status
{
    Set tSC = $$$OK
    Try {
        ; Phase 1: Verify source exists locally
        If '##class(IRISCouch.Storage.Database).Exists(pSourceDB) {
            Set tSC = $$$ERROR($$$GeneralError, "Source database does not exist: " _ pSourceDB)
            Quit
        }
        ; Verify remote target (HEAD request)
        Set tSC2 = pTargetClient.Request("HEAD", "/", "", .tStatusCode, .tBody)
        If $$$ISERR(tSC2) || (tStatusCode '= 200) {
            ; Try to create target if option set
            If $IsObject(pOptions) && (pOptions.%Get("create_target") = 1) {
                Set tSC3 = pTargetClient.Put("/", "", .tStatusCode2, .tBody2)
                If $$$ISERR(tSC3) || ((tStatusCode2 '= 201) && (tStatusCode2 '= 200)) {
                    Set tSC = $$$ERROR($$$GeneralError, "Failed to create remote target database")
                    Quit
                }
            } Else {
                Set tSC = $$$ERROR($$$GeneralError, "Remote target database not accessible")
                Quit
            }
        }
        ; Phase 3: Compute replication ID
        Set tTargetUrl = pTargetClient.Server _ ":" _ pTargetClient.Port _ pTargetClient.BasePath
        Set tRepId = ##class(IRISCouch.Replication.ReplicationId).Compute(pSourceDB, tTargetUrl, pOptions)
        ; Phase 4: Find common ancestry
        Set tSessionId = ##class(IRISCouch.Util.UUID).Generate()
        Set tSourceCkpt = ##class(IRISCouch.Replication.Checkpoint).Read(pSourceDB, tRepId, 1)
        Set tTargetCkpt = ##class(IRISCouch.Replication.Checkpoint).Read("", tRepId, 0, pTargetClient)
        Set tSince = +##class(IRISCouch.Replication.Checkpoint).FindCommonAncestry(tSourceCkpt, tTargetCkpt)
        ; Phase 5: Get changes from local source
        Set tChanges = ##class(IRISCouch.Storage.Changes).ListChanges(pSourceDB, tSince, 0, 0)
        Set tResults = tChanges.%Get("results")
        Set tLastSeq = tChanges.%Get("lastSeq")
        If tResults.%Size() = 0 Quit
        ; Phase 5b: Post _revs_diff to remote target
        Set tRevsDiffReq = {}
        Set tI = 0
        While tI < tResults.%Size() {
            Set tChange = tResults.%Get(tI)
            Set tDocId = tChange.%Get("id")
            Set tChangeRevs = tChange.%Get("changes")
            Set tRevArray = []
            Set tJ = 0
            While tJ < tChangeRevs.%Size() {
                Do tRevArray.%Push(tChangeRevs.%Get(tJ).%Get("rev"))
                Set tJ = tJ + 1
            }
            Do tRevsDiffReq.%Set(tDocId, tRevArray)
            Set tI = tI + 1
        }
        Set tSC4 = pTargetClient.Post("/_revs_diff", tRevsDiffReq.%ToJSON(), .tDiffStatus, .tDiffBody)
        If $$$ISERR(tSC4) || (tDiffStatus '= 200) {
            Set tSC = $$$ERROR($$$GeneralError, "Remote _revs_diff failed")
            Quit
        }
        Set tMissing = ##class(%DynamicObject).%FromJSON(tDiffBody)
        ; Phase 6: Build _bulk_docs payload for remote target
        Set tBulkDocs = []
        Set tMissingIter = tMissing.%GetIterator()
        While tMissingIter.%GetNext(.tDocId, .tDocResult) {
            Set tMissingRevs = tDocResult.%Get("missing")
            If '$IsObject(tMissingRevs) Continue
            Set tK = 0
            While tK < tMissingRevs.%Size() {
                Set tRev = tMissingRevs.%Get(tK)
                Set tBody = ##class(IRISCouch.Storage.Document).Read(pSourceDB, tDocId, tRev)
                Set tRevisions = ##class(IRISCouch.Storage.RevTree).GetRevisions(pSourceDB, tDocId, tRev)
                Set tDeleted = ##class(IRISCouch.Storage.RevTree).IsDeleted(pSourceDB, tDocId, tRev)
                ; Build doc for _bulk_docs
                If tBody '= "" {
                    Set tDoc = ##class(%DynamicObject).%FromJSON(tBody)
                } Else {
                    Set tDoc = {}
                }
                Do tDoc.%Set("_id", tDocId)
                Do tDoc.%Set("_rev", tRev)
                Do tDoc.%Set("_revisions", tRevisions)
                If tDeleted Do tDoc.%Set("_deleted", 1, "boolean")
                Do tBulkDocs.%Push(tDoc)
                Set tK = tK + 1
            }
        }
        ; Post _bulk_docs with new_edits=false
        If tBulkDocs.%Size() > 0 {
            Set tBulkBody = {}
            Do tBulkBody.%Set("docs", tBulkDocs)
            Do tBulkBody.%Set("new_edits", 0, "boolean")
            Set tSC5 = pTargetClient.Post("/_bulk_docs", tBulkBody.%ToJSON(), .tBulkStatus, .tBulkResp)
            If $$$ISERR(tSC5) {
                Set tSC = tSC5
                Quit
            }
        }
        ; Phase 9: Update checkpoints
        Set tHistoryEntry = {}
        Do tHistoryEntry.%Set("session_id", tSessionId)
        Do tHistoryEntry.%Set("start_last_seq", tSince, "number")
        Do tHistoryEntry.%Set("end_last_seq", tLastSeq, "number")
        Do tHistoryEntry.%Set("recorded_seq", tLastSeq, "number")
        Set tHistory = []
        Do tHistory.%Push(tHistoryEntry)
        Set tCheckpoint = ##class(IRISCouch.Replication.Checkpoint).BuildCheckpointDoc(tRepId, tSessionId, tLastSeq, tHistory)
        Set tSC6 = ##class(IRISCouch.Replication.Checkpoint).Write(pSourceDB, tRepId, tCheckpoint, 1)
        If $$$ISERR(tSC6) Set tSC = tSC6
        Set tSC7 = ##class(IRISCouch.Replication.Checkpoint).Write("", tRepId, tCheckpoint, 0, pTargetClient)
        If $$$ISERR(tSC7) && $$$ISOK(tSC) Set tSC = tSC7
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Pull replication: remote source to local target via HTTP.</p>
/// @param pSourceClient The HttpClient for the remote source
/// @param pTargetDB The local target database name
/// @param pOptions Optional replication options
/// @return %Status
ClassMethod ReplicateRemote(pSourceClient As IRISCouch.Replication.HttpClient, pTargetDB As %String, pOptions As %DynamicObject = "") As %Status
{
    Set tSC = $$$OK
    Try {
        ; Phase 1: Verify local target exists
        If '##class(IRISCouch.Storage.Database).Exists(pTargetDB) {
            If $IsObject(pOptions) && (pOptions.%Get("create_target") = 1) {
                Set tSC = ##class(IRISCouch.Storage.Database).Create(pTargetDB)
                If $$$ISERR(tSC) Quit
            } Else {
                Set tSC = $$$ERROR($$$GeneralError, "Target database does not exist: " _ pTargetDB)
                Quit
            }
        }
        ; Verify remote source (HEAD request)
        Set tSC2 = pSourceClient.Request("HEAD", "/", "", .tStatusCode, .tBody)
        If $$$ISERR(tSC2) || (tStatusCode '= 200) {
            Set tSC = $$$ERROR($$$GeneralError, "Remote source database not accessible")
            Quit
        }
        ; Phase 3: Compute replication ID
        Set tSourceUrl = pSourceClient.Server _ ":" _ pSourceClient.Port _ pSourceClient.BasePath
        Set tRepId = ##class(IRISCouch.Replication.ReplicationId).Compute(tSourceUrl, pTargetDB, pOptions)
        ; Phase 4: Find common ancestry
        Set tSessionId = ##class(IRISCouch.Util.UUID).Generate()
        Set tSourceCkpt = ##class(IRISCouch.Replication.Checkpoint).Read("", tRepId, 0, pSourceClient)
        Set tTargetCkpt = ##class(IRISCouch.Replication.Checkpoint).Read(pTargetDB, tRepId, 1)
        Set tSince = +##class(IRISCouch.Replication.Checkpoint).FindCommonAncestry(tSourceCkpt, tTargetCkpt)
        ; Phase 5: Get changes from remote source
        Set tSC3 = pSourceClient.Get("/_changes?since=" _ tSince, .tChangesStatus, .tChangesBody)
        If $$$ISERR(tSC3) || (tChangesStatus '= 200) {
            Set tSC = $$$ERROR($$$GeneralError, "Failed to get changes from remote source")
            Quit
        }
        Set tChangesObj = ##class(%DynamicObject).%FromJSON(tChangesBody)
        Set tResults = tChangesObj.%Get("results")
        Set tLastSeq = tChangesObj.%Get("last_seq")
        If tResults.%Size() = 0 Quit
        ; Phase 5b: Compute _revs_diff locally on target
        Set tRevsDiffReq = {}
        Set tI = 0
        While tI < tResults.%Size() {
            Set tChange = tResults.%Get(tI)
            Set tDocId = tChange.%Get("id")
            Set tChangeRevs = tChange.%Get("changes")
            Set tRevArray = []
            Set tJ = 0
            While tJ < tChangeRevs.%Size() {
                Do tRevArray.%Push(tChangeRevs.%Get(tJ).%Get("rev"))
                Set tJ = tJ + 1
            }
            Do tRevsDiffReq.%Set(tDocId, tRevArray)
            Set tI = tI + 1
        }
        Set tMissing = ..ComputeRevsDiffLocal(pTargetDB, tRevsDiffReq)
        ; Phase 6: Fetch missing docs from remote source via _bulk_get
        Set tBulkGetDocs = []
        Set tMissingIter = tMissing.%GetIterator()
        While tMissingIter.%GetNext(.tDocId, .tDocResult) {
            Set tMissingRevs = tDocResult.%Get("missing")
            If '$IsObject(tMissingRevs) Continue
            Set tK = 0
            While tK < tMissingRevs.%Size() {
                Set tBGDoc = {}
                Do tBGDoc.%Set("id", tDocId)
                Do tBGDoc.%Set("rev", tMissingRevs.%Get(tK))
                Do tBulkGetDocs.%Push(tBGDoc)
                Set tK = tK + 1
            }
        }
        If tBulkGetDocs.%Size() > 0 {
            Set tBulkGetReq = {}
            Do tBulkGetReq.%Set("docs", tBulkGetDocs)
            Set tSC4 = pSourceClient.Post("/_bulk_get?revs=true&attachments=true", tBulkGetReq.%ToJSON(), .tBGStatus, .tBGBody)
            If $$$ISERR(tSC4) || (tBGStatus '= 200) {
                Set tSC = $$$ERROR($$$GeneralError, "Failed to bulk_get from remote source")
                Quit
            }
            ; Parse response and write to local target
            Set tBGResp = ##class(%DynamicObject).%FromJSON(tBGBody)
            Set tBGResults = tBGResp.%Get("results")
            If $IsObject(tBGResults) {
                Set tBI = 0
                While tBI < tBGResults.%Size() {
                    Set tDocResult = tBGResults.%Get(tBI)
                    Set tDocs = tDocResult.%Get("docs")
                    If $IsObject(tDocs) {
                        Set tDI = 0
                        While tDI < tDocs.%Size() {
                            Set tDocEntry = tDocs.%Get(tDI)
                            Set tOk = tDocEntry.%Get("ok")
                            If $IsObject(tOk) {
                                Set tDocId = tOk.%Get("_id")
                                Set tRev = tOk.%Get("_rev")
                                Set tRevisions = tOk.%Get("_revisions")
                                Set tDeleted = +tOk.%Get("_deleted")
                                ; Strip metadata from body
                                Set tBodyObj = ##class(%DynamicObject).%FromJSON(tOk.%ToJSON())
                                If tBodyObj.%IsDefined("_id") Do tBodyObj.%Remove("_id")
                                If tBodyObj.%IsDefined("_rev") Do tBodyObj.%Remove("_rev")
                                If tBodyObj.%IsDefined("_revisions") Do tBodyObj.%Remove("_revisions")
                                If tBodyObj.%IsDefined("_deleted") Do tBodyObj.%Remove("_deleted")
                                If tBodyObj.%IsDefined("_attachments") Do tBodyObj.%Remove("_attachments")
                                ; Write to target via SaveWithHistory
                                Set tSC5 = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory(pTargetDB, tDocId, tBodyObj.%ToJSON(), tRev, tRevisions, tDeleted)
                                ; NFR-R1: Verify rev was stored correctly
                                If $$$ISOK(tSC5) && '##class(IRISCouch.Storage.RevTree).RevExists(pTargetDB, tDocId, tRev) {
                                    Set tSC = $$$ERROR($$$GeneralError, "NFR-R1: Rev-tree corruption detected for " _ tDocId _ " rev " _ tRev)
                                    Quit
                                }
                            }
                            If $$$ISERR(tSC) Quit
                            Set tDI = tDI + 1
                        }
                    }
                    If $$$ISERR(tSC) Quit
                    Set tBI = tBI + 1
                }
            }
        }
        If $$$ISERR(tSC) Quit
        ; Phase 9: Update checkpoints
        Set tHistoryEntry = {}
        Do tHistoryEntry.%Set("session_id", tSessionId)
        Do tHistoryEntry.%Set("start_last_seq", tSince, "number")
        Do tHistoryEntry.%Set("end_last_seq", tLastSeq, "number")
        Do tHistoryEntry.%Set("recorded_seq", tLastSeq, "number")
        Set tHistory = []
        Do tHistory.%Push(tHistoryEntry)
        Set tCheckpoint = ##class(IRISCouch.Replication.Checkpoint).BuildCheckpointDoc(tRepId, tSessionId, tLastSeq, tHistory)
        Set tSC6 = ##class(IRISCouch.Replication.Checkpoint).Write("", tRepId, tCheckpoint, 0, pSourceClient)
        If $$$ISERR(tSC6) Set tSC = tSC6
        Set tSC7 = ##class(IRISCouch.Replication.Checkpoint).Write(pTargetDB, tRepId, tCheckpoint, 1)
        If $$$ISERR(tSC7) && $$$ISOK(tSC) Set tSC = tSC7
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

}
