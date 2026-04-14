/// <p>Manager for the <code>_replicator</code> database and continuous replication jobs.</p>
/// <p>Intercepts document writes and deletes in the <code>_replicator</code> database
/// to manage replication job lifecycle. Implements CouchDB-compatible
/// <code>_replicator</code> document state machine:</p>
/// <ol>
/// <li>Document created with <code>source</code> + <code>target</code></li>
/// <li>System injects <code>_replication_id</code>, <code>owner</code>, <code>_replication_state</code></li>
/// <li>Background job spawned via IRIS <code>JOB</code> command</li>
/// <li>State transitions: triggered -> completed (one-shot) or triggered -> error (with backoff)</li>
/// <li>Document deletion stops the running job</li>
/// </ol>
/// <p>Called by <class>IRISCouch.Core.DocumentEngine</class> within the
/// document write transaction (Story 8.5).</p>
Class IRISCouch.Replication.Manager Extends %RegisteredObject
{

/// <p>Default polling interval in seconds for continuous replication.</p>
Parameter POLLINTERVAL = 5;

/// <p>Maximum backoff delay in seconds for error retries.</p>
Parameter MAXBACKOFF = 60;

/// <p>Check if a database name is the <code>_replicator</code> system database.</p>
/// @param pDB The database name
/// @return %Boolean 1 if pDB is "_replicator", 0 otherwise
ClassMethod IsReplicatorDB(pDB As %String) As %Boolean
{
    Quit (pDB = "_replicator")
}

/// <p>Handle a document save in the <code>_replicator</code> database.</p>
/// <p>Validates required fields, computes replication ID, injects system fields
/// (<code>_replication_id</code>, <code>owner</code>, <code>_replication_state</code>,
/// <code>_replication_state_time</code>, <code>_replication_stats</code>),
/// and starts the replication job in the background.</p>
/// @param pDB The database name (must be "_replicator")
/// @param pDocId The document identifier
/// @param pBody The document body as %DynamicObject
/// @return %DynamicObject The modified body with system fields injected, or "" on validation failure
ClassMethod OnReplicatorDocSave(pDB As %String, pDocId As %String, pBody As %DynamicObject) As %DynamicObject
{
    Set tResult = ""
    Try {
        ; Skip if this is a state-update write (prevent hook recursion)
        If $Get(%IRISCouchReplicatorUpdate) = 1 {
            Set tResult = pBody
            Quit
        }
        ; Skip design documents
        If $Extract(pDocId, 1, 8) = "_design/" {
            Set tResult = pBody
            Quit
        }
        ; Validate required fields: source and target must be present
        Set tSource = pBody.%Get("source")
        Set tTarget = pBody.%Get("target")
        If (tSource = "") || (tTarget = "") {
            ; Missing required fields; return body unchanged
            Set tResult = pBody
            Quit
        }
        ; Compute deterministic _replication_id
        Set tOptions = ..BuildOptionsFromBody(pBody)
        Set tRepId = ##class(IRISCouch.Replication.ReplicationId).Compute(tSource, tTarget, tOptions)
        ; Set system fields
        Do pBody.%Set("_replication_id", tRepId)
        Do pBody.%Set("owner", $Get(%IRISCouchUser, "_admin"))
        Do pBody.%Set("_replication_state", "triggered")
        ; ISO-8601 timestamp
        Set tNow = $Translate($ZDateTime($Horolog, 3, 1), " ", "T") _ "Z"
        Do pBody.%Set("_replication_state_time", tNow)
        ; Initialize stats to zeros
        Set tStats = {}
        Do tStats.%Set("docs_read", 0, "number")
        Do tStats.%Set("docs_written", 0, "number")
        Do tStats.%Set("doc_write_failures", 0, "number")
        Do tStats.%Set("missing_checked", 0, "number")
        Do tStats.%Set("missing_found", 0, "number")
        Do pBody.%Set("_replication_stats", tStats)
        ; NOTE: Job is NOT started here — DocumentEngine calls StartJobFromBody()
        ; after TCOMMIT to avoid spawning jobs inside uncommitted transactions.
        Set tResult = pBody
        Quit
    }
    Catch ex {
        Set tResult = pBody
        Quit
    }
    Quit tResult
}

/// <p>Start the background replication job for a _replicator document.</p>
/// <p>Called by <class>IRISCouch.Core.DocumentEngine</class> AFTER TCOMMIT
/// to ensure the document data is committed before the job reads it.
/// Extracts source, target, and options from the body and calls
/// <method>StartJob</method>.</p>
/// @param pDB The database name (must be "_replicator")
/// @param pDocId The replicator document ID
/// @param pBody The document body as %DynamicObject (with system fields already injected)
ClassMethod StartJobFromBody(pDB As %String, pDocId As %String, pBody As %DynamicObject)
{
    Try {
        ; Skip state-update writes (recursion prevention)
        If $Get(%IRISCouchReplicatorUpdate) = 1 Quit
        ; Skip design documents
        If $Extract(pDocId, 1, 8) = "_design/" Quit
        ; Validate required fields
        Set tSource = pBody.%Get("source")
        Set tTarget = pBody.%Get("target")
        If (tSource = "") || (tTarget = "") Quit
        ; Build options and start job
        Set tOptions = ..BuildOptionsFromBody(pBody)
        Set tContinuous = +pBody.%Get("continuous")
        Do ..StartJob(pDB, pDocId, tSource, tTarget, tOptions, tContinuous)
        Quit
    }
    Catch ex {
        ; Best-effort job start; log and continue
        Quit
    }
}

/// <p>Handle a document deletion in the <code>_replicator</code> database.</p>
/// <p>Stops any running replication job associated with this document
/// by reading the document body to extract the replication ID and
/// signaling cancellation.</p>
/// @param pDB The database name (must be "_replicator")
/// @param pDocId The document identifier
ClassMethod OnReplicatorDocDelete(pDB As %String, pDocId As %String)
{
    Try {
        ; Find the replication ID for this doc by reading from Winners projection
        Set tBody = ##class(IRISCouch.Projection.Winners).GetBody(pDB, pDocId)
        If tBody '= "" {
            Set tDoc = ##class(%DynamicObject).%FromJSON(tBody)
            Set tRepId = tDoc.%Get("_replication_id")
            If tRepId '= "" {
                Do ..StopJob(tRepId)
            }
        }
        Quit
    }
    Catch ex {
        ; Best-effort cancellation; log and continue
        Quit
    }
}

/// <p>Update a <code>_replicator</code> document with replication state and stats.</p>
/// <p>Reads the current document, updates <code>_replication_state</code>,
/// <code>_replication_state_time</code>, and <code>_replication_stats</code>,
/// then writes back via <method>DocumentEngine.Save</method> with the
/// <code>%IRISCouchReplicatorUpdate</code> flag set to prevent hook recursion.</p>
/// @param pDB The database name (must be "_replicator")
/// @param pDocId The document identifier
/// @param pState The new replication state ("triggered", "completed", "error")
/// @param pStats Optional %DynamicObject with replication statistics
ClassMethod UpdateReplicatorDoc(pDB As %String, pDocId As %String, pState As %String, pStats As %DynamicObject = "")
{
    Try {
        ; Get current winner revision for this doc
        Set tCurrentRev = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDocId)
        If tCurrentRev = "" Quit
        ; Read current body
        Set tBody = ##class(IRISCouch.Storage.Document).Read(pDB, pDocId, tCurrentRev)
        If tBody = "" Quit
        ; Parse and update fields
        Set tDoc = ##class(%DynamicObject).%FromJSON(tBody)
        Do tDoc.%Set("_replication_state", pState)
        Set tNow = $Translate($ZDateTime($Horolog, 3, 1), " ", "T") _ "Z"
        Do tDoc.%Set("_replication_state_time", tNow)
        If $IsObject(pStats) {
            Do tDoc.%Set("_replication_stats", pStats)
        }
        ; Set recursion-prevention flag
        Set %IRISCouchReplicatorUpdate = 1
        ; Write back via DocumentEngine.Save to maintain change feed
        Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).Save(pDB, pDocId, tDoc.%ToJSON(), tCurrentRev)
        ; Clear flag
        Set %IRISCouchReplicatorUpdate = 0
        Quit
    }
    Catch ex {
        Set %IRISCouchReplicatorUpdate = 0
        Quit
    }
}

/// <p>Start a background replication job using the IRIS JOB command.</p>
/// <p>Spawns a new IRIS process running <method>RunReplication</method>.
/// Stores the job PID in <code>^IRISCouch.Jobs(replicationId)</code>
/// for later cancellation.</p>
/// @param pDB The _replicator database name
/// @param pDocId The replicator document ID
/// @param pSource The source database name or URL
/// @param pTarget The target database name or URL
/// @param pOptions Replication options as %DynamicObject
/// @param pContinuous Whether this is continuous (1) or one-shot (0)
/// @return %String The job PID or "" on failure
ClassMethod StartJob(pDB As %String, pDocId As %String, pSource As %String, pTarget As %String, pOptions As %DynamicObject = "", pContinuous As %Boolean = 0) As %String
{
    Set tPID = ""
    Try {
        ; Compute replication ID for job tracking
        Set tRepId = ##class(IRISCouch.Replication.ReplicationId).Compute(pSource, pTarget, pOptions)
        ; Clear any stale cancellation flag
        Kill ^IRISCouch.Jobs(tRepId, "cancel")
        ; Build options JSON string for JOB parameter passing
        Set tOptionsJSON = ""
        If $IsObject(pOptions) {
            Set tOptionsJSON = pOptions.%ToJSON()
        }
        ; Spawn background process with 5-second timeout
        JOB ##class(IRISCouch.Replication.Manager).RunReplication(pDB, pDocId, pSource, pTarget, tOptionsJSON, pContinuous)::5
        ; $ZChild contains the PID of the last JOB command
        Set tPID = $ZChild
        ; Store job PID for cancellation
        Set ^IRISCouch.Jobs(tRepId) = tPID
        Set ^IRISCouch.Jobs(tRepId, "docId") = pDocId
        Set ^IRISCouch.Jobs(tRepId, "db") = pDB
        Quit
    }
    Catch ex {
        ; JOB command failed — update doc state to error
        Quit
    }
    Quit tPID
}

/// <p>Entry point for the background replication job.</p>
/// <p>Called by the IRIS JOB command. Runs the replication and updates
/// the <code>_replicator</code> document with progress and final state.
/// For continuous mode, loops with polling interval and checks for
/// cancellation between iterations.</p>
/// @param pDB The _replicator database name
/// @param pDocId The replicator document ID
/// @param pSource The source database name or URL
/// @param pTarget The target database name or URL
/// @param pOptionsJSON Replication options as JSON string
/// @param pContinuous Whether this is continuous (1) or one-shot (0)
ClassMethod RunReplication(pDB As %String, pDocId As %String, pSource As %String, pTarget As %String, pOptionsJSON As %String = "", pContinuous As %Boolean = 0)
{
    Try {
        ; Parse options
        Set tOptions = ""
        If pOptionsJSON '= "" {
            Set tOptions = ##class(%DynamicObject).%FromJSON(pOptionsJSON)
        }
        ; Compute replication ID for cancellation checks
        Set tRepId = ##class(IRISCouch.Replication.ReplicationId).Compute(pSource, pTarget, tOptions)
        Set tAttempt = 0
        ; Audit replication start (Story 9.2)
        Do ##class(IRISCouch.Audit.Emit).ReplicationStart(pSource, pTarget, $Get(%IRISCouchUser))
        ; Structured log — replication started (Story 9.3)
        Set tStartLog = {"source":(pSource),"target":(pTarget),"continuous":(pContinuous)}
        Do ##class(IRISCouch.Util.Log).Info("replication", "Replication started", tStartLog)
        ; Main replication loop
        For {
            ; Check cancellation before each iteration
            If $Get(^IRISCouch.Jobs(tRepId, "cancel")) = 1 {
                ; Clean up and exit
                Kill ^IRISCouch.Jobs(tRepId)
                Quit
            }
            Set tAttempt = tAttempt + 1
            ; Run replication
            Set tSC = ##class(IRISCouch.Replication.Replicator).Replicate(pSource, pTarget, tOptions, .tStats)
            If $$$ISOK(tSC) {
                ; Build stats object for doc update
                Set tStatsObj = ..BuildStatsObject(tStats)
                If 'pContinuous {
                    ; One-shot: mark completed and exit
                    Do ..UpdateReplicatorDoc(pDB, pDocId, "completed", tStatsObj)
                    ; Audit replication complete (Story 9.2)
                    Do ##class(IRISCouch.Audit.Emit).ReplicationComplete(pSource, pTarget, tStatsObj, $Get(%IRISCouchUser))
                    ; Structured log — replication completed (Story 9.3)
                    Set tCompleteLog = {"source":(pSource),"target":(pTarget),"stats":(tStatsObj)}
                    Do ##class(IRISCouch.Util.Log).Info("replication", "Replication completed", tCompleteLog)
                    ; Clean up job tracking
                    Kill ^IRISCouch.Jobs(tRepId)
                    Quit
                }
                ; Continuous: update with latest stats, reset attempt counter
                Do ..UpdateReplicatorDoc(pDB, pDocId, "triggered", tStatsObj)
                Set tAttempt = 0
                ; Sleep for polling interval, checking cancellation periodically
                Do ..SleepWithCancel(tRepId, ..#POLLINTERVAL)
                ; Check cancellation after sleep
                If $Get(^IRISCouch.Jobs(tRepId, "cancel")) = 1 {
                    Kill ^IRISCouch.Jobs(tRepId)
                    Quit
                }
            } Else {
                ; Error: update state and compute backoff
                Set tErrStats = ..BuildStatsObject(tStats)
                Set tErrMsg = $System.Status.GetErrorText(tSC)
                If $IsObject(tErrStats) {
                    Do tErrStats.%Set("error", tErrMsg)
                } Else {
                    Set tErrStats = {}
                    Do tErrStats.%Set("error", tErrMsg)
                }
                Do ..UpdateReplicatorDoc(pDB, pDocId, "error", tErrStats)
                ; Structured log — replication error (Story 9.3)
                Set tErrLog = {"source":(pSource),"target":(pTarget),"error":(tErrMsg)}
                Do ##class(IRISCouch.Util.Log).Error("replication", "Replication error", tErrLog)
                If 'pContinuous {
                    ; One-shot error: clean up and exit
                    Kill ^IRISCouch.Jobs(tRepId)
                    Quit
                }
                ; Continuous: exponential backoff then retry
                Set tBackoff = ..ComputeBackoff(tAttempt)
                Do ..SleepWithCancel(tRepId, tBackoff)
                ; Check cancellation after backoff sleep
                If $Get(^IRISCouch.Jobs(tRepId, "cancel")) = 1 {
                    Kill ^IRISCouch.Jobs(tRepId)
                    Quit
                }
            }
        }
        Quit
    }
    Catch ex {
        ; Final error handler — attempt to mark doc as error
        Try {
            Set tErrStats = {}
            Do tErrStats.%Set("error", ex.DisplayString())
            Do ..UpdateReplicatorDoc(pDB, pDocId, "error", tErrStats)
        } Catch ex2 {
            ; Cannot update doc; just exit
        }
        Quit
    }
}

/// <p>Stop a running replication job by signaling cancellation.</p>
/// <p>Sets the cancellation flag in <code>^IRISCouch.Jobs(pReplicationId, "cancel")</code>.
/// The running job checks this flag periodically and exits gracefully.</p>
/// @param pReplicationId The replication ID to cancel
ClassMethod StopJob(pReplicationId As %String)
{
    Set ^IRISCouch.Jobs(pReplicationId, "cancel") = 1
}

/// <p>Compute exponential backoff delay for error retries.</p>
/// <p>Formula: min(2^(attempt-1), MAXBACKOFF) seconds.</p>
/// @param pAttempt The current attempt number (1-based)
/// @return %Integer The delay in seconds
ClassMethod ComputeBackoff(pAttempt As %Integer) As %Integer
{
    ; 2^(attempt-1): 1, 2, 4, 8, 16, 32, 60 max
    Set tExponent = pAttempt - 1
    If tExponent < 0 Set tExponent = 0
    Set tDelay = 1
    For tI = 1:1:tExponent {
        Set tDelay = tDelay * 2
    }
    If tDelay > ..#MAXBACKOFF Set tDelay = ..#MAXBACKOFF
    Quit tDelay
}

/// <p>Sleep for a specified duration while checking for cancellation.</p>
/// <p>Breaks the sleep into 1-second intervals, checking the cancellation
/// flag between each interval for responsive shutdown.</p>
/// @param pReplicationId The replication ID to check for cancellation
/// @param pSeconds The total number of seconds to sleep
ClassMethod SleepWithCancel(pReplicationId As %String, pSeconds As %Integer)
{
    For tI = 1:1:pSeconds {
        If $Get(^IRISCouch.Jobs(pReplicationId, "cancel")) = 1 Quit
        Hang 1
    }
}

/// <p>Build a replication options %DynamicObject from a _replicator document body.</p>
/// <p>Extracts replication-relevant fields (continuous, create_target, filter,
/// doc_ids, selector) from the document body for use with
/// <method>ReplicationId.Compute</method>.</p>
/// @param pBody The _replicator document body as %DynamicObject
/// @return %DynamicObject The options object
ClassMethod BuildOptionsFromBody(pBody As %DynamicObject) As %DynamicObject
{
    Set tOptions = {}
    If pBody.%IsDefined("continuous") {
        Do tOptions.%Set("continuous", pBody.%Get("continuous"))
    }
    If pBody.%IsDefined("create_target") {
        Do tOptions.%Set("create_target", pBody.%Get("create_target"))
    }
    If pBody.%IsDefined("filter") {
        Do tOptions.%Set("filter", pBody.%Get("filter"))
    }
    If pBody.%IsDefined("doc_ids") {
        Do tOptions.%Set("doc_ids", pBody.%Get("doc_ids"))
    }
    If pBody.%IsDefined("selector") {
        Do tOptions.%Set("selector", pBody.%Get("selector"))
    }
    Quit tOptions
}

/// <p>Build a stats %DynamicObject from an Output stats parameter.</p>
/// <p>Converts the Output pStats from <method>Replicator.Replicate</method>
/// into a %DynamicObject suitable for storage in the _replicator document.</p>
/// @param pStats The stats output from Replicate (may be %DynamicObject or "")
/// @return %DynamicObject The stats object with all counter fields
ClassMethod BuildStatsObject(pStats) As %DynamicObject
{
    Set tResult = {}
    If $IsObject(pStats) {
        Do tResult.%Set("docs_read", +pStats.%Get("docs_read"), "number")
        Do tResult.%Set("docs_written", +pStats.%Get("docs_written"), "number")
        Do tResult.%Set("doc_write_failures", +pStats.%Get("doc_write_failures"), "number")
        Do tResult.%Set("missing_checked", +pStats.%Get("missing_checked"), "number")
        Do tResult.%Set("missing_found", +pStats.%Get("missing_found"), "number")
    } Else {
        Do tResult.%Set("docs_read", 0, "number")
        Do tResult.%Set("docs_written", 0, "number")
        Do tResult.%Set("doc_write_failures", 0, "number")
        Do tResult.%Set("missing_checked", 0, "number")
        Do tResult.%Set("missing_found", 0, "number")
    }
    Quit tResult
}

}
