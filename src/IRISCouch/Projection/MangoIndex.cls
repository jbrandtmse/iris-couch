/// <p>Persistent key-value index table for Mango queries.</p>
/// <p>Each row represents one field value extracted from a document for a specific
/// Mango index. Updated synchronously inside DocumentEngine write transactions
/// to ensure zero staleness (NFR-P7). No DDL at runtime (AC #10) — uses a
/// fixed schema with key-value rows.</p>
Class IRISCouch.Projection.MangoIndex Extends %Persistent
{

/// <p>Database name.</p>
Property DbName As %String(MAXLEN = 255) [ Required ];

/// <p>Index name (matches MangoIndexDef.Name).</p>
Property IndexName As %String(MAXLEN = 255) [ Required ];

/// <p>Design document ID (matches MangoIndexDef.DDoc).</p>
Property DDoc As %String(MAXLEN = 255) [ Required ];

/// <p>Document identifier.</p>
Property DocId As %String(MAXLEN = 255) [ Required ];

/// <p>Dot-notation field path (e.g., "type", "address.city").</p>
Property FieldPath As %String(MAXLEN = 255) [ Required ];

/// <p>Extracted field value as JSON-encoded string.</p>
Property FieldValue As %String(MAXLEN = "");

/// <p>JSON type: "null", "boolean", "number", "string", "array", "object".</p>
Property FieldType As %String(MAXLEN = 50);

/// <p>Primary lookup index for range queries.</p>
Index IdxLookup On (DbName, DDoc, IndexName, FieldPath, FieldValue, DocId);

/// <p>Reverse index for efficient cleanup when document is updated/deleted.</p>
Index IdxReverse On (DbName, DocId, DDoc, IndexName);

/// <p>Upsert index rows for a document across all active indexes.</p>
/// <p>For each active index, extracts field values from the document body
/// and creates MangoIndex rows. Caller should call DeleteForDocument first
/// to clear stale rows.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pBody The document body as %DynamicObject
/// @param pIndexDefs Active index definitions as %DynamicArray
/// @return %Status
ClassMethod UpsertForDocument(pDB As %String, pDocId As %String, pBody As %DynamicObject, pIndexDefs As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Try {
        If '$IsObject(pBody) Quit
        If '$IsObject(pIndexDefs) Quit
        Set tDefCount = pIndexDefs.%Size()
        For tI = 0:1:(tDefCount - 1) {
            Set tDef = pIndexDefs.%Get(tI)
            If '$IsObject(tDef) Continue
            Set tDDoc = tDef.%Get("ddoc")
            Set tIdxName = tDef.%Get("name")
            Set tFieldsStr = tDef.%Get("fields")
            Set tPartialFilter = tDef.%Get("partialFilter")
            ; Check partial filter: if set, document must match
            If tPartialFilter '= "" {
                Set tMatch = ..MatchesPartialFilter(pBody, tPartialFilter)
                If 'tMatch Continue
            }
            ; Parse fields array
            If tFieldsStr = "" Continue
            Set tFieldsArr = ##class(%DynamicAbstractObject).%FromJSON(tFieldsStr)
            Set tFieldCount = tFieldsArr.%Size()
            For tJ = 0:1:(tFieldCount - 1) {
                Set tFieldDef = tFieldsArr.%Get(tJ)
                ; Field can be string or object like {"fieldname":"asc"}
                If $IsObject(tFieldDef) {
                    Set tIter = tFieldDef.%GetIterator()
                    If tIter.%GetNext(.tFieldPath, .tDir) {
                        ; tFieldPath is the field name
                    } Else {
                        Continue
                    }
                } Else {
                    Set tFieldPath = tFieldDef
                }
                ; Extract the value with type info
                Set tValue = ..ExtractFieldValue(pBody, tFieldPath, .tTypeHint)
                Set tType = ..GetJsonType(tValue, tTypeHint)
                ; Convert value to string for storage
                Set tValueStr = ..ValueToString(tValue, tType)
                ; Create index row
                Set tRow = ..%New()
                Set tRow.DbName = pDB
                Set tRow.IndexName = tIdxName
                Set tRow.DDoc = tDDoc
                Set tRow.DocId = pDocId
                Set tRow.FieldPath = tFieldPath
                Set tRow.FieldValue = tValueStr
                Set tRow.FieldType = tType
                Set tSC = tRow.%Save()
                If $$$ISERR(tSC) Quit
            }
            If $$$ISERR(tSC) Quit
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Delete all MangoIndex rows for a document (called before re-indexing on update).</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @return %Status
ClassMethod DeleteForDocument(pDB As %String, pDocId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        &sql(DELETE FROM IRISCouch_Projection.MangoIndex WHERE DbName = :pDB AND DocId = :pDocId)
        If SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "SQL error deleting MangoIndex for doc: " _ SQLCODE)
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Delete all rows for a specific index (called when index is deleted).</p>
/// @param pDB The database name
/// @param pDDoc The design document ID
/// @param pName The index name
/// @return %Status
ClassMethod DeleteForIndex(pDB As %String, pDDoc As %String, pName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        &sql(DELETE FROM IRISCouch_Projection.MangoIndex WHERE DbName = :pDB AND DDoc = :pDDoc AND IndexName = :pName)
        If SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "SQL error deleting MangoIndex for index: " _ SQLCODE)
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Delete all rows for a database.</p>
/// @param pDB The database name
/// @return %Status
ClassMethod DeleteAll(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        &sql(DELETE FROM IRISCouch_Projection.MangoIndex WHERE DbName = :pDB)
        If SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "SQL error deleting all MangoIndex: " _ SQLCODE)
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Extract a field value from a document body using dot-notation path traversal.</p>
/// <p>Supports nested objects (e.g., "address.city"). Returns "" if path not found.
/// Sets pJsonType output parameter using %GetTypeOf() for accurate type detection.</p>
/// @param pBody The document body as %DynamicObject
/// @param pFieldPath The dot-notation field path
/// @param pJsonType Output: JSON type string from %GetTypeOf()
/// @return The extracted value (any type)
ClassMethod ExtractFieldValue(pBody As %DynamicObject, pFieldPath As %String, Output pJsonType As %String)
{
    Set pJsonType = "null"
    Set tObj = pBody
    Set tParts = $Length(pFieldPath, ".")
    For tI = 1:1:tParts {
        Set tPart = $Piece(pFieldPath, ".", tI)
        If '$IsObject(tObj) {
            Quit
        }
        If tI = tParts {
            ; Final segment — extract the actual value
            If 'tObj.%IsDefined(tPart) {
                Set tObj = ""
                Quit
            }
            Set pJsonType = tObj.%GetTypeOf(tPart)
            Set tObj = tObj.%Get(tPart)
            Quit
        }
        If 'tObj.%IsDefined(tPart) {
            Set tObj = ""
            Quit
        }
        Set tObj = tObj.%Get(tPart)
    }
    Quit tObj
}

/// <p>Determine the JSON type of a value.</p>
/// <p>When called with a %GetTypeOf() result in pTypeHint, uses that for accurate
/// type detection. Falls back to heuristic detection when no hint is provided.</p>
/// @param pValue The value to check
/// @param pTypeHint Optional type hint from %GetTypeOf() (e.g., "boolean", "null", "number", "string", "object", "array")
/// @return %String One of: "null", "boolean", "number", "string", "array", "object"
ClassMethod GetJsonType(pValue, pTypeHint As %String = "") As %String
{
    ; Use type hint from %GetTypeOf() when available
    If pTypeHint '= "" {
        If pTypeHint = "boolean" Quit "boolean"
        If pTypeHint = "null" || (pTypeHint = "unassigned") Quit "null"
        If pTypeHint = "number" Quit "number"
        If pTypeHint = "string" Quit "string"
        If pTypeHint = "object" Quit "object"
        If pTypeHint = "array" Quit "array"
    }
    ; Fallback: heuristic detection (for backward compatibility)
    If $IsObject(pValue) {
        If pValue.%IsA("%DynamicArray") Quit "array"
        If pValue.%IsA("%DynamicObject") Quit "object"
        Quit "object"
    }
    If pValue = "" Quit "null"
    If pValue = +pValue Quit "number"
    Quit "string"
}

/// <p>Convert a value to string representation for storage.</p>
/// @param pValue The value to convert
/// @param pType The JSON type
/// @return %String String representation
ClassMethod ValueToString(pValue, pType As %String) As %String
{
    If pType = "null" Quit ""
    If pType = "object" || (pType = "array") {
        If $IsObject(pValue) Quit pValue.%ToJSON()
        Quit ""
    }
    Quit pValue
}

/// <p>Check if a document matches a partial filter selector.</p>
/// <p>Simple implementation: checks top-level equality conditions only.
/// Full selector evaluation will be implemented in Story 6.2.</p>
/// @param pBody The document body as %DynamicObject
/// @param pPartialFilter JSON string of the partial filter selector
/// @return %Boolean 1 if matches, 0 otherwise
ClassMethod MatchesPartialFilter(pBody As %DynamicObject, pPartialFilter As %String) As %Boolean
{
    Set tResult = 1
    Try {
        If pPartialFilter = "" Quit
        Set tFilter = ##class(%DynamicObject).%FromJSON(pPartialFilter)
        If '$IsObject(tFilter) Quit
        Set tIter = tFilter.%GetIterator()
        While tIter.%GetNext(.tKey, .tExpected) {
            Set tActual = pBody.%Get(tKey)
            If tActual '= tExpected {
                Set tResult = 0
                Quit
            }
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tResult
}

Storage Default
{
<Data name="MangoIndexDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>DbName</Value>
</Value>
<Value name="3">
<Value>IndexName</Value>
</Value>
<Value name="4">
<Value>DDoc</Value>
</Value>
<Value name="5">
<Value>DocId</Value>
</Value>
<Value name="6">
<Value>FieldPath</Value>
</Value>
<Value name="7">
<Value>FieldValue</Value>
</Value>
<Value name="8">
<Value>FieldType</Value>
</Value>
</Data>
<DataLocation>^IRISCouch.Proje4479.MangoIndexD</DataLocation>
<DefaultData>MangoIndexDefaultData</DefaultData>
<IdLocation>^IRISCouch.Proje4479.MangoIndexD</IdLocation>
<IndexLocation>^IRISCouch.Proje4479.MangoIndexI</IndexLocation>
<StreamLocation>^IRISCouch.Proje4479.MangoIndexS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
