/// <p>Storage layer for IRISCouch document body operations.</p>
/// <p>Encapsulates all direct global access for document bodies stored in
/// <code>^IRISCouch.Docs(db, docId, rev)</code>.
/// Handlers must NEVER touch document globals directly;
/// all access goes through this class (Pattern 3: Storage Encapsulation).</p>
Class IRISCouch.Storage.Document Extends %RegisteredObject
{

/// <p>Write a document body to storage.</p>
/// <p>Stores the raw JSON body string in <code>^IRISCouch.Docs(pDB, pDocId, pRev)</code>.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision string (e.g., "1-abc123...")
/// @param pBody The raw JSON body string
/// @return %Status
ClassMethod Write(pDB As %String, pDocId As %String, pRev As %String, pBody As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set ^IRISCouch.Docs(pDB, pDocId, pRev) = pBody
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Read a document body from storage.</p>
/// <p>Returns the raw JSON body string from <code>^IRISCouch.Docs(pDB, pDocId, pRev)</code>.
/// Returns empty string if the document or revision does not exist.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision string
/// @return %String The raw JSON body, or "" if not found
ClassMethod Read(pDB As %String, pDocId As %String, pRev As %String) As %String
{
    Quit $Get(^IRISCouch.Docs(pDB, pDocId, pRev))
}

/// <p>Count non-deleted documents in a database.</p>
/// <p>Returns the value of <code>^IRISCouch.DB(pDB, "doc_count")</code>
/// which is maintained by DocumentEngine (incremented on create, decremented on delete).</p>
/// @param pDB The database name
/// @return %Integer The count of non-deleted documents
ClassMethod CountNonDeleted(pDB As %String) As %Integer
{
    Quit +$Get(^IRISCouch.DB(pDB, "doc_count"))
}

/// <p>Check if a document exists in a database.</p>
/// <p>Returns true if any revision of the document exists in
/// <code>^IRISCouch.Docs(pDB, pDocId)</code>.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %Boolean 1 if document exists, 0 otherwise
ClassMethod Exists(pDB As %String, pDocId As %String) As %Boolean
{
    Quit $Data(^IRISCouch.Docs(pDB, pDocId))>0
}

/// <p>Check if a specific document revision exists in storage.</p>
/// <p>Returns true if <code>^IRISCouch.Docs(pDB, pDocId, pRev)</code> has data.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision string
/// @return %Boolean 1 if the specific revision exists, 0 otherwise
ClassMethod DocumentExists(pDB As %String, pDocId As %String, pRev As %String) As %Boolean
{
    Quit $Data(^IRISCouch.Docs(pDB, pDocId, pRev))>0
}

}
