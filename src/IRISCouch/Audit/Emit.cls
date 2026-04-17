/// <p>Single point of audit event emission for IRISCouch (Story 9.2).</p>
/// <p>All audit events MUST go through this class. Never call
/// <code>$System.Security.Audit()</code> directly from handlers or
/// storage classes (Architecture Pattern 6).</p>
/// <p>Audit failures are silently absorbed -- they must never propagate
/// to or fail the calling transaction (NFR-O6).</p>
Class IRISCouch.Audit.Emit Extends %RegisteredObject
{

/// <p>Emit an audit event to the IRIS <code>%SYS.Audit</code> log.</p>
/// <p>Builds a JSON EventData string and a human-readable Description,
/// then calls <code>$System.Security.Audit("IRISCouch", ...)</code>.
/// Wrapped in Try/Catch so audit failure never propagates.</p>
/// @param pEventType The event type (DocWrite, DocDelete, AuthSuccess, etc.)
/// @param pDB The database name (may be empty for non-DB events)
/// @param pDocId The document identifier (optional)
/// @param pRev The document revision (optional)
/// @param pUser The user identity (defaults to %IRISCouchUser or $Username)
/// @param pExtra Optional %DynamicObject with additional event data fields
ClassMethod Emit(pEventType As %String, pDB As %String = "", pDocId As %String = "", pRev As %String = "", pUser As %String = "", pExtra As %DynamicObject = "") As %Status
{
    Set tSC = $$$OK
    Try {
        ; Default user from process-private variable or IRIS session
        If pUser = "" {
            Set pUser = $Get(%IRISCouchUser, $Username)
        }
        ; Build EventData JSON
        Set tEventData = {}
        Set tEventData.db = pDB
        Set tEventData.docId = pDocId
        Set tEventData.rev = pRev
        Set tEventData.user = pUser
        ; Merge extra fields if provided
        If $IsObject(pExtra) {
            Set tIter = pExtra.%GetIterator()
            While tIter.%GetNext(.tKey, .tVal) {
                Do tEventData.%Set(tKey, tVal)
            }
        }
        Set tEventDataStr = tEventData.%ToJSON()
        ; Build Description (max 128 chars per IRIS docs)
        Set tDescription = pEventType _ ": " _ pDB
        If pDocId '= "" {
            Set tDescription = tDescription _ "/" _ pDocId
        }
        ; Truncate description to 128 chars
        If $Length(tDescription) > 128 {
            Set tDescription = $Extract(tDescription, 1, 128)
        }
        ; Emit to IRIS audit subsystem
        ; Name parameter must match registered Security.Events name (= pEventType)
        ; The document ID is captured in EventData JSON, not the Name field
        Set tSC = $System.Security.Audit("IRISCouch", pEventType, pEventType, tEventDataStr, tDescription)
        Quit
    }
    Catch ex {
        ; Audit failure must NEVER propagate — silently absorb
        Quit
    }
    Quit tSC
}

/// <p>Register all IRISCouch audit event types in <code>Security.Events</code>.</p>
/// <p>Must be called once during installation or setup. Creates events in
/// <code>%SYS</code> namespace. Safe to call repeatedly — skips events that
/// already exist. Each event is created with <code>Enabled=1</code>.</p>
/// @return %Status
ClassMethod EnsureEvents() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $Namespace
    Try {
        Set $Namespace = "%SYS"
        Set tTypes = "DocWrite,DocDelete,AuthSuccess,AuthFailure,SecurityChange,UserWrite,ReplicationStart,ReplicationComplete,ViewAttempt,ViewExecute,ViewError"
        For tI = 1:1:$Length(tTypes, ",") {
            Set tType = $Piece(tTypes, ",", tI)
            If '##class(Security.Events).Exists("IRISCouch", tType, tType) {
                Set tSC = ##class(Security.Events).Create("IRISCouch", tType, tType, tType _ " audit event")
                If $$$ISERR(tSC) {
                    Set $Namespace = tOrigNS
                    Quit
                }
            }
        }
        Set $Namespace = tOrigNS
        Quit
    }
    Catch ex {
        Set $Namespace = tOrigNS
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Emit a DocWrite audit event for document create/update.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The new revision string
/// @param pUser The user identity (optional)
ClassMethod DocWrite(pDB As %String, pDocId As %String, pRev As %String = "", pUser As %String = "")
{
    Do ..Emit("DocWrite", pDB, pDocId, pRev, pUser)
}

/// <p>Emit a DocDelete audit event for document deletion.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The tombstone revision string
/// @param pUser The user identity (optional)
ClassMethod DocDelete(pDB As %String, pDocId As %String, pRev As %String = "", pUser As %String = "")
{
    Do ..Emit("DocDelete", pDB, pDocId, pRev, pUser)
}

/// <p>Emit an AuthSuccess audit event for successful authentication.</p>
/// @param pUser The authenticated user name
/// @param pMethod The authentication method (cookie, basic, jwt, proxy)
ClassMethod AuthSuccess(pUser As %String, pMethod As %String = "")
{
    Set tExtra = {}
    Set tExtra.method = pMethod
    Do ..Emit("AuthSuccess", "", "", "", pUser, tExtra)
}

/// <p>Emit an AuthFailure audit event for failed authentication.</p>
/// @param pUser The attempted user name
/// @param pMethod The authentication method (cookie, basic)
/// @param pReason The failure reason
ClassMethod AuthFailure(pUser As %String, pMethod As %String = "", pReason As %String = "")
{
    Set tExtra = {}
    Set tExtra.method = pMethod
    Set tExtra.reason = pReason
    Do ..Emit("AuthFailure", "", "", "", pUser, tExtra)
}

/// <p>Emit a SecurityChange audit event for _security configuration changes.</p>
/// @param pDB The database name
/// @param pUser The user who made the change (optional)
ClassMethod SecurityChange(pDB As %String, pUser As %String = "")
{
    Do ..Emit("SecurityChange", pDB, "", "", pUser)
}

/// <p>Emit a UserWrite audit event for _users database writes.</p>
/// @param pDB The database name (should be _users)
/// @param pDocId The user document identifier
/// @param pUser The user who made the change (optional)
ClassMethod UserWrite(pDB As %String, pDocId As %String, pUser As %String = "")
{
    Do ..Emit("UserWrite", pDB, pDocId, "", pUser)
}

/// <p>Emit a ReplicationStart audit event when replication begins.</p>
/// @param pSource The source database name or URL
/// @param pTarget The target database name or URL
/// @param pUser The user who initiated replication (optional)
ClassMethod ReplicationStart(pSource As %String, pTarget As %String, pUser As %String = "")
{
    Set tExtra = {}
    Set tExtra.source = pSource
    Set tExtra.target = pTarget
    Do ..Emit("ReplicationStart", "", "", "", pUser, tExtra)
}

/// <p>Emit a ReplicationComplete audit event when replication finishes.</p>
/// @param pSource The source database name or URL
/// @param pTarget The target database name or URL
/// @param pStats Replication statistics as %DynamicObject (optional)
/// @param pUser The user who initiated replication (optional)
ClassMethod ReplicationComplete(pSource As %String, pTarget As %String, pStats As %DynamicObject = "", pUser As %String = "")
{
    Set tExtra = {}
    Set tExtra.source = pSource
    Set tExtra.target = pTarget
    If $IsObject(pStats) {
        Set tExtra.stats = pStats
    }
    Do ..Emit("ReplicationComplete", "", "", "", pUser, tExtra)
}

/// <p>Emit a ViewAttempt audit event when a client requests a design-doc
/// view (Story 12.1). Fires on every call regardless of whether the
/// JSRuntime can actually execute the view, so operators can see attempts
/// even while <code>JSRUNTIME=None</code> is returning 501.</p>
/// @param pDB The database name
/// @param pDDocId The design document identifier (e.g., <code>_design/by_user</code>)
/// @param pViewName The view name
/// @param pStatus HTTP status code emitted (501 under Story 12.1 None backend;
///                200 once Story 12.2 / 12.4 land)
/// @param pUser The user who made the request (optional)
ClassMethod ViewAttempt(pDB As %String, pDDocId As %String, pViewName As %String, pStatus As %Integer = 0, pUser As %String = "")
{
    Set tExtra = {}
    Set tExtra.view = pViewName
    Set tExtra.status = pStatus
    Do ..Emit("ViewAttempt", pDB, pDDocId, "", pUser, tExtra)
}

/// <p>Emit a ViewExecute audit event on successful view execution (Story 12.2).</p>
/// <p>Payload includes the database, composite design-doc id, view name,
/// row count, and wall-clock duration in milliseconds. Operators can grep
/// the audit log to correlate slow queries with specific ddocs.</p>
/// @param pDB The database name
/// @param pDDocId The design document identifier
/// @param pViewName The view name
/// @param pRows The number of rows returned
/// @param pDurationMs Wall-clock duration of the query in milliseconds
/// @param pUser The user who made the request (optional)
ClassMethod ViewExecute(pDB As %String, pDDocId As %String, pViewName As %String, pRows As %Integer = 0, pDurationMs As %Numeric = 0, pUser As %String = "")
{
    Set tExtra = {}
    Set tExtra.view = pViewName
    Set tExtra.rows = pRows
    Set tExtra.durationMs = pDurationMs
    Do ..Emit("ViewExecute", pDB, pDDocId, "", pUser, tExtra)
}

/// <p>Emit a ViewError audit event on view execution failure (Story 12.2).</p>
/// <p>Distinct from <method>ViewAttempt</method>: ViewError fires only
/// when execution genuinely failed (subprocess crashed, fatal map error,
/// design doc syntactically valid but semantically broken). Callers still
/// emit ViewAttempt alongside for the HTTP-level traceability.</p>
/// @param pDB The database name
/// @param pDDocId The design document identifier
/// @param pViewName The view name
/// @param pReason Short human-readable error reason
/// @param pUser The user who made the request (optional)
ClassMethod ViewError(pDB As %String, pDDocId As %String, pViewName As %String, pReason As %String = "", pUser As %String = "")
{
    Set tExtra = {}
    Set tExtra.view = pViewName
    Set tExtra.reason = $Extract(pReason, 1, 256)
    Do ..Emit("ViewError", pDB, pDDocId, "", pUser, tExtra)
}

}
