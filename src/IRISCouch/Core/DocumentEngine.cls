/// <p>Single write orchestrator for IRISCouch document operations.</p>
/// <p>All document writes MUST go through <method>Save</method> or
/// <method>SaveDeleted</method> to ensure atomicity via
/// <code>TSTART</code>/<code>TCOMMIT</code> (NFR-R2).
/// Coordinates storage, revision tree, changes feed, and metadata updates
/// within a single transaction.</p>
Class IRISCouch.Core.DocumentEngine Extends %RegisteredObject
{

/// <p>Save a document to the database — the single write orchestrator.</p>
/// <p>Wraps all subsystem calls in a <code>TSTART</code>/<code>TCOMMIT</code>
/// transaction to ensure atomicity. On error, performs <code>TROLLBACK</code>.</p>
/// <h4>Transaction steps:</h4>
/// <ol>
/// <li>Write document body via <class>IRISCouch.Storage.Document</class></li>
/// <li>Initialize or extend revision tree via <class>IRISCouch.Storage.RevTree</class></li>
/// <li>Record change in <code>^IRISCouch.Changes</code> feed</li>
/// <li>Update database metadata (<code>doc_count</code>, <code>update_seq</code>)</li>
/// </ol>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pBody The raw JSON body string
/// @param pParentRev The parent revision string (empty for new documents)
/// @return %String The new revision string on success, empty string on failure
ClassMethod Save(pDB As %String, pDocId As %String, pBody As %String, pParentRev As %String = "") As %String
{
    Set tNewRev = ""
    Set tInTrans = 0
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Quit
        }
        ; Determine generation
        If pParentRev = "" {
            Set tGeneration = 1
        } Else {
            Set tGeneration = +$Piece(pParentRev, "-", 1) + 1
        }
        ; Mint new revision
        Set tNewRev = ##class(IRISCouch.Core.RevHash).MintRev(tGeneration, pBody, pParentRev)
        If tNewRev = "" Quit
        ; Begin transaction
        TSTART
        Set tInTrans = 1
        ; 1. Write document body
        Set tSC = ##class(IRISCouch.Storage.Document).Write(pDB, pDocId, tNewRev, pBody)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 2. Update revision tree
        If tGeneration = 1 {
            Set tSC = ##class(IRISCouch.Storage.RevTree).Init(pDB, pDocId, tNewRev)
        } Else {
            Set tSC = ##class(IRISCouch.Storage.RevTree).AddChild(pDB, pDocId, pParentRev, tNewRev)
        }
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 3. Record change in changes feed
        Set tSeq = ##class(IRISCouch.Storage.Changes).RecordChange(pDB, pDocId, tNewRev)
        ; 4. Update database metadata
        If tGeneration = 1 {
            ; Only increment doc_count for new documents
            Do ##class(IRISCouch.Storage.Database).IncrementDocCount(pDB)
        }
        Do ##class(IRISCouch.Storage.Database).SetUpdateSeq(pDB, tSeq)
        ; 5. Update Projection.Winners (Story 6.1)
        Do ##class(IRISCouch.Projection.Winners).Upsert(pDB, pDocId, tNewRev, pBody, 0)
        ; 6. Update MangoIndex projections (Story 6.1)
        Do ##class(IRISCouch.Projection.MangoIndex).DeleteForDocument(pDB, pDocId)
        Set tIndexDefs = ##class(IRISCouch.Projection.MangoIndexDef).GetActiveIndexes(pDB)
        If tIndexDefs.%Size() > 0 {
            Set tBodyObj = ##class(%DynamicObject).%FromJSON(pBody)
            Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument(pDB, pDocId, tBodyObj, tIndexDefs)
        }
        ; 7. _users database sync (Story 7.3)
        ; If this is a _users write, process password hashing and IRIS user sync
        If ##class(IRISCouch.Auth.Users).IsUsersDB(pDB) {
            Set tUserBody = ##class(%DynamicObject).%FromJSON(pBody)
            Set tModified = ##class(IRISCouch.Auth.Users).OnUserDocSave(pDB, pDocId, tUserBody)
            ; If body was modified (password stripped), re-save the modified body
            Set tModifiedJSON = tModified.%ToJSON()
            If tModifiedJSON '= pBody {
                Set tSC = ##class(IRISCouch.Storage.Document).Write(pDB, pDocId, tNewRev, tModifiedJSON)
                If $$$ISERR(tSC) {
                    TROLLBACK  Set tInTrans = 0
                    Set tNewRev = ""
                    Quit
                }
                ; Update Winners projection with the modified body
                Do ##class(IRISCouch.Projection.Winners).Upsert(pDB, pDocId, tNewRev, tModifiedJSON, 0)
                ; Re-index MangoIndex with modified body (password stripped)
                Do ##class(IRISCouch.Projection.MangoIndex).DeleteForDocument(pDB, pDocId)
                Set tIndexDefs2 = ##class(IRISCouch.Projection.MangoIndexDef).GetActiveIndexes(pDB)
                If tIndexDefs2.%Size() > 0 {
                    Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument(pDB, pDocId, tModified, tIndexDefs2)
                }
            }
        }
        ; Commit transaction
        TCOMMIT
        Set tInTrans = 0
        ; Signal longpoll waiters AFTER commit so readers see committed data
        ; Only signal if the event resource exists (created by a longpoll listener)
        Set tEventName = ##class(IRISCouch.Storage.Changes).EventResourceName(pDB)
        If ##class(%SYSTEM.Event).Defined(tEventName) {
            Set tEvtSignal = ##class(%SYSTEM.Event).Signal(tEventName)
        }
        Quit
    }
    Catch ex {
        If tInTrans { TROLLBACK  Set tInTrans = 0 }
        Set tNewRev = ""
        Quit
    }
    Quit tNewRev
}

/// <p>Save a document with a new attachment, creating a new revision.</p>
/// <p>Wraps document write, attachment store, and metadata update in a single
/// <code>TSTART</code>/<code>TCOMMIT</code> transaction. The document body
/// is updated to include <code>_attachments</code> stub metadata.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pParentRev The current revision (required for existing documents)
/// @param pAttName The attachment filename
/// @param pContentType The MIME content type
/// @param pStream The binary stream containing attachment data
/// @return %String The new revision string on success, empty string on failure
ClassMethod SaveAttachment(pDB As %String, pDocId As %String, pParentRev As %String, pAttName As %String, pContentType As %String, pStream As %Stream.GlobalBinary) As %String
{
    Set tNewRev = ""
    Set tInTrans = 0
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Quit
        }
        ; Read existing document body (or create empty one)
        Set tBodyStr = ""
        If pParentRev '= "" {
            Set tBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, pDocId, pParentRev)
        }
        If tBodyStr = "" {
            Set tBodyStr = "{}"
        }
        ; Determine generation
        If pParentRev = "" {
            Set tGeneration = 1
        } Else {
            Set tGeneration = +$Piece(pParentRev, "-", 1) + 1
        }
        ; Mint new revision
        Set tNewRev = ##class(IRISCouch.Core.RevHash).MintRev(tGeneration, tBodyStr, pParentRev)
        If tNewRev = "" Quit
        ; Begin transaction
        TSTART
        Set tInTrans = 1
        ; 1. Store the attachment stream
        Set tSC = ##class(IRISCouch.Storage.Attachment).Store(pDB, pDocId, tNewRev, pAttName, pContentType, pStream, tGeneration, .tDigest, .tLength)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 2. Copy forward any existing attachments from previous rev
        If pParentRev '= "" {
            Set tSC = ##class(IRISCouch.Storage.Attachment).CopyAttachments(pDB, pDocId, pParentRev, tNewRev, pAttName)
            If $$$ISERR(tSC) {
                TROLLBACK  Set tInTrans = 0
                Set tNewRev = ""
                Quit
            }
        }
        ; 3. Write document body (same body, new rev)
        Set tSC = ##class(IRISCouch.Storage.Document).Write(pDB, pDocId, tNewRev, tBodyStr)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 4. Update revision tree
        If tGeneration = 1 {
            Set tSC = ##class(IRISCouch.Storage.RevTree).Init(pDB, pDocId, tNewRev)
        } Else {
            Set tSC = ##class(IRISCouch.Storage.RevTree).AddChild(pDB, pDocId, pParentRev, tNewRev)
        }
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 5. Record change in changes feed
        Set tSeq = ##class(IRISCouch.Storage.Changes).RecordChange(pDB, pDocId, tNewRev)
        ; 6. Update database metadata
        If tGeneration = 1 {
            Do ##class(IRISCouch.Storage.Database).IncrementDocCount(pDB)
        }
        Do ##class(IRISCouch.Storage.Database).SetUpdateSeq(pDB, tSeq)
        ; 7. Update Projection.Winners (Story 6.1) — body unchanged for attachment ops
        Do ##class(IRISCouch.Projection.Winners).Upsert(pDB, pDocId, tNewRev, tBodyStr, 0)
        ; 8. Update MangoIndex projections (Story 6.1)
        Do ##class(IRISCouch.Projection.MangoIndex).DeleteForDocument(pDB, pDocId)
        Set tIndexDefs = ##class(IRISCouch.Projection.MangoIndexDef).GetActiveIndexes(pDB)
        If tIndexDefs.%Size() > 0 {
            Set tBodyObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
            Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument(pDB, pDocId, tBodyObj, tIndexDefs)
        }
        ; Commit transaction
        TCOMMIT
        Set tInTrans = 0
        ; Signal longpoll waiters AFTER commit
        Set tEventName = ##class(IRISCouch.Storage.Changes).EventResourceName(pDB)
        If ##class(%SYSTEM.Event).Defined(tEventName) {
            Set tEvtSignal = ##class(%SYSTEM.Event).Signal(tEventName)
        }
        Quit
    }
    Catch ex {
        If tInTrans { TROLLBACK  Set tInTrans = 0 }
        Set tNewRev = ""
        Quit
    }
    Quit tNewRev
}

/// <p>Delete an attachment from a document, creating a new revision.</p>
/// <p>Creates a new revision that carries forward all attachments except
/// the deleted one. The document body is preserved.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pParentRev The current revision (required)
/// @param pAttName The attachment filename to delete
/// @return %String The new revision string on success, empty string on failure
ClassMethod DeleteAttachment(pDB As %String, pDocId As %String, pParentRev As %String, pAttName As %String) As %String
{
    Set tNewRev = ""
    Set tInTrans = 0
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Quit
        }
        ; Read existing document body
        Set tBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, pDocId, pParentRev)
        If tBodyStr = "" {
            Set tBodyStr = "{}"
        }
        ; Determine generation
        Set tGeneration = +$Piece(pParentRev, "-", 1) + 1
        ; Mint new revision
        Set tNewRev = ##class(IRISCouch.Core.RevHash).MintRev(tGeneration, tBodyStr, pParentRev)
        If tNewRev = "" Quit
        ; Begin transaction
        TSTART
        Set tInTrans = 1
        ; 1. Copy forward all attachments except the deleted one
        Set tSC = ##class(IRISCouch.Storage.Attachment).CopyAttachments(pDB, pDocId, pParentRev, tNewRev, pAttName)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 2. Write document body (same body, new rev)
        Set tSC = ##class(IRISCouch.Storage.Document).Write(pDB, pDocId, tNewRev, tBodyStr)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 3. Update revision tree
        Set tSC = ##class(IRISCouch.Storage.RevTree).AddChild(pDB, pDocId, pParentRev, tNewRev)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 4. Record change in changes feed
        Set tSeq = ##class(IRISCouch.Storage.Changes).RecordChange(pDB, pDocId, tNewRev)
        ; 5. Update database metadata
        Do ##class(IRISCouch.Storage.Database).SetUpdateSeq(pDB, tSeq)
        ; 6. Update Projection.Winners (Story 6.1) — body unchanged for attachment ops
        Do ##class(IRISCouch.Projection.Winners).Upsert(pDB, pDocId, tNewRev, tBodyStr, 0)
        ; 7. Update MangoIndex projections (Story 6.1)
        Do ##class(IRISCouch.Projection.MangoIndex).DeleteForDocument(pDB, pDocId)
        Set tIndexDefs = ##class(IRISCouch.Projection.MangoIndexDef).GetActiveIndexes(pDB)
        If tIndexDefs.%Size() > 0 {
            Set tBodyObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
            Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument(pDB, pDocId, tBodyObj, tIndexDefs)
        }
        ; Commit transaction
        TCOMMIT
        Set tInTrans = 0
        ; Signal longpoll waiters AFTER commit
        Set tEventName = ##class(IRISCouch.Storage.Changes).EventResourceName(pDB)
        If ##class(%SYSTEM.Event).Defined(tEventName) {
            Set tEvtSignal = ##class(%SYSTEM.Event).Signal(tEventName)
        }
        Quit
    }
    Catch ex {
        If tInTrans { TROLLBACK  Set tInTrans = 0 }
        Set tNewRev = ""
        Quit
    }
    Quit tNewRev
}

/// <p>Delete a document by creating a tombstone revision.</p>
/// <p>Creates a new revision with <code>{"_deleted":true}</code> as the body,
/// marks the leaf as deleted in the revision tree, decrements
/// <code>doc_count</code>, and increments <code>doc_del_count</code>.</p>
/// <h4>Transaction steps:</h4>
/// <ol>
/// <li>Mint tombstone revision with pDeleted=1</li>
/// <li>Write tombstone body</li>
/// <li>Mark leaf as deleted in revision tree</li>
/// <li>Extend revision tree (AddChild recomputes winner with deletion awareness)</li>
/// <li>Record change in changes feed</li>
/// <li>Update database metadata (decrement doc_count, increment doc_del_count)</li>
/// </ol>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pParentRev The parent revision string (must be the current winner)
/// @return %String The new tombstone revision string on success, empty string on failure
ClassMethod SaveDeleted(pDB As %String, pDocId As %String, pParentRev As %String) As %String
{
    Set tNewRev = ""
    Set tInTrans = 0
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Quit
        }
        ; Determine generation from parent
        Set tGeneration = +$Piece(pParentRev, "-", 1) + 1
        ; Tombstone body
        Set tTombstoneBody = "{""_deleted"":true}"
        ; Mint rev with pDeleted=1
        Set tNewRev = ##class(IRISCouch.Core.RevHash).MintRev(tGeneration, tTombstoneBody, pParentRev, 1)
        If tNewRev = "" Quit
        ; Begin transaction
        TSTART
        Set tInTrans = 1
        ; 1. Write tombstone body
        Set tSC = ##class(IRISCouch.Storage.Document).Write(pDB, pDocId, tNewRev, tTombstoneBody)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 2. Mark leaf as deleted BEFORE AddChild so RecomputeWinner sees it
        Set tSC = ##class(IRISCouch.Storage.RevTree).MarkDeleted(pDB, pDocId, tNewRev)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 3. Extend revision tree (AddChild calls RecomputeWinner internally)
        Set tSC = ##class(IRISCouch.Storage.RevTree).AddChild(pDB, pDocId, pParentRev, tNewRev)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 4. Record change in changes feed
        Set tSeq = ##class(IRISCouch.Storage.Changes).RecordChange(pDB, pDocId, tNewRev)
        ; 5. Update database metadata
        ; Decrement doc_count
        Do ##class(IRISCouch.Storage.Database).IncrementDocCount(pDB, -1)
        ; Increment doc_del_count
        Do ##class(IRISCouch.Storage.Database).IncrementDelCount(pDB)
        Do ##class(IRISCouch.Storage.Database).SetUpdateSeq(pDB, tSeq)
        ; 6. Update Projection.Winners with deletion (Story 6.1)
        Do ##class(IRISCouch.Projection.Winners).Upsert(pDB, pDocId, tNewRev, "", 1)
        ; 7. Remove from all MangoIndex rows (Story 6.1)
        Do ##class(IRISCouch.Projection.MangoIndex).DeleteForDocument(pDB, pDocId)
        ; 8. _users database sync (Story 7.3)
        ; If this is a _users delete, remove the corresponding IRIS user
        If ##class(IRISCouch.Auth.Users).IsUsersDB(pDB) {
            Do ##class(IRISCouch.Auth.Users).OnUserDocDelete(pDB, pDocId)
        }
        ; Commit transaction
        TCOMMIT
        Set tInTrans = 0
        ; Signal longpoll waiters AFTER commit so readers see committed data
        ; Only signal if the event resource exists (created by a longpoll listener)
        Set tEventName = ##class(IRISCouch.Storage.Changes).EventResourceName(pDB)
        If ##class(%SYSTEM.Event).Defined(tEventName) {
            Set tEvtSignal = ##class(%SYSTEM.Event).Signal(tEventName)
        }
        Quit
    }
    Catch ex {
        If tInTrans { TROLLBACK  Set tInTrans = 0 }
        Set tNewRev = ""
        Quit
    }
    Quit tNewRev
}

/// <p>Save a document with externally-provided revision history (replication mode).</p>
/// <p>Used by <code>new_edits=false</code> bulk writes to graft external revision
/// histories into the local database. The server acts as a passive receiver:
/// no revision minting, no conflict checking. The provided <code>_rev</code> is
/// stored as-is, and the <code>_revisions</code> ancestry chain is grafted into
/// the revision tree.</p>
/// <h4>Transaction steps:</h4>
/// <ol>
/// <li>Check idempotency — if rev already exists in tree, skip silently</li>
/// <li>Build ancestry chain from _revisions object</li>
/// <li>Write document body for the leaf revision</li>
/// <li>Graft ancestry chain via <method>RevTree.GraftChain</method></li>
/// <li>Record change in changes feed</li>
/// <li>Update doc_count (only for genuinely new documents)</li>
/// <li>Update update_seq</li>
/// </ol>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pBody The raw JSON body string (metadata fields already stripped)
/// @param pRev The exact revision string to store (not minted by server)
/// @param pRevisions The _revisions object: {"start":N,"ids":["hash1","hash2",...]}
/// @param pDeleted Whether this is a deletion tombstone
/// @return %Status
ClassMethod SaveWithHistory(pDB As %String, pDocId As %String, pBody As %String, pRev As %String, pRevisions As %DynamicObject = "", pDeleted As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    Set tInTrans = 0
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Set tSC = $$$ERROR($$$GeneralError, "Database does not exist")
            Quit
        }
        ; Idempotency check: if rev already exists in tree, skip silently
        If ##class(IRISCouch.Storage.RevTree).RevExists(pDB, pDocId, pRev) {
            Quit
        }
        ; Build ancestry chain from _revisions object
        Set tRevChain = []
        If $IsObject(pRevisions) && pRevisions.%IsDefined("start") && pRevisions.%IsDefined("ids") {
            Set tStart = pRevisions.%Get("start")
            Set tIds = pRevisions.%Get("ids")
            Set tIdCount = tIds.%Size()
            ; Build from oldest to newest: ids are newest-first, so reverse
            For tI = (tIdCount - 1):-1:0 {
                Set tGen = tStart - tI
                Set tHash = tIds.%Get(tI)
                Do tRevChain.%Push(tGen _ "-" _ tHash)
            }
        } Else {
            ; No _revisions — treat as single-node tree (root and only revision)
            Do tRevChain.%Push(pRev)
        }
        ; Check if this is a genuinely new document (no prior tree existed)
        Set tIsNewDoc = '##class(IRISCouch.Storage.RevTree).TreeExists(pDB, pDocId)
        ; Begin transaction
        TSTART
        Set tInTrans = 1
        ; 1. Write document body for the leaf rev
        Set tSC = ##class(IRISCouch.Storage.Document).Write(pDB, pDocId, pRev, pBody)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Quit
        }
        ; 2. Graft the ancestry chain into the rev tree
        Set tSC = ##class(IRISCouch.Storage.RevTree).GraftChain(pDB, pDocId, tRevChain, pRev, pDeleted)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Quit
        }
        ; 3. Record change in changes feed
        Set tSeq = ##class(IRISCouch.Storage.Changes).RecordChange(pDB, pDocId, pRev)
        ; 4. Update doc_count only if genuinely new document
        If tIsNewDoc {
            Do ##class(IRISCouch.Storage.Database).IncrementDocCount(pDB)
        }
        ; 5. Update update_seq
        Do ##class(IRISCouch.Storage.Database).SetUpdateSeq(pDB, tSeq)
        ; 6. Update Projection.Winners (Story 6.1)
        ; Determine the winning rev after graft
        Set tCurrentWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDocId)
        If tCurrentWinner '= "" {
            If pDeleted && (tCurrentWinner = pRev) {
                Do ##class(IRISCouch.Projection.Winners).Upsert(pDB, pDocId, tCurrentWinner, "", 1)
                Do ##class(IRISCouch.Projection.MangoIndex).DeleteForDocument(pDB, pDocId)
            } Else {
                ; Get the winning body
                Set tWinBody = ##class(IRISCouch.Storage.Document).Read(pDB, pDocId, tCurrentWinner)
                Do ##class(IRISCouch.Projection.Winners).Upsert(pDB, pDocId, tCurrentWinner, tWinBody, 0)
                ; Re-index for mango
                Do ##class(IRISCouch.Projection.MangoIndex).DeleteForDocument(pDB, pDocId)
                Set tIndexDefs = ##class(IRISCouch.Projection.MangoIndexDef).GetActiveIndexes(pDB)
                If tIndexDefs.%Size() > 0 && (tWinBody '= "") {
                    Set tBodyObj = ##class(%DynamicObject).%FromJSON(tWinBody)
                    Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument(pDB, pDocId, tBodyObj, tIndexDefs)
                }
            }
        }
        ; Commit transaction
        TCOMMIT
        Set tInTrans = 0
        ; Signal longpoll waiters AFTER commit so readers see committed data
        ; Only signal if the event resource exists (created by a longpoll listener)
        Set tEventName = ##class(IRISCouch.Storage.Changes).EventResourceName(pDB)
        If ##class(%SYSTEM.Event).Defined(tEventName) {
            Set tEvtSignal = ##class(%SYSTEM.Event).Signal(tEventName)
        }
        Quit
    }
    Catch ex {
        If tInTrans { TROLLBACK  Set tInTrans = 0 }
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Save a document with multiple inline attachments atomically.</p>
/// <p>Handles both new attachments (with base64 <code>"data"</code> field) and
/// stub attachments (<code>"stub":true</code>) carried forward from a previous
/// revision. All operations occur within a single
/// <code>TSTART</code>/<code>TCOMMIT</code> transaction.</p>
/// <h4>Transaction steps:</h4>
/// <ol>
/// <li>Write document body (without <code>_attachments</code> data fields)</li>
/// <li>Update revision tree</li>
/// <li>For each new attachment: base64-decode and store via Storage.Attachment</li>
/// <li>For stub attachments: copy forward from previous revision</li>
/// <li>Record change in changes feed</li>
/// <li>Update database metadata</li>
/// </ol>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pBody The raw JSON body string (without _attachments data)
/// @param pParentRev The parent revision string (empty for new documents)
/// @param pAttachments The _attachments %DynamicObject with data and/or stub entries
/// @return %String The new revision string on success, empty string on failure
ClassMethod SaveWithAttachments(pDB As %String, pDocId As %String, pBody As %String, pParentRev As %String = "", pAttachments As %DynamicObject = "") As %String
{
    Set tNewRev = ""
    Set tInTrans = 0
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Quit
        }
        ; Validate attachments object
        If '$IsObject(pAttachments) {
            Quit
        }
        ; Determine generation
        If pParentRev = "" {
            Set tGeneration = 1
        } Else {
            Set tGeneration = +$Piece(pParentRev, "-", 1) + 1
        }
        ; Mint new revision
        Set tNewRev = ##class(IRISCouch.Core.RevHash).MintRev(tGeneration, pBody, pParentRev)
        If tNewRev = "" Quit
        ; Begin transaction
        TSTART
        Set tInTrans = 1
        ; 1. Write document body (without _attachments data fields)
        Set tSC = ##class(IRISCouch.Storage.Document).Write(pDB, pDocId, tNewRev, pBody)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 2. Update revision tree
        If tGeneration = 1 {
            Set tSC = ##class(IRISCouch.Storage.RevTree).Init(pDB, pDocId, tNewRev)
        } Else {
            Set tSC = ##class(IRISCouch.Storage.RevTree).AddChild(pDB, pDocId, pParentRev, tNewRev)
        }
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 3. Process each attachment
        ; Build delimited list of stub attachment names to copy forward
        Set tStubNames = ""
        Set tIter = pAttachments.%GetIterator()
        While tIter.%GetNext(.tAttName, .tAttObj) {
            If '$IsObject(tAttObj) Continue
            If $IsObject(tAttObj.%Get("_stream")) {
                ; Stream-based attachment (from multipart upload path — no base64 round-trip)
                Set tStream = tAttObj.%Get("_stream")
                Set tContentType = tAttObj.%Get("content_type")
                If tContentType = "" Set tContentType = "application/octet-stream"
                Do tStream.Rewind()
                ; Store via Storage.Attachment — stream passed directly
                Set tSC = ##class(IRISCouch.Storage.Attachment).Store(pDB, pDocId, tNewRev, tAttName, tContentType, tStream, tGeneration, .tDigest, .tLength)
                If $$$ISERR(tSC) {
                    TROLLBACK  Set tInTrans = 0
                    Set tNewRev = ""
                    Quit
                }
            } ElseIf tAttObj.%Get("data") '= "" {
                ; New attachment with base64 data
                Set tBase64 = tAttObj.%Get("data")
                Set tContentType = tAttObj.%Get("content_type")
                If tContentType = "" Set tContentType = "application/octet-stream"
                ; Base64 decode
                Set tBinary = $System.Encryption.Base64Decode(tBase64)
                If tBinary = "" {
                    ; Invalid base64 — rollback
                    TROLLBACK  Set tInTrans = 0
                    Set tNewRev = ""
                    Quit
                }
                ; Create stream from decoded data
                Set tStream = ##class(%Stream.GlobalBinary).%New()
                Do tStream.Write(tBinary)
                Do tStream.Rewind()
                ; Store via Storage.Attachment
                Set tSC = ##class(IRISCouch.Storage.Attachment).Store(pDB, pDocId, tNewRev, tAttName, tContentType, tStream, tGeneration, .tDigest, .tLength)
                If $$$ISERR(tSC) {
                    TROLLBACK  Set tInTrans = 0
                    Set tNewRev = ""
                    Quit
                }
            } ElseIf tAttObj.%Get("stub") = 1 || (tAttObj.%Get("stub") = "true") {
                ; Stub attachment — carry forward from previous rev
                Set tStubNames = tStubNames _ $Select(tStubNames'="":"||", 1:"") _ tAttName
            } ElseIf tAttObj.%Get("follows") = 1 || (tAttObj.%Get("follows") = "true") {
                ; Multipart "follows" marker — handled by caller who provides streams
                ; Skip here; caller should have replaced "follows" with "data" or stream
                Continue
            }
        }
        ; Check if we had a rollback from the inner loop
        If tNewRev = "" Quit
        ; 4. Copy forward stub attachments from previous revision
        ; Uses Storage.Attachment.CopyStubByName to preserve encapsulation
        If (pParentRev '= "") && (tStubNames '= "") {
            ; Iterate the delimited stub list and copy each one individually
            Set tStubCount = $Length(tStubNames, "||")
            For tSI = 1:1:tStubCount {
                Set tStubName = $Piece(tStubNames, "||", tSI)
                If tStubName = "" Continue
                Set tSC = ##class(IRISCouch.Storage.Attachment).CopyOneAttachment(pDB, pDocId, pParentRev, tNewRev, tStubName)
                If $$$ISERR(tSC) {
                    TROLLBACK  Set tInTrans = 0
                    Set tNewRev = ""
                    Quit
                }
            }
            ; Check if rollback occurred in the loop
            If tNewRev = "" Quit
        }
        ; 5. Record change in changes feed
        Set tSeq = ##class(IRISCouch.Storage.Changes).RecordChange(pDB, pDocId, tNewRev)
        ; 6. Update database metadata
        If tGeneration = 1 {
            Do ##class(IRISCouch.Storage.Database).IncrementDocCount(pDB)
        }
        Do ##class(IRISCouch.Storage.Database).SetUpdateSeq(pDB, tSeq)
        ; 7. Update Projection.Winners (Story 6.1)
        Do ##class(IRISCouch.Projection.Winners).Upsert(pDB, pDocId, tNewRev, pBody, 0)
        ; 8. Update MangoIndex projections (Story 6.1)
        Do ##class(IRISCouch.Projection.MangoIndex).DeleteForDocument(pDB, pDocId)
        Set tIndexDefs = ##class(IRISCouch.Projection.MangoIndexDef).GetActiveIndexes(pDB)
        If tIndexDefs.%Size() > 0 {
            Set tBodyObj = ##class(%DynamicObject).%FromJSON(pBody)
            Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument(pDB, pDocId, tBodyObj, tIndexDefs)
        }
        ; Commit transaction
        TCOMMIT
        Set tInTrans = 0
        ; Signal longpoll waiters AFTER commit
        Set tEventName = ##class(IRISCouch.Storage.Changes).EventResourceName(pDB)
        If ##class(%SYSTEM.Event).Defined(tEventName) {
            Set tEvtSignal = ##class(%SYSTEM.Event).Signal(tEventName)
        }
        Quit
    }
    Catch ex {
        If tInTrans { TROLLBACK  Set tInTrans = 0 }
        Set tNewRev = ""
        Quit
    }
    Quit tNewRev
}

}
