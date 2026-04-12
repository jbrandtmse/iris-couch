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
        Set tSeq = $Increment(^IRISCouch.Seq(pDB))
        Set ^IRISCouch.Changes(pDB, tSeq) = $ListBuild(pDocId, tNewRev)
        ; 4. Update database metadata
        If tGeneration = 1 {
            ; Only increment doc_count for new documents
            Set tCount = $Increment(^IRISCouch.DB(pDB, "doc_count"))
        }
        Set ^IRISCouch.DB(pDB, "update_seq") = tSeq
        ; Commit transaction
        TCOMMIT
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
        Set ^IRISCouch.Tree(pDB, pDocId, "D", tNewRev) = 1
        ; 3. Extend revision tree (AddChild calls RecomputeWinner internally)
        Set tSC = ##class(IRISCouch.Storage.RevTree).AddChild(pDB, pDocId, pParentRev, tNewRev)
        If $$$ISERR(tSC) {
            TROLLBACK  Set tInTrans = 0
            Set tNewRev = ""
            Quit
        }
        ; 4. Record change in changes feed
        Set tSeq = $Increment(^IRISCouch.Seq(pDB))
        Set ^IRISCouch.Changes(pDB, tSeq) = $ListBuild(pDocId, tNewRev)
        ; 5. Update database metadata
        ; Decrement doc_count
        Set tCount = $Increment(^IRISCouch.DB(pDB, "doc_count"), -1)
        ; Increment doc_del_count
        Set tDelCount = $Increment(^IRISCouch.DB(pDB, "doc_del_count"))
        Set ^IRISCouch.DB(pDB, "update_seq") = tSeq
        ; Commit transaction
        TCOMMIT
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
        If $Data(^IRISCouch.Tree(pDB, pDocId, "R", pRev)) > 0 {
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
        Set tIsNewDoc = '$Data(^IRISCouch.Tree(pDB, pDocId))
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
        Set tSeq = $Increment(^IRISCouch.Seq(pDB))
        Set ^IRISCouch.Changes(pDB, tSeq) = $ListBuild(pDocId, pRev)
        ; 4. Update doc_count only if genuinely new document
        If tIsNewDoc {
            Set tCount = $Increment(^IRISCouch.DB(pDB, "doc_count"))
        }
        ; 5. Update update_seq
        Set ^IRISCouch.DB(pDB, "update_seq") = tSeq
        ; Commit transaction
        TCOMMIT
        Set tInTrans = 0
        Quit
    }
    Catch ex {
        If tInTrans { TROLLBACK  Set tInTrans = 0 }
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

}
