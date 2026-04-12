/// <p>Storage layer for IRISCouch changes feed operations.</p>
/// <p>Provides encapsulated access to <code>^IRISCouch.Changes</code> global
/// for querying change sequence data.</p>
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

}
