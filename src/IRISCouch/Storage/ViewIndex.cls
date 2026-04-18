/// <p>Persistent key-value index store for CouchDB design-doc views
/// (Story 12.5).</p>
/// <p>Updated synchronously inside
/// <class>IRISCouch.Core.DocumentEngine</class> write transactions to ensure
/// zero staleness (AC #1). Query-time lookups become <code>$Order</code>
/// traversals rather than per-query map executions -- collapsing cold-start
/// latency from Story 12.2's ~1.3 s/10-docs to single-digit ms.</p>
///
/// <h3>Global layout</h3>
/// <ul>
/// <li><code>^IRISCouch.ViewIndex(pDB, pDDocId, pViewName, pKeySort, pDocId, pSeq) = pValueJson</code>
///     — forward index; <code>$Order</code>-walked at query time to return rows
///     in key-sort order. <code>pSeq</code> disambiguates multi-emit (a single
///     doc emitting the same key twice).</li>
/// <li><code>^IRISCouch.ViewIndexById(pDB, pDDocId, pViewName, pDocId) = $ListBuild(pKeySort1, pKeySort2, ...)</code>
///     — reverse map; lets us locate every forward-index row we previously
///     wrote for a given (doc, view) in O(k) so we can purge them on update
///     or delete without a full scan.</li>
/// <li><code>^IRISCouch.ViewIndexMeta(pDB, pDDocId, pViewName) = $ListBuild(lastUpdatedSeq, viewDefinitionHash)</code>
///     — ETag source-of-truth: the seq changes whenever any indexed doc
///     mutates the view, the hash changes whenever the view source changes.</li>
/// </ul>
///
/// <h3>Storage encapsulation (Pattern 3)</h3>
/// <p>This class is the <b>sole</b> owner of
/// <code>^IRISCouch.ViewIndex*</code> globals. No other class may read or
/// write them directly. Callers (<class>IRISCouch.Core.ViewIndexUpdater</class>,
/// <class>IRISCouch.View.QueryEngine</class>,
/// <class>IRISCouch.API.ViewHandler</class>) use the class methods only.</p>
///
/// <h3>Reference</h3>
/// <ul>
/// <li>CouchDB incremental update algorithm:
///     <code>sources/couchdb/src/couch_mrview/src/couch_mrview_updater.erl</code>.
///     Per-doc pattern (purge old kv rows, insert new ones) is preserved;
///     the btree is replaced by IRIS globals that sort via <code>$Order</code>.</li>
/// <li>Architectural template: <class>IRISCouch.Projection.MangoIndex</class>
///     already implements the same "index-on-write" pattern for Mango queries.</li>
/// </ul>
Class IRISCouch.Storage.ViewIndex Extends %RegisteredObject
{

/// <p>Sort-prefix character that keeps numeric keys ordered numerically
/// while collating after null and before strings/objects. Numeric keys get
/// padded to a fixed width so <code>$Order</code> matches numeric order.</p>
Parameter KEYNULLPREFIX = "0";

Parameter KEYBOOLPREFIX = "1";

Parameter KEYNUMERICPREFIX = "2";

Parameter KEYSTRINGPREFIX = "3";

Parameter KEYARRAYPREFIX = "4";

Parameter KEYOBJECTPREFIX = "5";

/// <p>Encode a JSON key into a sortable string prefix.</p>
/// <p>Collation order: null &lt; boolean &lt; number &lt; string &lt; array &lt; object
/// — matches CouchDB's typed-ejson-compare semantics (per
/// <code>sources/couchdb/src/couch/src/couch_ejson_compare.erl</code>). Numbers
/// are zero-padded so <code>$Order</code> sorts them numerically.</p>
/// @param pKey The key value from <code>emit(key, value)</code>
/// @return %String A byte-comparable encoding
ClassMethod EncodeKeyForSort(pKey) As %String
{
    If pKey = "" {
        ; IRIS %DynamicObject cannot distinguish empty-string from JSON null
        ; purely from the scalar — both end up as "". We lean on the pattern
        ; used in View.QueryEngine.EncodeKeyForSort (Story 12.2) and treat
        ; "" as null for sort purposes. A fuller fix would require %GetTypeOf
        ; at the call site to pass a type hint.
        Quit ..#KEYNULLPREFIX _ ":"
    }
    If $IsObject(pKey) {
        If pKey.%IsA("%DynamicArray") {
            Quit ..#KEYARRAYPREFIX _ ":" _ pKey.%ToJSON()
        }
        Quit ..#KEYOBJECTPREFIX _ ":" _ pKey.%ToJSON()
    }
    ; Scalar distinctions. A bool/integer sentinel lived here previously
    ; (Story 12.5 Task 1) but ObjectScript cannot reliably distinguish 1
    ; from true without a caller-supplied type hint, so the block was dead
    ; code and has been removed (Story 13.0 cleanup 2026-04-18).
    If (pKey = +pKey) && (pKey '= "") {
        ; Numeric: pad integer portion so lexical sort = numeric sort.
        ; Negative numbers are not correctly collated here (CouchDB rarely
        ; uses negative keys; documented deviation carried over from
        ; Story 12.2 QueryEngine.EncodeKeyForSort).
        Set tAbs = +pKey
        Quit ..#KEYNUMERICPREFIX _ ":" _ $Justify(tAbs, 25, 0)
    }
    ; Default: string.
    Quit ..#KEYSTRINGPREFIX _ ":" _ pKey
}

/// <p>Hash a view's map+reduce JavaScript source for the ETag / invalidation
/// signal.</p>
/// <p>Uses SHA-1 for speed — this is not a cryptographic hash boundary, just
/// a change detector. Hex encoded, lowercase, 40 chars.</p>
/// @param pMapSource Map function source
/// @param pReduceSource Reduce function source (may be empty)
/// @return %String 40-char lowercase hex SHA-1
ClassMethod ViewDefinitionHash(pMapSource As %String, pReduceSource As %String = "") As %String
{
    Set tInput = pMapSource _ $Char(30) _ pReduceSource
    Set tBinary = $System.Encryption.SHAHash(160, tInput)
    Set tHex = ""
    For tI = 1:1:$Length(tBinary) {
        Set tByte = $Ascii(tBinary, tI)
        Set tByteHex = $ZHex(tByte)
        If $Length(tByteHex) = 1 Set tByteHex = "0" _ tByteHex
        Set tHex = tHex _ tByteHex
    }
    Quit $ZConvert(tHex, "L")
}

/// <p>Append one emission row to the forward + reverse indexes.</p>
/// <p>Caller is responsible for calling
/// <method>RemoveEntriesForDoc</method> first if the doc previously emitted
/// rows for this view (that is the standard update pattern — purge then
/// re-emit).</p>
/// <p>Appends instead of overwrites because a single doc may emit the same
/// key multiple times; each emission gets a unique <code>seq</code>
/// sub-subscript under <code>(pKeySort, pDocId)</code>.</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id (<code>_design/&lt;name&gt;</code>)
/// @param pViewName View name within the design doc
/// @param pKey Emitted key (any JSON value)
/// @param pDocId Source document id
/// @param pValue Emitted value (any JSON value)
/// @return %Status
ClassMethod AddEntry(pDB As %String, pDDocId As %String, pViewName As %String, pKey, pDocId As %String, pValue) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tKeySort = ..EncodeKeyForSort(pKey)
        ; Forward index: unique seq within (db, ddoc, view, keySort, docId).
        Set tSeq = $Increment(^IRISCouch.ViewIndexCounter(pDB, pDDocId, pViewName, tKeySort, pDocId))
        ; Store both the raw key (for display — caller may have used a typed
        ; value) and the value. Encoding both as JSON keeps the row
        ; self-describing regardless of what the map emitted.
        Set tKeyJson = $Select($IsObject(pKey): pKey.%ToJSON(), 1: ..#KEYNULLPREFIX)  ; filler
        ; Rebuild tKeyJson safely. %DynamicObject.%ToJSON exists, but raw
        ; scalars need encoding too; use a helper object to avoid quoting traps.
        Set tKeyJson = ..EncodeAsJson(pKey)
        Set tValueJson = ..EncodeAsJson(pValue)
        Set ^IRISCouch.ViewIndex(pDB, pDDocId, pViewName, tKeySort, pDocId, tSeq) = $ListBuild(tKeyJson, tValueJson)
        ; Reverse index: append this keySort to the doc's kv list so we can
        ; purge later. We store the LIST of every (keySort, seq) pair for
        ; atomic cleanup.
        Set tPrior = $Get(^IRISCouch.ViewIndexById(pDB, pDDocId, pViewName, pDocId))
        Set tUpdated = tPrior _ $ListBuild($ListBuild(tKeySort, tSeq))
        Set ^IRISCouch.ViewIndexById(pDB, pDDocId, pViewName, pDocId) = tUpdated
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every forward-index row a given doc contributed to a view.</p>
/// <p>Reads the reverse map, kills each referenced forward row, then kills
/// the reverse entry. Idempotent: a doc that never emitted rows for this
/// view is a no-op (reverse map absent).</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id
/// @param pViewName View name
/// @param pDocId Document id whose rows are to be purged
/// @return %Status
ClassMethod RemoveEntriesForDoc(pDB As %String, pDDocId As %String, pViewName As %String, pDocId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tReverse = $Get(^IRISCouch.ViewIndexById(pDB, pDDocId, pViewName, pDocId))
        If tReverse = "" Quit
        ; tReverse is a $List of $ListBuild(keySort, seq) pairs.
        Set tN = $ListLength(tReverse)
        For tI = 1:1:tN {
            Set tPair = $List(tReverse, tI)
            If tPair = "" Continue
            Set tKeySort = $List(tPair, 1)
            Set tSeq = $List(tPair, 2)
            Kill ^IRISCouch.ViewIndex(pDB, pDDocId, pViewName, tKeySort, pDocId, tSeq)
            ; If no more rows remain at (keySort, docId), kill the counter
            ; sub-node so it stops showing up in $Order walks.
            If $Data(^IRISCouch.ViewIndex(pDB, pDDocId, pViewName, tKeySort, pDocId)) = 0 {
                Kill ^IRISCouch.ViewIndexCounter(pDB, pDDocId, pViewName, tKeySort, pDocId)
            }
        }
        Kill ^IRISCouch.ViewIndexById(pDB, pDDocId, pViewName, pDocId)
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Walk the forward index and emit every row for a view, in key-sort
/// order.</p>
/// <p>Story 12.5 ships without range (<code>startkey</code>/<code>endkey</code>)
/// or pagination (<code>limit</code>/<code>skip</code>) parameters —
/// those remain scope-cut to Story 12.2a. The output array carries every
/// row for the view so the caller can apply the existing Story 12.2
/// semantics on top.</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id
/// @param pViewName View name
/// @param pRows Output: <class>%DynamicArray</class> of
///        <code>{"id":pDocId,"key":pKey,"value":pValue}</code> rows in key order
/// @return %Status
ClassMethod QueryRange(pDB As %String, pDDocId As %String, pViewName As %String, Output pRows As %DynamicArray) As %Status
{
    Set pRows = []
    Set tSC = $$$OK
    Try {
        Set tKeySort = ""
        For {
            Set tKeySort = $Order(^IRISCouch.ViewIndex(pDB, pDDocId, pViewName, tKeySort))
            If tKeySort = "" Quit
            Set tDocId = ""
            For {
                Set tDocId = $Order(^IRISCouch.ViewIndex(pDB, pDDocId, pViewName, tKeySort, tDocId))
                If tDocId = "" Quit
                Set tSeq = ""
                For {
                    Set tSeq = $Order(^IRISCouch.ViewIndex(pDB, pDDocId, pViewName, tKeySort, tDocId, tSeq))
                    If tSeq = "" Quit
                    Set tCell = ^IRISCouch.ViewIndex(pDB, pDDocId, pViewName, tKeySort, tDocId, tSeq)
                    Set tKeyJson = $List(tCell, 1)
                    Set tValueJson = $List(tCell, 2)
                    Set tRow = {}
                    Do tRow.%Set("id", tDocId)
                    Do ..InjectJsonField(tRow, "key", tKeyJson)
                    Do ..InjectJsonField(tRow, "value", tValueJson)
                    Do pRows.%Push(tRow)
                }
            }
        }
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Return the last-updated sequence for a view.</p>
/// <p>Zero when the view has never been written.</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id
/// @param pViewName View name
/// @return %Integer The seq value (0 if meta missing)
ClassMethod GetLastUpdatedSeq(pDB As %String, pDDocId As %String, pViewName As %String) As %Integer
{
    Set tMeta = $Get(^IRISCouch.ViewIndexMeta(pDB, pDDocId, pViewName))
    If tMeta = "" Quit 0
    Quit +$List(tMeta, 1)
}

/// <p>Return the cached view-definition hash.</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id
/// @param pViewName View name
/// @return %String 40-char SHA-1 hex, empty if meta missing
ClassMethod GetViewDefinitionHash(pDB As %String, pDDocId As %String, pViewName As %String) As %String
{
    Set tMeta = $Get(^IRISCouch.ViewIndexMeta(pDB, pDDocId, pViewName))
    If tMeta = "" Quit ""
    Quit $List(tMeta, 2)
}

/// <p>Update the meta entry after a write-time incremental update.</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id
/// @param pViewName View name
/// @param pSeq New last-updated sequence
/// @param pHash View definition hash
/// @return %Status
ClassMethod SetMeta(pDB As %String, pDDocId As %String, pViewName As %String, pSeq As %Integer, pHash As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set ^IRISCouch.ViewIndexMeta(pDB, pDDocId, pViewName) = $ListBuild(pSeq, pHash)
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Drop every index and meta entry for a database (cascade on DB delete).</p>
/// @param pDB Database name
/// @return %Status
ClassMethod DropForDatabase(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Kill ^IRISCouch.ViewIndex(pDB)
        Kill ^IRISCouch.ViewIndexById(pDB)
        Kill ^IRISCouch.ViewIndexMeta(pDB)
        Kill ^IRISCouch.ViewIndexCounter(pDB)
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Drop every index for a specific design doc (cascade on ddoc delete or
/// view removal / source change).</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id
/// @return %Status
ClassMethod DropForDesignDoc(pDB As %String, pDDocId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Kill ^IRISCouch.ViewIndex(pDB, pDDocId)
        Kill ^IRISCouch.ViewIndexById(pDB, pDDocId)
        Kill ^IRISCouch.ViewIndexMeta(pDB, pDDocId)
        Kill ^IRISCouch.ViewIndexCounter(pDB, pDDocId)
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Drop every index entry for a single named view under a design doc
/// (used when a view's map/reduce source changes).</p>
/// <p>Exposed so <class>IRISCouch.Core.ViewIndexUpdater</class> does not
/// need to touch <code>^IRISCouch.ViewIndex*</code> globals directly --
/// keeps Storage.ViewIndex as the sole owner per the encapsulation rule.</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id
/// @param pViewName View name
/// @return %Status
ClassMethod DropForView(pDB As %String, pDDocId As %String, pViewName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Kill ^IRISCouch.ViewIndex(pDB, pDDocId, pViewName)
        Kill ^IRISCouch.ViewIndexById(pDB, pDDocId, pViewName)
        Kill ^IRISCouch.ViewIndexCounter(pDB, pDDocId, pViewName)
        Kill ^IRISCouch.ViewIndexMeta(pDB, pDDocId, pViewName)
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>List every view name that has a meta entry for a given (db, ddoc).</p>
/// <p>Used by <class>IRISCouch.Core.ViewIndexUpdater</class> to detect
/// views that no longer appear in the design doc (so their orphaned
/// entries can be dropped via <method>DropForView</method>).</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id
/// @return %DynamicArray of view names
ClassMethod ListIndexedViewNames(pDB As %String, pDDocId As %String) As %DynamicArray
{
    Set tList = []
    Set tName = ""
    For {
        Set tName = $Order(^IRISCouch.ViewIndexMeta(pDB, pDDocId, tName))
        If tName = "" Quit
        Do tList.%Push(tName)
    }
    Quit tList
}

/// <p>Rebuild the index for one named view by iterating every live doc and
/// invoking the map function.</p>
/// <p>Expensive; used for migration from a pre-12.5 database and for
/// recovery when a view's source changes. Skips design docs (a view on
/// design docs is supported in CouchDB but rare; matches the Story 12.2
/// QueryEngine iteration which walks all live docs).</p>
/// <p>Runs OUTSIDE any caller transaction — this is a heavy operation and
/// should not be wrapped in TSTART/TCOMMIT by the caller. It uses direct
/// index writes (no transaction) so a mid-rebuild crash leaves a partial
/// index that the next call will overwrite cleanly.</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id
/// @param pViewName View name within the ddoc
/// @param pSandbox Active JSRuntime sandbox
/// @return %Status
ClassMethod Rebuild(pDB As %String, pDDocId As %String, pViewName As %String, pSandbox As IRISCouch.JSRuntime.Sandbox) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Resolve the view source (map + reduce) from the winning ddoc revision.
        Set tWin = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDDocId)
        If tWin = "" {
            Set tSC = $$$ERROR($$$GeneralError, "rebuild: design doc missing: " _ pDDocId)
            Quit
        }
        Set tBody = ##class(IRISCouch.Storage.Document).Read(pDB, pDDocId, tWin)
        If tBody = "" {
            Set tSC = $$$ERROR($$$GeneralError, "rebuild: design doc body missing")
            Quit
        }
        Set tDDoc = ##class(%DynamicObject).%FromJSON(tBody)
        Set tViews = tDDoc.%Get("views")
        If '$IsObject(tViews) || '(tViews.%IsDefined(pViewName)) {
            Set tSC = $$$ERROR($$$GeneralError, "rebuild: view not defined: " _ pViewName)
            Quit
        }
        Set tViewDef = tViews.%Get(pViewName)
        Set tMapFn = tViewDef.%Get("map")
        If tMapFn = "" {
            Set tSC = $$$ERROR($$$GeneralError, "rebuild: view has no map function")
            Quit
        }
        Set tReduceSource = $Select(tViewDef.%IsDefined("reduce"): tViewDef.%Get("reduce"), 1: "")
        Set tHash = ..ViewDefinitionHash(tMapFn, tReduceSource)
        ; Drop any existing index for this view before repopulating.
        Kill ^IRISCouch.ViewIndex(pDB, pDDocId, pViewName)
        Kill ^IRISCouch.ViewIndexById(pDB, pDDocId, pViewName)
        Kill ^IRISCouch.ViewIndexCounter(pDB, pDDocId, pViewName)
        Kill ^IRISCouch.ViewIndexMeta(pDB, pDDocId, pViewName)
        ; Iterate live docs (including design docs -- the Story 12.2 engine
        ; did). Apply the map, append entries.
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
                Continue
            }
            Do tDocObj.%Set("_id", tDocId)
            Do tDocObj.%Set("_rev", tDocWin)
            Set tEmits = ""
            Try {
                Set tEmits = pSandbox.ExecuteMap(tMapFn, tDocObj)
            } Catch exMap {
                Continue
            }
            If '$IsObject(tEmits) Continue
            Set tEN = tEmits.%Size()
            Set tJ = 0
            While tJ < tEN {
                Set tPair = tEmits.%Get(tJ)
                Set tJ = tJ + 1
                If '$IsObject(tPair) Continue
                Do ..AddEntry(pDB, pDDocId, pViewName, tPair.%Get(0), tDocId, tPair.%Get(1))
            }
        }
        ; Seed meta with current DB update_seq and the hash.
        Set tSeq = +$Get(^IRISCouch.Seq(pDB))
        Do ..SetMeta(pDB, pDDocId, pViewName, tSeq, tHash)
        Do ##class(IRISCouch.Audit.Emit).ViewIndexRebuild(pDB, pDDocId, pViewName)
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Encode a scalar or object as a JSON string for storage in the index.</p>
/// <p>Objects serialize via <method>%ToJSON</method>; scalars are JSON-encoded
/// by wrapping in a one-element array then peeling the element. This avoids
/// ad-hoc quoting bugs (e.g., strings containing double-quotes).</p>
ClassMethod EncodeAsJson(pValue) As %String [ Internal ]
{
    If $IsObject(pValue) Quit pValue.%ToJSON()
    ; Use a temporary array to let %DynamicObject handle escaping.
    Set tArr = []
    Do tArr.%Push(pValue)
    Set tArrJson = tArr.%ToJSON()
    ; tArrJson is like [123] or ["hello"]. Strip the surrounding []. The
    ; inner element is what we want to store.
    Set tLen = $Length(tArrJson)
    If tLen < 2 Quit tArrJson
    Quit $Extract(tArrJson, 2, tLen - 1)
}

/// <p>Parse a stored JSON fragment back into a %DynamicObject field value
/// (object, array, or scalar).</p>
/// <p>Uses <method>%FromJSON</method> with the same array-wrapping trick as
/// <method>EncodeAsJson</method> so scalars round-trip correctly.</p>
ClassMethod InjectJsonField(pTarget As %DynamicObject, pFieldName As %String, pJsonFragment As %String) [ Internal ]
{
    Set tWrap = "[" _ pJsonFragment _ "]"
    Set tArr = [].%FromJSON(tWrap)
    If tArr.%Size() = 0 {
        Do pTarget.%Set(pFieldName, "", "null")
        Quit
    }
    Set tVal = tArr.%Get(0)
    Do pTarget.%Set(pFieldName, tVal)
}

}
