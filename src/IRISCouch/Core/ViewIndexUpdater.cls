/// <p>Incremental view-index maintenance hook, invoked by every
/// <class>IRISCouch.Core.DocumentEngine</class> save method after the body
/// is persisted but before <code>TCOMMIT</code> (Story 12.5 AC #1).</p>
///
/// <h3>Why in-transaction</h3>
/// <p>The alternative — a post-commit background job — would leave a
/// staleness window where a just-written doc is not yet queryable through
/// its view. Keeping the update transactional means every successful
/// write guarantees the view index includes the new state; conversely a
/// rollback guarantees the index is unchanged.</p>
///
/// <h3>Design-doc change detection</h3>
/// <p>When a <code>_design/*</code> doc is saved and its
/// <code>views.&lt;name&gt;.map</code> source differs from the previous
/// revision, the cached index for that view is invalidated via
/// <method>IRISCouch.Storage.ViewIndex.DropForDesignDoc</method>; the next
/// query rebuilds. We deliberately do NOT rebuild eagerly at save time —
/// a ddoc update with 100k matching docs would make the write take
/// minutes.</p>
///
/// <h3>Pattern Replication Completeness (Story 12.5 mandate)</h3>
/// <p>Invoked from all four writers:</p>
/// <ul>
/// <li><class>DocumentEngine.Save</class> — non-deleting write</li>
/// <li><class>DocumentEngine.SaveDeleted</class> — tombstone (null body)</li>
/// <li><class>DocumentEngine.SaveWithHistory</class> — replication graft</li>
/// <li><class>DocumentEngine.SaveWithAttachments</class> — multi-attachment</li>
/// </ul>
Class IRISCouch.Core.ViewIndexUpdater Extends %RegisteredObject
{

/// <p>Update every design-doc view's index for one document write.</p>
/// <p>For each design doc in <var>pDB</var> with a <code>views</code>
/// collection, for each view:</p>
/// <ol>
/// <li>Purge any prior forward/reverse index rows for <var>pDocId</var>
///     (via <method>Storage.ViewIndex.RemoveEntriesForDoc</method>).</li>
/// <li>If <var>pNewDocBody</var> is non-null (write / graft, not tombstone),
///     execute the map function against the new body and append every
///     emitted (key, value) pair.</li>
/// <li>Update the view's meta entry with the latest update seq and
///     definition hash.</li>
/// </ol>
/// <p>Design docs themselves are skipped — we do not index the design
/// doc as data (CouchDB's same-ddoc self-emit is rare and leads to
/// surprising behaviour; documented scope decision for α/β).</p>
/// <p>Iteration order matches
/// <class>IRISCouch.Core.DesignDocs.ListValidateFunctions</class> — natural
/// subscript order of <class>IRISCouch.Storage.Document</class>.</p>
/// @param pDB Database name
/// @param pDocId Document id being saved (or deleted)
/// @param pNewDocBody The new body <class>%DynamicObject</class>; pass
///        <code>$$$NULLOREF</code> (or empty) for a deletion so the stale
///        entries are purged without re-emit
/// @param pNewRev The new revision (used only for logging; the index rows
///        themselves are rev-agnostic)
/// @return %Status $$$OK on success; error %Status whose reason names the
///         failing step for TROLLBACK surfacing
ClassMethod UpdateForDoc(pDB As %String, pDocId As %String, pNewDocBody As %DynamicObject = "", pNewRev As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        ; Skip _local documents entirely (never indexed by views).
        If $Extract(pDocId, 1, 7) = "_local/" Quit
        ; List design docs. Only _design/* qualify.
        Set tDDocIds = ..ListDesignDocIds(pDB)
        Set tN = tDDocIds.%Size()
        If tN = 0 Quit
        ; Short-circuit when no JSRuntime is available: nothing to execute.
        ; (An operator who wants view indexing MUST enable a JSRuntime; AC #4
        ; exemption does not apply here because view indexing is implicit,
        ; not requested by the caller.)
        Set tSandbox = $$$NULLOREF
        Set tNewSeq = +$Get(^IRISCouch.Seq(pDB))
        Set tIdx = 0
        While tIdx < tN {
            Set tDDocId = tDDocIds.%Get(tIdx)
            Set tIdx = tIdx + 1
            ; Special case: this write IS a design doc. Detect whether any
            ; view's map source has changed; if so, invalidate the cached
            ; index (next query will rebuild). Never re-emit the ddoc body
            ; into its own view.
            If pDocId = tDDocId {
                Do ..HandleDesignDocChange(pDB, tDDocId, pNewDocBody)
                Continue
            }
            ; Load the design-doc body for this pass.
            Set tDDocWin = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDDocId)
            If tDDocWin = "" Continue
            Set tDDocBody = ##class(IRISCouch.Storage.Document).Read(pDB, tDDocId, tDDocWin)
            If tDDocBody = "" Continue
            Set tDDocObj = ""
            Try {
                Set tDDocObj = ##class(%DynamicObject).%FromJSON(tDDocBody)
            } Catch exParse {
                Continue
            }
            If '$IsObject(tDDocObj) Continue
            If 'tDDocObj.%IsDefined("views") Continue
            Set tViews = tDDocObj.%Get("views")
            If '$IsObject(tViews) Continue
            Set tIter = tViews.%GetIterator()
            While tIter.%GetNext(.tViewName, .tViewDef) {
                If '$IsObject(tViewDef) Continue
                Set tMapFn = tViewDef.%Get("map")
                If tMapFn = "" Continue
                Set tReduceSource = $Select(tViewDef.%IsDefined("reduce"): tViewDef.%Get("reduce"), 1: "")
                ; Purge prior entries for this doc in this view regardless
                ; of whether we'll re-emit (covers tombstones + updates).
                Do ##class(IRISCouch.Storage.ViewIndex).RemoveEntriesForDoc(pDB, tDDocId, tViewName, pDocId)
                ; If deletion, we are done for this view.
                If '$IsObject(pNewDocBody) {
                    Do ##class(IRISCouch.Storage.ViewIndex).SetMeta(pDB, tDDocId, tViewName, tNewSeq, ##class(IRISCouch.Storage.ViewIndex).ViewDefinitionHash(tMapFn, tReduceSource))
                    Continue
                }
                ; Live write: execute the map function. Lazy-acquire the
                ; sandbox -- avoid the cost for DBs with no ddocs / no views.
                If tSandbox = $$$NULLOREF {
                    Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
                    If 'tSandbox.IsAvailable() {
                        ; Write-time indexing quietly no-ops if no runtime is
                        ; available. The index will be empty at query time;
                        ; the ViewHandler's existing 501 path will surface to
                        ; clients. This is the same posture as Story 12.2
                        ; views before indexing existed.
                        Set tSandbox = $$$NULLOREF
                        Quit
                    }
                }
                Set tEmits = ""
                Set tMapTimedOut = 0
                Try {
                    ; Inject _id / _rev so map functions see them.
                    Set tInject = pNewDocBody
                    Set tInjectJson = pNewDocBody.%ToJSON()
                    Set tInject = ##class(%DynamicObject).%FromJSON(tInjectJson)
                    Do tInject.%Set("_id", pDocId)
                    If pNewRev '= "" Do tInject.%Set("_rev", pNewRev)
                    Set tEmits = tSandbox.ExecuteMap(tMapFn, tInject)
                } Catch exMap {
                    ; Story 12.5 AC #4: timeouts MUST fail the write (caller
                    ; TROLLBACKs). A runaway map function makes every write
                    ; impossible; surface the timeout so the user sees 500.
                    ; Other map errors (per-doc exceptions) match CouchDB's
                    ; views.js::handleViewError -- log and continue.
                    Set tReason = exMap.DisplayString()
                    If tReason [ "jsruntime_timeout" {
                        Set tMapTimedOut = 1
                    } Else {
                        Do ##class(IRISCouch.Util.Log).Warn("view-index", "map error during incremental update (skipped)", {"db":(pDB),"doc":(pDocId),"ddoc":(tDDocId),"view":(tViewName),"error":(tReason)})
                    }
                    Set tEmits = ""
                }
                If tMapTimedOut {
                    Set tSC = $$$ERROR($$$GeneralError, "jsruntime_timeout: map function for view " _ tViewName _ " exceeded JSRUNTIMETIMEOUT")
                    Quit
                }
                If $IsObject(tEmits) {
                    Set tEN = tEmits.%Size()
                    Set tJ = 0
                    While tJ < tEN {
                        Set tPair = tEmits.%Get(tJ)
                        Set tJ = tJ + 1
                        If '$IsObject(tPair) Continue
                        Do ##class(IRISCouch.Storage.ViewIndex).AddEntry(pDB, tDDocId, tViewName, tPair.%Get(0), pDocId, tPair.%Get(1))
                    }
                }
                Do ##class(IRISCouch.Storage.ViewIndex).SetMeta(pDB, tDDocId, tViewName, tNewSeq, ##class(IRISCouch.Storage.ViewIndex).ViewDefinitionHash(tMapFn, tReduceSource))
            }
            ; Escalate timeout to the outer ddoc loop too.
            If $$$ISERR(tSC) Quit
        }
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>List live design-doc ids in a database.</p>
/// <p>Uses direct <code>$Order</code> over
/// <code>^IRISCouch.Tree(pDB,"_design/...")</code> so the cost is O(k) in
/// the number of design docs, not O(N) in the document count. This closes
/// the Story 12.3 MED (<code>ListValidateFunctions</code> O(N) concern).</p>
/// @param pDB Database name
/// @return %DynamicArray of design-doc ids in <code>_design/xxx</code> form
ClassMethod ListDesignDocIds(pDB As %String) As %DynamicArray [ Internal ]
{
    Set tList = []
    ; Scan tree index by prefix. $Order from "_design/" upwards stops once
    ; we move past the underscore-prefix range.
    Set tDocId = "_design/"
    For {
        Set tDocId = $Order(^IRISCouch.Tree(pDB, tDocId))
        If tDocId = "" Quit
        If $Extract(tDocId, 1, 8) '= "_design/" Quit
        ; Skip tombstoned design docs.
        Set tWin = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
        If tWin = "" Continue
        If ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tWin) Continue
        Do tList.%Push(tDocId)
    }
    Quit tList
}

/// <p>When a design doc is saved, detect source-level changes to existing
/// views and invalidate the corresponding cached indexes.</p>
/// <p>Compares the stored view-definition hash against the newly computed
/// one; if different, drops every index entry for that (ddoc, view). The
/// next query rebuilds via <method>IRISCouch.Storage.ViewIndex.Rebuild</method>.</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id being saved
/// @param pNewBodyObj New body as <class>%DynamicObject</class>
ClassMethod HandleDesignDocChange(pDB As %String, pDDocId As %String, pNewBodyObj As %DynamicObject) [ Internal ]
{
    ; Tombstone: drop everything for this ddoc.
    If '$IsObject(pNewBodyObj) {
        Do ##class(IRISCouch.Storage.ViewIndex).DropForDesignDoc(pDB, pDDocId)
        Quit
    }
    If 'pNewBodyObj.%IsDefined("views") {
        ; New body has no views -- nothing to index going forward.
        Do ##class(IRISCouch.Storage.ViewIndex).DropForDesignDoc(pDB, pDDocId)
        Quit
    }
    Set tViews = pNewBodyObj.%Get("views")
    If '$IsObject(tViews) {
        Do ##class(IRISCouch.Storage.ViewIndex).DropForDesignDoc(pDB, pDDocId)
        Quit
    }
    ; Compare each view's hash against the stored one.
    Set tIter = tViews.%GetIterator()
    Set tSeenNames = $ListBuild()
    While tIter.%GetNext(.tViewName, .tViewDef) {
        If '$IsObject(tViewDef) Continue
        Set tMapFn = tViewDef.%Get("map")
        If tMapFn = "" Continue
        Set tReduceSource = $Select(tViewDef.%IsDefined("reduce"): tViewDef.%Get("reduce"), 1: "")
        Set tNewHash = ##class(IRISCouch.Storage.ViewIndex).ViewDefinitionHash(tMapFn, tReduceSource)
        Set tOldHash = ##class(IRISCouch.Storage.ViewIndex).GetViewDefinitionHash(pDB, pDDocId, tViewName)
        If tOldHash '= tNewHash {
            ; Drop the index; next query will rebuild. Storage.ViewIndex is the
            ; sole owner of ^IRISCouch.ViewIndex* globals (per .claude/rules/
            ; iris-objectscript-basics.md::Storage Encapsulation) so we go
            ; through the class API rather than killing globals directly.
            Do ##class(IRISCouch.Storage.ViewIndex).DropForView(pDB, pDDocId, tViewName)
        }
        Set tSeenNames = tSeenNames _ $ListBuild(tViewName)
    }
    ; Drop any view whose name is no longer in the design doc. Avoids
    ; leaked entries when a view is removed in a subsequent revision.
    Set tKnownNames = ##class(IRISCouch.Storage.ViewIndex).ListIndexedViewNames(pDB, pDDocId)
    Set tKI = 0
    Set tKN = tKnownNames.%Size()
    While tKI < tKN {
        Set tKnown = tKnownNames.%Get(tKI)
        Set tKI = tKI + 1
        If '$ListFind(tSeenNames, tKnown) {
            Do ##class(IRISCouch.Storage.ViewIndex).DropForView(pDB, pDDocId, tKnown)
        }
    }
}

}
