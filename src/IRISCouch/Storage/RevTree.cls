/// <p>Storage layer for IRISCouch revision tree operations.</p>
/// <p>Manages the revision tree structure stored in <code>^IRISCouch.Tree</code>.
/// Tracks parent-child revision relationships, leaf nodes with depth,
/// deleted leaf markers, and the cached winning revision.</p>
/// <h4>Global Structure:</h4>
/// <ul>
/// <li><code>^IRISCouch.Tree(db, docId, "R", rev)</code> - Child to parent pointer (empty string for root)</li>
/// <li><code>^IRISCouch.Tree(db, docId, "L", rev)</code> - Leaf node with depth value</li>
/// <li><code>^IRISCouch.Tree(db, docId, "D", rev)</code> - Deleted leaf marker (1 if deleted)</li>
/// <li><code>^IRISCouch.Tree(db, docId, "W")</code> - Cached winning revision</li>
/// </ul>
Class IRISCouch.Storage.RevTree Extends %RegisteredObject
{

/// <p>Initialize a new revision tree for a newly created document.</p>
/// <p>Sets up the root revision with no parent, marks it as a leaf at depth 1,
/// and caches it as the winning revision.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The initial revision string (e.g., "1-abc123...")
/// @return %Status
ClassMethod Init(pDB As %String, pDocId As %String, pRev As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Root revision has no parent
        Set ^IRISCouch.Tree(pDB, pDocId, "R", pRev) = ""
        ; Leaf at depth 1
        Set ^IRISCouch.Tree(pDB, pDocId, "L", pRev) = 1
        ; Winner is the only revision
        Set ^IRISCouch.Tree(pDB, pDocId, "W") = pRev
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Add a child revision to an existing revision tree.</p>
/// <p>Records the parent-child relationship, removes the parent from leaf index,
/// adds the child as a new leaf at parent depth + 1, and recomputes the winner.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pParentRev The parent revision string
/// @param pChildRev The new child revision string
/// @return %Status
ClassMethod AddChild(pDB As %String, pDocId As %String, pParentRev As %String, pChildRev As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Record parent pointer
        Set ^IRISCouch.Tree(pDB, pDocId, "R", pChildRev) = pParentRev
        ; Get parent depth
        Set tParentDepth = +$Get(^IRISCouch.Tree(pDB, pDocId, "L", pParentRev))
        ; Remove parent from leaf index
        Kill ^IRISCouch.Tree(pDB, pDocId, "L", pParentRev)
        ; Also remove parent deleted marker if it had one (no longer a leaf)
        Kill ^IRISCouch.Tree(pDB, pDocId, "D", pParentRev)
        ; Add child as leaf at parent depth + 1
        Set ^IRISCouch.Tree(pDB, pDocId, "L", pChildRev) = tParentDepth + 1
        ; Recompute winner
        Set tSC = ..RecomputeWinner(pDB, pDocId)
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Add a branch revision to an existing revision tree without removing the parent from the leaf index.</p>
/// <p>Unlike <method>AddChild</method>, this method keeps the parent as a leaf node, creating a
/// conflict branch. Used by replication (<code>new_edits=false</code>) and for test setup.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pParentRev The parent revision string
/// @param pChildRev The new child revision string
/// @return %Status
ClassMethod AddBranch(pDB As %String, pDocId As %String, pParentRev As %String, pChildRev As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Record parent pointer
        Set ^IRISCouch.Tree(pDB, pDocId, "R", pChildRev) = pParentRev
        ; Get parent depth — check leaf index first, then walk R-chain if not a leaf
        Set tParentDepth = +$Get(^IRISCouch.Tree(pDB, pDocId, "L", pParentRev))
        If tParentDepth = 0 {
            ; Parent is not a leaf — compute depth by walking R-chain
            Set tWalkRev = pParentRev
            Set tParentDepth = 0
            For {
                Quit:tWalkRev=""
                Set tParentDepth = tParentDepth + 1
                Set tWalkRev = $Get(^IRISCouch.Tree(pDB, pDocId, "R", tWalkRev))
            }
        }
        ; Add child as leaf at parent depth + 1 (do NOT remove parent from leaf index)
        Set ^IRISCouch.Tree(pDB, pDocId, "L", pChildRev) = tParentDepth + 1
        ; Recompute winner
        Set tSC = ..RecomputeWinner(pDB, pDocId)
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Mark a leaf revision as deleted in the revision tree.</p>
/// <p>Sets the D-marker for the specified revision.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision string to mark as deleted
/// @return %Status
ClassMethod MarkDeleted(pDB As %String, pDocId As %String, pRev As %String) As %Status
{
    Set ^IRISCouch.Tree(pDB, pDocId, "D", pRev) = 1
    Quit $$$OK
}

/// <p>Check if a revision exists in the revision tree (has an R-node).</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision string to check
/// @return %Boolean 1 if the revision exists, 0 otherwise
ClassMethod RevExists(pDB As %String, pDocId As %String, pRev As %String) As %Boolean
{
    Quit $Data(^IRISCouch.Tree(pDB, pDocId, "R", pRev)) > 0
}

/// <p>Check if a revision tree exists for a document.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %Boolean 1 if the tree exists, 0 otherwise
ClassMethod TreeExists(pDB As %String, pDocId As %String) As %Boolean
{
    Quit $Data(^IRISCouch.Tree(pDB, pDocId)) > 0
}

/// <p>Check if a revision is marked as deleted.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision string
/// @return %Boolean 1 if deleted, 0 otherwise
ClassMethod IsDeleted(pDB As %String, pDocId As %String, pRev As %String) As %Boolean
{
    Quit +$Get(^IRISCouch.Tree(pDB, pDocId, "D", pRev))
}

/// <p>Get the winning revision for a document.</p>
/// <p>Returns the cached winning revision from <code>^IRISCouch.Tree(pDB, pDocId, "W")</code>.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %String The winning revision string, or "" if no tree exists
ClassMethod GetWinner(pDB As %String, pDocId As %String) As %String
{
    Quit $Get(^IRISCouch.Tree(pDB, pDocId, "W"))
}

/// <p>Get all non-winning, non-deleted leaf revisions (conflicts).</p>
/// <p>Returns a <class>%DynamicArray</class> of revision strings that are leaves,
/// not the winner, and not deleted. Empty array if no conflicts.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %DynamicArray Array of conflicting revision strings
ClassMethod GetConflicts(pDB As %String, pDocId As %String) As %DynamicArray
{
    Set tConflicts = []
    Set tWinner = ..GetWinner(pDB, pDocId)
    Set tRev = ""
    For {
        Set tRev = $Order(^IRISCouch.Tree(pDB, pDocId, "L", tRev))
        Quit:tRev=""
        ; Skip the winner
        If tRev = tWinner Continue
        ; Skip deleted leaves
        If +$Get(^IRISCouch.Tree(pDB, pDocId, "D", tRev)) Continue
        Do tConflicts.%Push(tRev)
    }
    Quit tConflicts
}

/// <p>Get the revision history path from a specific revision to the root.</p>
/// <p>Returns a <class>%DynamicObject</class> with <code>start</code> (generation integer)
/// and <code>ids</code> (array of hex hashes from newest to oldest).</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision to trace from
/// @return %DynamicObject {"start":N,"ids":["hash1","hash2",...]}
ClassMethod GetRevisions(pDB As %String, pDocId As %String, pRev As %String) As %DynamicObject
{
    Set tIds = []
    Set tRev = pRev
    For {
        Quit:tRev=""
        Do tIds.%Push($Piece(tRev, "-", 2))
        Set tRev = $Get(^IRISCouch.Tree(pDB, pDocId, "R", tRev))
    }
    Set tResult = {}
    Do tResult.%Set("start", +$Piece(pRev, "-", 1), "number")
    Do tResult.%Set("ids", tIds)
    Quit tResult
}

/// <p>Get revision info with status for each revision in the path.</p>
/// <p>Returns a <class>%DynamicArray</class> of objects with <code>rev</code> and
/// <code>status</code> (<code>available</code>, <code>deleted</code>, or <code>missing</code>).</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision to trace from
/// @return %DynamicArray [{"rev":"N-hash","status":"available|missing|deleted"},...]
ClassMethod GetRevsInfo(pDB As %String, pDocId As %String, pRev As %String) As %DynamicArray
{
    Set tResult = []
    Set tRev = pRev
    For {
        Quit:tRev=""
        Set tInfo = {}
        Do tInfo.%Set("rev", tRev)
        ; Determine status
        If +$Get(^IRISCouch.Tree(pDB, pDocId, "D", tRev)) {
            Do tInfo.%Set("status", "deleted")
        } ElseIf ##class(IRISCouch.Storage.Document).DocumentExists(pDB, pDocId, tRev) {
            Do tInfo.%Set("status", "available")
        } Else {
            Do tInfo.%Set("status", "missing")
        }
        Do tResult.%Push(tInfo)
        Set tRev = $Get(^IRISCouch.Tree(pDB, pDocId, "R", tRev))
    }
    Quit tResult
}

/// <p>Get all leaf revision strings (including deleted).</p>
/// <p>Returns a <class>%DynamicArray</class> of all leaf revision strings.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %DynamicArray Array of all leaf revision strings
ClassMethod GetLeafRevs(pDB As %String, pDocId As %String) As %DynamicArray
{
    Set tLeaves = []
    Set tRev = ""
    For {
        Set tRev = $Order(^IRISCouch.Tree(pDB, pDocId, "L", tRev))
        Quit:tRev=""
        Do tLeaves.%Push(tRev)
    }
    Quit tLeaves
}

/// <p>Recompute and cache the winning revision for a document.</p>
/// <p>Iterates all leaf nodes in <code>^IRISCouch.Tree(pDB, pDocId, "L")</code>
/// and selects the winner by CouchDB algorithm:
/// (1) live beats deleted, (2) highest depth, (3) lexicographic rev hash tiebreak.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %Status
ClassMethod RecomputeWinner(pDB As %String, pDocId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tWinnerRev = ""
        Set tWinnerDepth = 0
        Set tWinnerDeleted = 1
        ; Iterate all leaf nodes
        Set tRev = ""
        For {
            Set tRev = $Order(^IRISCouch.Tree(pDB, pDocId, "L", tRev))
            Quit:tRev=""
            Set tDepth = +$Get(^IRISCouch.Tree(pDB, pDocId, "L", tRev))
            Set tDeleted = +$Get(^IRISCouch.Tree(pDB, pDocId, "D", tRev))
            ; Winner selection: live beats deleted, then depth, then lex tiebreak
            If (tWinnerRev = "") || ('tDeleted && tWinnerDeleted) || ((tDeleted = tWinnerDeleted) && ((tDepth > tWinnerDepth) || ((tDepth = tWinnerDepth) && (tRev ] tWinnerRev)))) {
                Set tWinnerRev = tRev
                Set tWinnerDepth = tDepth
                Set tWinnerDeleted = tDeleted
            }
        }
        Set ^IRISCouch.Tree(pDB, pDocId, "W") = tWinnerRev
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Graft an external revision ancestry chain into the revision tree.</p>
/// <p>Used by replication (<code>new_edits=false</code>) to insert a chain of
/// revisions from a remote source. Each revision in the chain is added as an
/// R-node if it does not already exist (idempotent). The leaf revision is
/// marked in the L-index and optionally marked as deleted.</p>
/// <h4>Algorithm:</h4>
/// <ol>
/// <li>For each rev in chain (oldest to newest), create R-node if missing</li>
/// <li>Remove parent-of-leaf from L-index if it was a leaf (it has a child now)</li>
/// <li>Set new leaf entry with depth = chain length</li>
/// <li>If deleted, set D marker on the leaf</li>
/// <li>Recompute the winner</li>
/// </ol>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRevChain A %DynamicArray of rev strings from oldest to newest (e.g., ["1-a","2-b","3-c"])
/// @param pLeafRev The leaf revision string (last element in chain)
/// @param pDeleted Whether the leaf is a deletion tombstone
/// @return %Status
ClassMethod GraftChain(pDB As %String, pDocId As %String, pRevChain As %DynamicArray, pLeafRev As %String, pDeleted As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tLen = pRevChain.%Size()
        ; Graft each revision in the chain (oldest to newest)
        For tI = 0:1:(tLen - 1) {
            Set tRev = pRevChain.%Get(tI)
            ; Skip if R-node already exists (idempotent graft)
            If $Data(^IRISCouch.Tree(pDB, pDocId, "R", tRev)) > 0 {
                Continue
            }
            ; Parent is previous rev in chain, or empty for root
            If tI > 0 {
                Set tParentRev = pRevChain.%Get(tI - 1)
            } Else {
                Set tParentRev = ""
            }
            Set ^IRISCouch.Tree(pDB, pDocId, "R", tRev) = tParentRev
        }
        ; If chain has more than 1 element, check if parent of leaf was a leaf
        If tLen > 1 {
            Set tParentOfLeaf = pRevChain.%Get(tLen - 2)
            If $Data(^IRISCouch.Tree(pDB, pDocId, "L", tParentOfLeaf)) > 0 {
                Kill ^IRISCouch.Tree(pDB, pDocId, "L", tParentOfLeaf)
                Kill ^IRISCouch.Tree(pDB, pDocId, "D", tParentOfLeaf)
            }
        }
        ; Set new leaf entry with depth = chain length
        Set ^IRISCouch.Tree(pDB, pDocId, "L", pLeafRev) = tLen
        ; Mark as deleted if requested
        If pDeleted {
            Set ^IRISCouch.Tree(pDB, pDocId, "D", pLeafRev) = 1
        }
        ; Recompute winner
        Set tSC = ..RecomputeWinner(pDB, pDocId)
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

}
