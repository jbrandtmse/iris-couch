/// <p>Enumerate design-doc-scoped functions that the write / changes pipelines
/// need to invoke (Story 12.3).</p>
/// <p>Callers are <class>IRISCouch.Core.DocumentEngine</class> (every Save*
/// method pulls the current list of <code>validate_doc_update</code> functions)
/// and <class>IRISCouch.API.ChangesHandler</class> (which resolves a single
/// named filter function). Both depend on storage-encapsulated iteration of
/// <code>_design/*</code> documents — this class centralises that iteration so
/// no caller touches <code>^IRISCouch.Docs</code> directly (Architecture
/// Pattern 3).</p>
/// <p>All helpers ignore deleted / tombstoned design docs by consulting
/// <class>IRISCouch.Storage.RevTree</class> — only the winning live revision
/// is considered, matching CouchDB's
/// <code>couch_db.erl::load_validation_funs</code>.</p>
Class IRISCouch.Core.DesignDocs Extends %RegisteredObject
{

/// <p>Return the ordered list of <code>validate_doc_update</code> function
/// sources for a database.</p>
/// <p>Iterates every live <code>_design/*</code> document, parses its body,
/// and records any doc that defines a <code>validate_doc_update</code> field.
/// Fail-fast iteration order (matching
/// <code>sources/couchdb/src/couch/src/couch_db.erl::validate_doc_update_int</code>)
/// is determined by the natural subscript order of
/// <class>IRISCouch.Storage.Document</class>.</p>
/// @param pDB The database name
/// @param pList Output: sparse subscripted array where
///        <code>pList(i,"ddocId") = "_design/&lt;name&gt;"</code> and
///        <code>pList(i,"source") = &lt;js source&gt;</code> for <code>i = 1..N</code>
/// @return %Integer The count of validate functions discovered (0 if none)
ClassMethod ListValidateFunctions(pDB As %String, Output pList) As %Integer
{
    Kill pList
    Set tCount = 0
    Set tLive = ##class(IRISCouch.Storage.Document).ListLiveDocIds(pDB, 1)
    Set tI = 0
    Set tN = tLive.%Size()
    While tI < tN {
        Set tDocId = tLive.%Get(tI)
        Set tI = tI + 1
        If $Extract(tDocId, 1, 8) '= "_design/" Continue
        Set tWin = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
        If tWin = "" Continue
        Set tBody = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tWin)
        If tBody = "" Continue
        Try {
            Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        } Catch tBadJson {
            ; Skip malformed design docs -- a validation hook cannot rely on
            ; ill-formed source. Log and continue matches CouchDB's behaviour
            ; of silently skipping unparsable validators.
            Continue
        }
        If 'tObj.%IsDefined("validate_doc_update") Continue
        Set tSource = tObj.%Get("validate_doc_update")
        ; Skip objects (only string function sources are valid) and empty strings.
        If $IsObject(tSource) Continue
        If tSource = "" Continue
        Set tCount = tCount + 1
        Set pList(tCount, "ddocId") = tDocId
        Set pList(tCount, "source") = tSource
    }
    Quit tCount
}

/// <p>Resolve a single named filter function source within a design doc.</p>
/// <p>Given the short name form (<code>ddoc/fn</code>) from the URL, looks up
/// the winning revision of <code>_design/&lt;ddoc&gt;</code>, parses the body,
/// and returns the filter source at <code>filters.&lt;fn&gt;</code>. Returns
/// empty source (and an error %Status on genuine storage failures) if the
/// ddoc or filter is missing.</p>
/// @param pDB The database name
/// @param pDDocShortName The short form of the design doc id (e.g. <code>val</code>
///        for <code>_design/val</code>)
/// @param pFilterName The filter field name within <code>filters</code>
/// @param pSource Output: the function source string, or <code>""</code> if absent
/// @return %Status $$$OK when the lookup completed (even if the ddoc/filter is
///         missing — in that case pSource is <code>""</code> and callers render
///         404). Error %Status only on genuine storage failure.
ClassMethod ListFilterFunctions(pDB As %String, pDDocShortName As %String, pFilterName As %String, Output pSource As %String) As %Status
{
    Set pSource = ""
    Set tSC = $$$OK
    Try {
        Set tDocId = "_design/" _ pDDocShortName
        Set tWin = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
        If tWin = "" Quit
        If ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tWin) Quit
        Set tBody = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tWin)
        If tBody = "" Quit
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        If 'tObj.%IsDefined("filters") Quit
        Set tFilters = tObj.%Get("filters")
        If '$IsObject(tFilters) Quit
        If 'tFilters.%IsDefined(pFilterName) Quit
        Set tFn = tFilters.%Get(pFilterName)
        If $IsObject(tFn) Quit
        Set pSource = tFn
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
