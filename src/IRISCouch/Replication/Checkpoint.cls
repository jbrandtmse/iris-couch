/// <p>Replication checkpoint management for the CouchDB replication protocol.</p>
/// <p>Handles reading, writing, and comparing checkpoint documents stored as
/// local documents (<code>_local/{replication_id}</code>) on both source and
/// target databases. Checkpoints enable resumable replication (AC #4).</p>
Class IRISCouch.Replication.Checkpoint Extends %RegisteredObject
{

/// <p>Read a checkpoint document from a database.</p>
/// <p>For local databases, reads via <class>IRISCouch.Storage.Local</class>.
/// For remote databases, performs GET {url}/_local/{repId} via HttpClient.</p>
/// @param pDB The database name or URL
/// @param pRepId The replication ID (used as local doc ID)
/// @param pIsLocal Whether the database is local (1) or remote (0)
/// @param pHttpClient Optional HttpClient for remote access
/// @return %DynamicObject The checkpoint document, or "" if not found
ClassMethod Read(pDB As %String, pRepId As %String, pIsLocal As %Boolean, pHttpClient As IRISCouch.Replication.HttpClient = "") As %DynamicObject
{
    Set tResult = ""
    Try {
        If pIsLocal {
            ; Read from local storage
            Set tBody = ##class(IRISCouch.Storage.Local).Read(pDB, pRepId)
            If tBody = "" {
                Quit
            }
            Set tResult = ##class(%DynamicObject).%FromJSON(tBody)
            ; Add _rev from storage
            Set tRev = ##class(IRISCouch.Storage.Local).GetRev(pDB, pRepId)
            If tRev '= "" {
                Do tResult.%Set("_rev", tRev)
            }
            Quit
        }
        ; Remote: GET via HttpClient
        If '$IsObject(pHttpClient) {
            Quit
        }
        Set tSC = pHttpClient.Get("/_local/" _ pRepId, .tStatusCode, .tRespBody)
        If $$$ISERR(tSC) Quit
        If tStatusCode '= 200 Quit
        If tRespBody '= "" {
            Set tResult = ##class(%DynamicObject).%FromJSON(tRespBody)
        }
        Quit
    }
    Catch ex {
        Set tResult = ""
        Quit
    }
    Quit tResult
}

/// <p>Write a checkpoint document to a database.</p>
/// <p>For local databases, serializes to JSON and writes via
/// <class>IRISCouch.Storage.Local</class>. For remote databases,
/// PUTs to {url}/_local/{repId} via HttpClient.</p>
/// @param pDB The database name or URL
/// @param pRepId The replication ID (used as local doc ID)
/// @param pCheckpoint The checkpoint document to write
/// @param pIsLocal Whether the database is local (1) or remote (0)
/// @param pHttpClient Optional HttpClient for remote access
/// @return %Status
ClassMethod Write(pDB As %String, pRepId As %String, pCheckpoint As %DynamicObject, pIsLocal As %Boolean, pHttpClient As IRISCouch.Replication.HttpClient = "") As %Status
{
    Set tSC = $$$OK
    Try {
        If pIsLocal {
            ; Get current rev for proper update
            Set tCurrentRev = ##class(IRISCouch.Storage.Local).GetRev(pDB, pRepId)
            Set tNextRev = ##class(IRISCouch.Storage.Local).NextRev(tCurrentRev)
            ; Remove _id and _rev before storing body
            Set tBody = ##class(%DynamicObject).%FromJSON(pCheckpoint.%ToJSON())
            If tBody.%IsDefined("_id") Do tBody.%Remove("_id")
            If tBody.%IsDefined("_rev") Do tBody.%Remove("_rev")
            Set tSC = ##class(IRISCouch.Storage.Local).Write(pDB, pRepId, tBody.%ToJSON(), tNextRev)
            Quit
        }
        ; Remote: PUT via HttpClient
        If '$IsObject(pHttpClient) {
            Set tSC = $$$ERROR($$$GeneralError, "HttpClient required for remote checkpoint write")
            Quit
        }
        Set tSC = pHttpClient.Put("/_local/" _ pRepId, pCheckpoint.%ToJSON(), .tStatusCode, .tRespBody)
        If $$$ISERR(tSC) Quit
        If (tStatusCode '= 200) && (tStatusCode '= 201) {
            Set tSC = $$$ERROR($$$GeneralError, "Checkpoint write failed with HTTP " _ tStatusCode)
            Quit
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Find common ancestry between source and target checkpoint documents.</p>
/// <p>Compares <code>session_id</code> fields. If they match, returns
/// <code>source_last_seq</code>. Otherwise iterates <code>history[]</code>
/// arrays to find a common <code>session_id</code> and returns the
/// <code>recorded_seq</code> from the matching history entry.</p>
/// <p>Returns "0" if no common ancestry is found (triggering full replication).</p>
/// @param pSourceCkpt The source checkpoint document (or "")
/// @param pTargetCkpt The target checkpoint document (or "")
/// @return %String The sequence to resume from, or "0" for full replication
ClassMethod FindCommonAncestry(pSourceCkpt As %DynamicObject, pTargetCkpt As %DynamicObject) As %String
{
    Set tResult = "0"
    Try {
        ; If either checkpoint is missing, full replication
        If '$IsObject(pSourceCkpt) Quit
        If '$IsObject(pTargetCkpt) Quit
        ; Compare top-level session_id
        Set tSourceSessionId = pSourceCkpt.%Get("session_id")
        Set tTargetSessionId = pTargetCkpt.%Get("session_id")
        If (tSourceSessionId '= "") && (tSourceSessionId = tTargetSessionId) {
            Set tSeq = pSourceCkpt.%Get("source_last_seq")
            If tSeq '= "" {
                Set tResult = tSeq
                Quit
            }
        }
        ; Search through history arrays for common session_id
        Set tSourceHistory = pSourceCkpt.%Get("history")
        Set tTargetHistory = pTargetCkpt.%Get("history")
        If '$IsObject(tSourceHistory) Quit
        If '$IsObject(tTargetHistory) Quit
        ; Build a set of target session_ids for quick lookup
        Set tTI = 0
        While tTI < tTargetHistory.%Size() {
            Set tEntry = tTargetHistory.%Get(tTI)
            If $IsObject(tEntry) {
                Set tSid = tEntry.%Get("session_id")
                If tSid '= "" {
                    Set tTargetSessions(tSid) = tEntry.%Get("recorded_seq")
                }
            }
            Set tTI = tTI + 1
        }
        ; Find first source history entry with matching target session
        Set tFound = 0
        Set tSI = 0
        While tSI < tSourceHistory.%Size() {
            Set tEntry = tSourceHistory.%Get(tSI)
            If $IsObject(tEntry) {
                Set tSid = tEntry.%Get("session_id")
                If (tSid '= "") && $Data(tTargetSessions(tSid)) {
                    Set tRecSeq = tEntry.%Get("recorded_seq")
                    If tRecSeq '= "" {
                        Set tResult = tRecSeq
                        Set tFound = 1
                    }
                }
            }
            If tFound Quit
            Set tSI = tSI + 1
        }
        Quit
    }
    Catch ex {
        Set tResult = "0"
        Quit
    }
    Quit tResult
}

/// <p>Build a checkpoint document with the standard CouchDB format.</p>
/// <p>Creates a <class>%DynamicObject</class> with <code>replication_id_version</code>,
/// <code>session_id</code>, <code>source_last_seq</code>, and <code>history[]</code>.</p>
/// @param pRepId The replication ID
/// @param pSessionId The current session UUID
/// @param pSourceLastSeq The last source sequence processed
/// @param pHistory The history array of previous sessions
/// @return %DynamicObject The checkpoint document
ClassMethod BuildCheckpointDoc(pRepId As %String, pSessionId As %String, pSourceLastSeq, pHistory As %DynamicArray) As %DynamicObject
{
    Set tDoc = {}
    Do tDoc.%Set("_id", "_local/" _ pRepId)
    Do tDoc.%Set("replication_id_version", 3, "number")
    Do tDoc.%Set("session_id", pSessionId)
    ; Story 13.4 Task 8c: serialize source_last_seq as a string per CouchDB 2.x+
    ; convention. The changes-feed `last_seq` is already a string in this codebase;
    ; checkpoint docs were inconsistent with that.
    Do tDoc.%Set("source_last_seq", ""_pSourceLastSeq)
    If '$IsObject(pHistory) {
        Set pHistory = []
    }
    Do tDoc.%Set("history", pHistory)
    Quit tDoc
}

}
