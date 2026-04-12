/// <p>Storage layer for IRISCouch revision tree operations.</p>
/// <p>Manages the revision tree structure stored in <code>^IRISCouch.Tree</code>.
/// Tracks parent-child revision relationships, leaf nodes with depth,
/// and the cached winning revision.</p>
/// <h4>Global Structure:</h4>
/// <ul>
/// <li><code>^IRISCouch.Tree(db, docId, "R", rev)</code> - Child to parent pointer (empty string for root)</li>
/// <li><code>^IRISCouch.Tree(db, docId, "L", rev)</code> - Leaf node with depth value</li>
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

/// <p>Get the winning revision for a document.</p>
/// <p>Returns the cached winning revision from <code>^IRISCouch.Tree(pDB, pDocId, "W")</code>.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %String The winning revision string, or "" if no tree exists
ClassMethod GetWinner(pDB As %String, pDocId As %String) As %String
{
    Quit $Get(^IRISCouch.Tree(pDB, pDocId, "W"))
}

/// <p>Recompute and cache the winning revision for a document.</p>
/// <p>Iterates all leaf nodes in <code>^IRISCouch.Tree(pDB, pDocId, "L")</code>
/// and selects the winner by: (1) highest depth, (2) lexicographic rev hash tiebreak.
/// For Story 3.1, no deleted leafs exist, so deletion status is not considered.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %Status
ClassMethod RecomputeWinner(pDB As %String, pDocId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tWinnerRev = ""
        Set tWinnerDepth = 0
        ; Iterate all leaf nodes
        Set tRev = ""
        For {
            Set tRev = $Order(^IRISCouch.Tree(pDB, pDocId, "L", tRev))
            Quit:tRev=""
            Set tDepth = +$Get(^IRISCouch.Tree(pDB, pDocId, "L", tRev))
            ; Winner selection: highest depth, then lexicographic tiebreak
            If (tDepth > tWinnerDepth) || ((tDepth = tWinnerDepth) && (tRev > tWinnerRev)) {
                Set tWinnerRev = tRev
                Set tWinnerDepth = tDepth
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

}
