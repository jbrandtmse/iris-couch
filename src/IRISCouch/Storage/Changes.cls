/// <p>Storage layer for IRISCouch changes feed operations.</p>
/// <p>Provides encapsulated access to <code>^IRISCouch.Changes</code> and
/// <code>^IRISCouch.Seq</code> globals for querying change sequence data.</p>
Class IRISCouch.Storage.Changes Extends %RegisteredObject
{

/// <p>Get the latest sequence number for a specific document.</p>
/// <p>Scans <code>^IRISCouch.Changes(pDB)</code> backwards via <code>$Order(..., -1)</code>
/// to find the most recent seq entry matching <code>pDocId</code>.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %String The sequence number as string, or "" if not found
ClassMethod GetDocSeq(pDB As %String, pDocId As %String) As %String
{
    Set tLocalSeq = ""
    Set tSeq = ""
    For {
        Set tSeq = $Order(^IRISCouch.Changes(pDB, tSeq), -1)
        Quit:tSeq=""
        Set tEntry = ^IRISCouch.Changes(pDB, tSeq)
        If $ListGet(tEntry, 1) = pDocId {
            Set tLocalSeq = tSeq
            Quit
        }
    }
    Quit tLocalSeq
}

/// <p>Get the last (highest) sequence number for a database.</p>
/// <p>Returns <code>+$Get(^IRISCouch.Seq(pDB))</code>. Returns 0 if no changes exist.</p>
/// @param pDB The database name
/// @return %Integer The last sequence number, or 0 if none
ClassMethod GetLastSeq(pDB As %String) As %Integer
{
    Quit +$Get(^IRISCouch.Seq(pDB))
}

/// <p>Read a single change entry by sequence number.</p>
/// <p>Returns the raw <code>$ListBuild(docId, rev)</code> value stored at
/// <code>^IRISCouch.Changes(pDB, pSeq)</code>. Returns "" if entry does not exist.</p>
/// @param pDB The database name
/// @param pSeq The sequence number
/// @return %List The entry as $ListBuild(docId, rev), or "" if not found
ClassMethod ReadEntry(pDB As %String, pSeq As %Integer) As %List
{
    Quit $Get(^IRISCouch.Changes(pDB, pSeq))
}

/// <p>List changes for a database with pagination support.</p>
/// <p>Iterates <code>^IRISCouch.Changes(pDB)</code> starting after <code>pSince</code>,
/// returns a <class>%DynamicObject</class> with <code>results</code>, <code>lastSeq</code>,
/// and <code>pending</code>.</p>
/// @param pDB The database name
/// @param pSince Return changes after this sequence number (default 0)
/// @param pLimit Maximum number of entries to return (0 = unlimited)
/// @param pDescending If true, iterate in reverse order
/// @return %DynamicObject {"results":[...],"lastSeq":N,"pending":N}
ClassMethod ListChanges(pDB As %String, pSince As %Integer = 0, pLimit As %Integer = 0, pDescending As %Boolean = 0) As %DynamicObject
{
    Set tResults = []
    Set tCount = 0
    Set tLastSeq = pSince
    If pDescending {
        ; Descending: iterate from highest seq down, stopping at pSince
        Set tGlobalLastSeq = ..GetLastSeq(pDB)
        Set tSeq = ""
        For {
            Set tSeq = $Order(^IRISCouch.Changes(pDB, tSeq), -1)
            Quit:tSeq=""
            ; Stop when we reach pSince (lower bound)
            Quit:(tSeq<=pSince)
            ; Apply limit
            If (pLimit > 0) && (tCount >= pLimit) {
                Quit
            }
            Set tEntry = ^IRISCouch.Changes(pDB, tSeq)
            Set tDocId = $ListGet(tEntry, 1)
            Set tRev = $ListGet(tEntry, 2)
            Set tChange = {}
            Do tChange.%Set("seq", tSeq, "number")
            Do tChange.%Set("id", tDocId)
            Set tChangesArr = []
            Set tRevObj = {}
            Do tRevObj.%Set("rev", tRev)
            Do tChangesArr.%Push(tRevObj)
            Do tChange.%Set("changes", tChangesArr)
            Do tResults.%Push(tChange)
            Set tCount = tCount + 1
            Set tLastSeq = tSeq
        }
    } Else {
        ; Ascending: iterate forward from pSince
        Set tSeq = pSince
        For {
            Set tSeq = $Order(^IRISCouch.Changes(pDB, tSeq))
            Quit:tSeq=""
            ; Apply limit
            If (pLimit > 0) && (tCount >= pLimit) {
                Quit
            }
            Set tEntry = ^IRISCouch.Changes(pDB, tSeq)
            Set tDocId = $ListGet(tEntry, 1)
            Set tRev = $ListGet(tEntry, 2)
            Set tChange = {}
            Do tChange.%Set("seq", tSeq, "number")
            Do tChange.%Set("id", tDocId)
            Set tChangesArr = []
            Set tRevObj = {}
            Do tRevObj.%Set("rev", tRev)
            Do tChangesArr.%Push(tRevObj)
            Do tChange.%Set("changes", tChangesArr)
            Do tResults.%Push(tChange)
            Set tCount = tCount + 1
            Set tLastSeq = tSeq
        }
    }
    ; Compute pending: changes remaining that were not returned
    If pDescending {
        ; For descending, pending = total entries above pSince minus what we returned
        Set tTotal = ..CountSince(pDB, pSince)
        Set tPending = tTotal - tCount
    } Else {
        ; For ascending, pending = entries after the last returned seq
        Set tPending = ..CountSince(pDB, tLastSeq)
    }
    Set tResp = {}
    Do tResp.%Set("results", tResults)
    Do tResp.%Set("lastSeq", tLastSeq, "number")
    Do tResp.%Set("pending", tPending, "number")
    Quit tResp
}

/// <p>Get the system event resource name for longpoll signaling on a database.</p>
/// <p>Returns the canonical event name string used with <code>$System.Event</code>
/// for longpoll change notifications.</p>
/// @param pDB The database name
/// @return %String The event resource name
ClassMethod EventResourceName(pDB As %String) As %String
{
    Quit "^IRISCouch.LPChanges(""" _ pDB _ """)"
}

/// <p>Record a change entry for a document and return the new sequence number.</p>
/// <p>Atomically increments <code>^IRISCouch.Seq(pDB)</code> and writes the change
/// entry to <code>^IRISCouch.Changes(pDB, seq)</code> as <code>$ListBuild(pDocId, pRev)</code>.</p>
/// <p><b>Transaction requirement:</b> This method performs two operations
/// (<code>$Increment</code> + <code>Set</code>) that are not independently atomic.
/// Callers MUST wrap this call within a <code>TSTART</code>/<code>TCOMMIT</code>
/// transaction to ensure both operations commit together. All current callers
/// (DocumentEngine.Save, SaveDeleted, SaveWithHistory, etc.) satisfy this requirement.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision string
/// @return %Integer The new sequence number
ClassMethod RecordChange(pDB As %String, pDocId As %String, pRev As %String) As %Integer
{
    Set tSeq = $Increment(^IRISCouch.Seq(pDB))
    Set ^IRISCouch.Changes(pDB, tSeq) = $ListBuild(pDocId, pRev)
    Quit tSeq
}

/// <p>Count change entries after a given sequence number.</p>
/// <p>Counts entries in <code>^IRISCouch.Changes(pDB)</code> with seq greater than
/// <code>pSince</code>. Used for computing the <code>pending</code> field.</p>
/// @param pDB The database name
/// @param pSince Count entries after this sequence number (default 0)
/// @return %Integer The count of entries with seq > pSince
ClassMethod CountSince(pDB As %String, pSince As %Integer = 0) As %Integer
{
    Set tCount = 0
    Set tSeq = pSince
    For {
        Set tSeq = $Order(^IRISCouch.Changes(pDB, tSeq))
        Quit:tSeq=""
        Set tCount = tCount + 1
    }
    Quit tCount
}

}
