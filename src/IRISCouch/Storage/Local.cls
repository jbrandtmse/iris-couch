/// <p>Storage layer for IRISCouch local (non-replicating) document operations.</p>
/// <p>Encapsulates all direct global access for local documents stored in
/// <code>^IRISCouch.Local(db, localId)</code>.
/// Handlers must NEVER touch local document globals directly;
/// all access goes through this class (Pattern 3: Storage Encapsulation).</p>
/// <p>Local documents use a simple <code>0-N</code> revision scheme, not the
/// <code>N-hash</code> scheme of normal documents. Only the latest version
/// is kept; updates overwrite the previous revision.</p>
Class IRISCouch.Storage.Local Extends %RegisteredObject
{

/// <p>Write a local document to storage.</p>
/// <p>Stores the raw JSON body and revision string in
/// <code>^IRISCouch.Local(pDB, pLocalId)</code> as a <code>$ListBuild</code> pair.</p>
/// @param pDB The database name
/// @param pLocalId The local document identifier (without _local/ prefix)
/// @param pBody The raw JSON body string (without _id/_rev metadata)
/// @param pRev The revision string in 0-N format (e.g., "0-1")
/// @return %Status
ClassMethod Write(pDB As %String, pLocalId As %String, pBody As %String, pRev As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set ^IRISCouch.Local(pDB, pLocalId) = $ListBuild(pBody, pRev)
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Read a local document body from storage.</p>
/// <p>Returns the raw JSON body string from
/// <code>^IRISCouch.Local(pDB, pLocalId)</code>.
/// Returns empty string if the document does not exist.</p>
/// @param pDB The database name
/// @param pLocalId The local document identifier (without _local/ prefix)
/// @return %String The raw JSON body, or "" if not found
ClassMethod Read(pDB As %String, pLocalId As %String) As %String
{
    Set tData = $Get(^IRISCouch.Local(pDB, pLocalId))
    If tData = "" Quit ""
    Quit $ListGet(tData, 1)
}

/// <p>Get the current revision string for a local document.</p>
/// <p>Returns the revision from <code>^IRISCouch.Local(pDB, pLocalId)</code>.
/// Returns empty string if the document does not exist.</p>
/// @param pDB The database name
/// @param pLocalId The local document identifier (without _local/ prefix)
/// @return %String The revision string in 0-N format, or "" if not found
ClassMethod GetRev(pDB As %String, pLocalId As %String) As %String
{
    Set tData = $Get(^IRISCouch.Local(pDB, pLocalId))
    If tData = "" Quit ""
    Quit $ListGet(tData, 2)
}

/// <p>Delete a local document from storage.</p>
/// <p>Removes the node at <code>^IRISCouch.Local(pDB, pLocalId)</code>.</p>
/// @param pDB The database name
/// @param pLocalId The local document identifier (without _local/ prefix)
/// @return %Status
ClassMethod Delete(pDB As %String, pLocalId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Kill ^IRISCouch.Local(pDB, pLocalId)
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Check if a local document exists in a database.</p>
/// @param pDB The database name
/// @param pLocalId The local document identifier (without _local/ prefix)
/// @return %Boolean 1 if document exists, 0 otherwise
ClassMethod Exists(pDB As %String, pLocalId As %String) As %Boolean
{
    Quit $Data(^IRISCouch.Local(pDB, pLocalId))>0
}

/// <p>Compute the next revision for a local document.</p>
/// <p>Local documents use a <code>0-N</code> revision scheme where N starts
/// at 1 and increments by 1 on each update.</p>
/// <ul>
/// <li><code>""</code> (new document) returns <code>"0-1"</code></li>
/// <li><code>"0-N"</code> returns <code>"0-(N+1)"</code></li>
/// </ul>
/// @param pCurrentRev The current revision string, or "" for new documents
/// @return %String The next revision string in 0-N format
ClassMethod NextRev(pCurrentRev As %String) As %String
{
    If pCurrentRev = "" Quit "0-1"
    Set tNum = +$Piece(pCurrentRev, "-", 2)
    Quit "0-" _ (tNum + 1)
}

/// <p>Delete all local documents for a database.</p>
/// <p>Removes the entire <code>^IRISCouch.Local(pDB)</code> subtree.
/// Called during database deletion to clean up local documents.</p>
/// @param pDB The database name
/// @return %Status
ClassMethod DeleteAll(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Kill ^IRISCouch.Local(pDB)
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

}
