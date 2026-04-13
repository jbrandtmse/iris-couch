/// <p>Persistent projection of winning revision bodies for Mango query reads.</p>
/// <p>Maintains a single row per document containing the current winning revision's
/// body. Updated synchronously inside DocumentEngine write transactions to ensure
/// zero staleness (NFR-P7). Used by Mango index population and query execution.</p>
Class IRISCouch.Projection.Winners Extends %Persistent
{

/// <p>Database name.</p>
Property DbName As %String(MAXLEN = 255) [ Required ];

/// <p>Document identifier.</p>
Property DocId As %String(MAXLEN = 255) [ Required ];

/// <p>Winning revision string (e.g., "3-abc123").</p>
Property WinningRev As %String(MAXLEN = 255);

/// <p>Whether the winning revision is a deletion tombstone.</p>
Property Deleted As %Boolean [ InitialExpression = 0 ];

/// <p>Raw JSON body of the winning revision (empty for deleted docs).</p>
Property Body As %String(MAXLEN = "");

/// <p>Unique index for upsert lookups by database and document.</p>
Index IdxDbDoc On (DbName, DocId) [ Unique ];

/// <p>Index for _all_docs-style queries filtering by database and deletion status.</p>
Index IdxDbDeleted On (DbName, Deleted);

/// <p>Upsert the winning revision for a document.</p>
/// <p>Finds existing row by (DbName, DocId) and updates it, or inserts a new row.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The winning revision string
/// @param pBody The raw JSON body string
/// @param pDeleted Whether this is a deletion tombstone
/// @return %Status
ClassMethod Upsert(pDB As %String, pDocId As %String, pRev As %String, pBody As %String, pDeleted As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Look up existing row by unique index
        Set tObj = ..IdxDbDocOpen(pDB, pDocId)
        If '$IsObject(tObj) {
            ; Create new row
            Set tObj = ..%New()
            Set tObj.DbName = pDB
            Set tObj.DocId = pDocId
        }
        Set tObj.WinningRev = pRev
        Set tObj.Body = pBody
        Set tObj.Deleted = pDeleted
        Set tSC = tObj.%Save()
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Delete the Winners row for a specific document.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %Status
ClassMethod Delete(pDB As %String, pDocId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tObj = ..IdxDbDocOpen(pDB, pDocId)
        If $IsObject(tObj) {
            Set tSC = ##class(IRISCouch.Projection.Winners).%DeleteId(tObj.%Id())
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Delete all Winners rows for a database.</p>
/// @param pDB The database name
/// @return %Status
ClassMethod DeleteAll(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        &sql(DELETE FROM IRISCouch_Projection.Winners WHERE %EXACT(DbName) = :pDB)
        If SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "SQL error deleting Winners: " _ SQLCODE)
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Retrieve the winning revision body for a document.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %String The raw JSON body, or "" if not found
ClassMethod GetBody(pDB As %String, pDocId As %String) As %String
{
    Set tBody = ""
    Try {
        Set tObj = ..IdxDbDocOpen(pDB, pDocId)
        If $IsObject(tObj) {
            Set tBody = tObj.Body
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tBody
}

Storage Default
{
<Data name="WinnersDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>DbName</Value>
</Value>
<Value name="3">
<Value>DocId</Value>
</Value>
<Value name="4">
<Value>WinningRev</Value>
</Value>
<Value name="5">
<Value>Deleted</Value>
</Value>
<Value name="6">
<Value>Body</Value>
</Value>
</Data>
<DataLocation>^IRISCouch.Projection.WinnersD</DataLocation>
<DefaultData>WinnersDefaultData</DefaultData>
<IdLocation>^IRISCouch.Projection.WinnersD</IdLocation>
<IndexLocation>^IRISCouch.Projection.WinnersI</IndexLocation>
<StreamLocation>^IRISCouch.Projection.WinnersS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
