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
ClassMethod RevisionExists(pDB As %String, pDocId As %String, pRev As %String) As %Boolean
{
    Quit $Data(^IRISCouch.Docs(pDB, pDocId, pRev))>0
}

/// <p>List all document IDs in a database.</p>
/// <p>Returns a <class>%DynamicArray</class> of document ID strings
/// by iterating <code>^IRISCouch.Docs(pDB)</code> subscripts.</p>
/// @param pDB The database name
/// @return %DynamicArray of document ID strings
ClassMethod ListDocIds(pDB As %String) As %DynamicArray
{
    Set tArr = []
    Set tDocId = ""
    For {
        Set tDocId = $Order(^IRISCouch.Docs(pDB, tDocId))
        If tDocId = "" Quit
        Do tArr.%Push(tDocId)
    }
    Quit tArr
}

/// <p>List all <em>live</em> (non-deleted, winning-rev) document IDs in a
/// database (Story 12.2).</p>
/// <p>Filters out tombstoned and missing-rev documents by consulting
/// <class>IRISCouch.Storage.RevTree</class>. Used by the view query engine
/// to iterate only the documents that will contribute emissions.</p>
/// @param pDB The database name
/// @param pIncludeDesign If 1, include <code>_design/*</code> docs (default
///        0 — views don't self-emit by convention, matching CouchDB)
/// @return %DynamicArray of document ID strings for live winning revs only
ClassMethod ListLiveDocIds(pDB As %String, pIncludeDesign As %Boolean = 0) As %DynamicArray
{
    Set tArr = []
    Set tDocId = ""
    For {
        Set tDocId = $Order(^IRISCouch.Docs(pDB, tDocId))
        If tDocId = "" Quit
        If 'pIncludeDesign, $Extract(tDocId, 1, 8) = "_design/" Continue
        Set tWin = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
        If tWin = "" Continue
        If ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tWin) Continue
        Do tArr.%Push(tDocId)
    }
    Quit tArr
}

}
