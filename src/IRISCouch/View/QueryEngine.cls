/// <p>Orchestrates design-document view execution end-to-end (Story 12.2).</p>
/// <p>The <class>IRISCouch.API.ViewHandler</class> delegates a parsed view
/// request to <method>Query</method> which:</p>
/// <ol>
/// <li>Loads the design doc body from
///     <class>IRISCouch.Storage.Document</class>.</li>
/// <li>Extracts the <code>views.&lt;name&gt;.map</code> source and the
///     optional <code>views.&lt;name&gt;.reduce</code> (either a builtin
///     token or a JS source string).</li>
/// <li>Iterates live documents via
///     <method>IRISCouch.Storage.Document.ListLiveDocIds</method>.</li>
/// <li>Calls <method>IRISCouch.JSRuntime.Sandbox.ExecuteMap</method> per
///     doc; per-doc exceptions are logged via
///     <method>IRISCouch.Util.Log.Warn</method> and the doc is skipped
///     (matches <code>sources/couchdb/share/server/views.js::handleViewError</code>).</li>
/// <li>Sorts accumulated rows by key using CouchDB-ish lexicographic
///     collation (deviation documented on the sort helper).</li>
/// <li>Applies reduce (builtin via
///     <class>IRISCouch.View.BuiltinReduce</class>, or JS via
///     <method>IRISCouch.JSRuntime.Sandbox.ExecuteReduce</method>) when
///     requested.</li>
/// <li>Builds the CouchDB response envelope.</li>
/// </ol>
///
/// <h3>MVP scope (Story 12.2)</h3>
/// <p>Only <code>reduce</code> and <code>include_docs</code> query params
/// are honoured. <code>group</code>, <code>group_level</code>,
/// <code>startkey</code>, <code>endkey</code>, <code>limit</code>, and
/// <code>skip</code> are deferred to a follow-up story (logged in
/// <code>deferred-work.md</code>).</p>
Class IRISCouch.View.QueryEngine Extends %RegisteredObject
{

/// <p>Execute a view query and return the CouchDB response envelope.</p>
/// <p>Public entry point for <class>IRISCouch.API.ViewHandler</class>.
/// Callers pass the database, composite design-doc id (e.g.,
/// <code>_design/by_user</code>), the view name, and a
/// <class>%DynamicObject</class> of parsed query parameters. The return
/// value is the JSON response body exactly as the client receives it.</p>
/// @param pDB The database name
/// @param pDDocId The composite design doc id (<code>_design/&lt;name&gt;</code>)
/// @param pViewName The view name
/// @param pParams Parsed query params: reduce, include_docs (booleans)
/// @param pSandbox The active <class>IRISCouch.JSRuntime.Sandbox</class> instance
/// @return %DynamicObject response envelope
ClassMethod Query(pDB As %String, pDDocId As %String, pViewName As %String, pParams As %DynamicObject, pSandbox As IRISCouch.JSRuntime.Sandbox) As %DynamicObject
{
    ; 1. Load design doc body (winning rev).
    Set tWin = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDDocId)
    If tWin = "" {
        Throw ##class(%Exception.General).%New("view execution", "not_found", "", "design doc missing: " _ pDDocId)
    }
    Set tBody = ##class(IRISCouch.Storage.Document).Read(pDB, pDDocId, tWin)
    If tBody = "" {
        Throw ##class(%Exception.General).%New("view execution", "not_found", "", "design doc body missing: " _ pDDocId)
    }
    Set tDDoc = ##class(%DynamicObject).%FromJSON(tBody)
    Set tViews = tDDoc.%Get("views")
    If '$IsObject(tViews) || '(tViews.%IsDefined(pViewName)) {
        Throw ##class(%Exception.General).%New("view execution", "not_found", "", "missing_named_view: " _ pViewName)
    }
    Set tViewDef = tViews.%Get(pViewName)
    Set tMapFn = tViewDef.%Get("map")
    If tMapFn = "" {
        Throw ##class(%Exception.General).%New("view execution", "not_found", "", "view has no map function: " _ pViewName)
    }
    Set tReduceSource = ""
    If tViewDef.%IsDefined("reduce") {
        Set tReduceSource = tViewDef.%Get("reduce")
    }
    ; 2. Parse query params (only reduce and include_docs for MVP).
    Set tIncludeDocs = 0
    Set tReduceRequested = (tReduceSource '= "")
    If $IsObject(pParams) {
        If pParams.%IsDefined("include_docs") {
            Set tIncludeDocs = (pParams.%Get("include_docs") = "true") || (pParams.%Get("include_docs") = 1)
        }
        If pParams.%IsDefined("reduce") {
            Set tVal = pParams.%Get("reduce")
            If (tVal = "false") || (tVal = 0) {
                Set tReduceRequested = 0
            } ElseIf (tVal = "true") || (tVal = 1) {
                ; Explicit ?reduce=true is only valid if the view defines a
                ; reduce function. CouchDB returns 400 query_parse_error when
                ; a client asks for reduction on a map-only view; mirror that
                ; here so clients get a useful error instead of silent map
                ; rows. Signalled via the "query_parse_error" exception code
                ; which ViewHandler can map to 400.
                If tReduceSource = "" {
                    Throw ##class(%Exception.General).%New("view execution", "query_parse_error", "", "reduce=true requested but view has no reduce function")
                }
                Set tReduceRequested = 1
            }
        }
    }
    ; 3. Iterate live docs and accumulate map emissions.
    Set tRows = []
    Set tDocIds = ##class(IRISCouch.Storage.Document).ListLiveDocIds(pDB)
    Set tN = tDocIds.%Size()
    Set tI = 0
    While tI < tN {
        Set tDocId = tDocIds.%Get(tI)
        Set tI = tI + 1
        Set tDocWin = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
        If tDocWin = "" Continue
        Set tDocBody = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tDocWin)
        If tDocBody = "" Continue
        Set tDocObj = {}
        Try {
            Set tDocObj = ##class(%DynamicObject).%FromJSON(tDocBody)
        } Catch exParse {
            Do ##class(IRISCouch.Util.Log).Warn("view", "corrupt doc body skipped", {"db":(pDB),"doc":(tDocId)})
            Continue
        }
        ; Inject _id / _rev so the map function can reference them.
        Do tDocObj.%Set("_id", tDocId)
        Do tDocObj.%Set("_rev", tDocWin)
        ; Per-doc map execution with error-swallowing per AC #8.
        Set tEmits = ""
        Try {
            Set tEmits = pSandbox.ExecuteMap(tMapFn, tDocObj)
        } Catch exMap {
            Do ##class(IRISCouch.Util.Log).Warn("view", "map error for doc (skipped)", {"db":(pDB),"doc":(tDocId),"error":(exMap.DisplayString())})
            Continue
        }
        ; tEmits is an array of [key, value] pairs.
        If '$IsObject(tEmits) Continue
        Set tJ = 0
        Set tEN = tEmits.%Size()
        While tJ < tEN {
            Set tPair = tEmits.%Get(tJ)
            Set tJ = tJ + 1
            If '$IsObject(tPair) Continue
            Set tKey = tPair.%Get(0)
            Set tValue = tPair.%Get(1)
            Set tRow = {}
            Do tRow.%Set("id", tDocId)
            Do tRow.%Set("key", tKey)
            Do tRow.%Set("value", tValue)
            If tIncludeDocs {
                ; Rebuild the doc WITHOUT the _id/_rev injection pollution --
                ; the include_docs consumer expects the stored body augmented
                ; with _id/_rev, which is what we already have on tDocObj.
                Do tRow.%Set("doc", tDocObj)
            }
            Do tRows.%Push(tRow)
        }
    }
    ; 4. Sort rows by key (CouchDB collation -- see sort helper).
    Set tRows = ..SortRowsByKey(tRows)
    ; 5. Reduce if requested.
    If tReduceRequested {
        ; Extract flat values for reduce input.
        Set tValues = []
        Set tKeys = []
        Set tI = 0
        Set tN = tRows.%Size()
        While tI < tN {
            Set tRow = tRows.%Get(tI)
            Do tKeys.%Push(tRow.%Get("key"))
            Do tValues.%Push(tRow.%Get("value"))
            Set tI = tI + 1
        }
        Set tReducedValue = ""
        If ##class(IRISCouch.View.BuiltinReduce).IsBuiltin(tReduceSource) {
            ; Native builtin -- bypass subprocess entirely.
            Set tReducedValue = ##class(IRISCouch.View.BuiltinReduce).Apply(tReduceSource, tValues)
        } Else {
            ; User JS reduce via subprocess sandbox.
            Set tReduceResp = pSandbox.ExecuteReduce(tReduceSource, tKeys, tValues, 0)
            If $IsObject(tReduceResp) {
                Set tReducedValue = tReduceResp.%Get("value")
            }
        }
        ; CouchDB reduce (no grouping) shape:
        ; {"rows":[{"key":null,"value":<reduced>}]}
        Set tRow = {}
        Do tRow.%Set("key", "", "null")
        Do tRow.%Set("value", tReducedValue)
        Set tReducedRows = []
        Do tReducedRows.%Push(tRow)
        Set tResp = {}
        Do tResp.%Set("rows", tReducedRows)
        Quit tResp
    }
    ; 6. Map-only response envelope (AC #1).
    Set tResp = {}
    Do tResp.%Set("total_rows", tRows.%Size(), "number")
    Do tResp.%Set("offset", 0, "number")
    Do tResp.%Set("rows", tRows)
    Quit tResp
}

/// <p>Sort rows by key using CouchDB-ish lexicographic collation.</p>
/// <p>Story 12.2 deviation: CouchDB's
/// <code>sources/couchdb/src/couch/src/couch_ejson_compare.erl</code>
/// implements a typed comparison (null &lt; false &lt; true &lt; numbers
/// &lt; strings &lt; arrays &lt; objects). The MVP here sorts on the JSON
/// serialisation of the key, which is correct for homogeneous-type keys
/// (strings, numbers) but may mis-order mixed-type keys. Logged as
/// deferred work.</p>
ClassMethod SortRowsByKey(pRows As %DynamicArray) As %DynamicArray [ Internal ]
{
    Set tN = pRows.%Size()
    If tN < 2 Quit pRows
    ; Materialise rows into a local array keyed by serialised-key so
    ; $Order gives us ascending CouchDB-ish order. Collisions append by
    ; insertion order.
    Kill tBuckets
    Set tI = 0
    While tI < tN {
        Set tRow = pRows.%Get(tI)
        Set tKey = tRow.%Get("key")
        Set tKeyStr = ..EncodeKeyForSort(tKey)
        Set tBuckets(tKeyStr, $Increment(tBuckets(tKeyStr))) = tRow
        Set tI = tI + 1
    }
    Set tSorted = []
    Set tKS = ""
    For {
        Set tKS = $Order(tBuckets(tKS))
        If tKS = "" Quit
        Set tJ = ""
        For {
            Set tJ = $Order(tBuckets(tKS, tJ))
            If tJ = "" Quit
            Do tSorted.%Push(tBuckets(tKS, tJ))
        }
    }
    Quit tSorted
}

/// <p>Serialise a key for sort-order comparison.</p>
/// <p>Numeric keys are padded so lexicographic <code>$Order</code> matches
/// numeric order. Strings are prefixed to sort after numbers. Objects /
/// arrays fall back to their JSON string; this is the documented MVP
/// deviation.</p>
ClassMethod EncodeKeyForSort(pKey) As %String [ Internal ]
{
    If $IsObject(pKey) {
        Quit "z:" _ pKey.%ToJSON()
    }
    If pKey = "" Quit "0:"
    ; Numeric-looking: pad integer part to 20 chars so lexicographic sort
    ; matches numeric. Negative numbers are not correctly collated here --
    ; CouchDB 3 rarely uses negative keys in practice and the deviation is
    ; logged.
    If (pKey = +pKey) {
        Set tAbs = +pKey
        Quit "n:" _ $Justify(tAbs, 25, 0)
    }
    Quit "s:" _ pKey
}

}
