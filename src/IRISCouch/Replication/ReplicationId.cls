/// <p>Deterministic replication ID computation for CouchDB replication protocol.</p>
/// <p>Computes a unique, deterministic replication ID based on source, target,
/// and replication options. The same inputs always produce the same ID,
/// ensuring resumable replication across process restarts (FR57).</p>
/// <p>The ID is an MD5 hex hash of a canonical string built from sorted
/// source, target, and option parameters.</p>
Class IRISCouch.Replication.ReplicationId Extends %RegisteredObject
{

/// <p>Compute a deterministic replication ID from source, target, and options.</p>
/// <p>Builds a canonical string from source URL/name, target URL/name, and
/// sorted option keys (create_target, continuous, filter, doc_ids, selector).
/// Returns the MD5 hex hash of this canonical string.</p>
/// @param pSource The source database name or URL
/// @param pTarget The target database name or URL
/// @param pOptions Optional replication options (%DynamicObject)
/// @return %String The hex-encoded MD5 hash replication ID
ClassMethod Compute(pSource As %String, pTarget As %String, pOptions As %DynamicObject = "") As %String
{
    Set tSC = $$$OK
    Try {
        ; Build canonical string: source + target
        Set tCanonical = pSource _ "|" _ pTarget
        ; Add sorted options if provided
        If $IsObject(pOptions) {
            ; Collect option keys that affect replication identity
            ; Sort them alphabetically for determinism
            Set tOptKeys = ""
            Set tIter = pOptions.%GetIterator()
            While tIter.%GetNext(.tKey, .tVal) {
                ; Only include keys that affect replication identity
                If (tKey = "create_target") || (tKey = "continuous") || (tKey = "filter") || (tKey = "doc_ids") || (tKey = "selector") {
                    ; Store in local array for sorting
                    Set tOptKeys(tKey) = tVal
                }
            }
            ; Iterate sorted keys and append to canonical string
            Set tKey = ""
            For {
                Set tKey = $Order(tOptKeys(tKey))
                Quit:tKey=""
                Set tVal = tOptKeys(tKey)
                ; Handle object values (doc_ids array, selector object)
                If $IsObject(tVal) {
                    Set tValStr = tVal.%ToJSON()
                } Else {
                    Set tValStr = tVal
                }
                Set tCanonical = tCanonical _ "|" _ tKey _ "=" _ tValStr
            }
        }
        ; Compute MD5 hash
        Set tHash = $System.Encryption.MD5Hash(tCanonical)
        ; Convert to hex string
        Set tHex = ""
        For tI = 1:1:$Length(tHash) {
            Set tByte = $Ascii($Extract(tHash, tI))
            Set tHex = tHex _ $Translate($Justify($ZHex(tByte), 2), " ", "0")
        }
        Quit
    }
    Catch ex {
        Set tHex = ""
        Quit
    }
    Quit $ZConvert(tHex, "L")
}

/// <p>Check if a database name refers to a local database or a remote URL.</p>
/// <p>A name is considered local if it does not start with "http://" or "https://".</p>
/// @param pName The database name or URL to check
/// @return %Boolean 1 if local, 0 if remote URL
ClassMethod IsLocalDB(pName As %String) As %Boolean
{
    Set tLower = $ZConvert(pName, "L")
    If ($Extract(tLower, 1, 7) = "http://") Quit 0
    If ($Extract(tLower, 1, 8) = "https://") Quit 0
    Quit 1
}

}
