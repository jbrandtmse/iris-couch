/// <p>Persistent metadata for Mango index definitions.</p>
/// <p>Stores the definition of each user-created Mango index including fields,
/// design document, name, type, and optional partial filter selector.
/// No DDL or class recompilation occurs at runtime (AC #10).</p>
Class IRISCouch.Projection.MangoIndexDef Extends %Persistent
{

/// <p>Database name.</p>
Property DbName As %String(MAXLEN = 255) [ Required ];

/// <p>Design document ID (e.g., "_design/my-indexes").</p>
Property DDoc As %String(MAXLEN = 255) [ Required ];

/// <p>Index name.</p>
Property Name As %String(MAXLEN = 255) [ Required ];

/// <p>Index type — always "json" for now.</p>
Property Type As %String(MAXLEN = 50) [ InitialExpression = "json" ];

/// <p>JSON array of field objects, e.g., [{"type":"asc"},{"date":"asc"}].</p>
Property Fields As %String(MAXLEN = "");

/// <p>JSON partial filter selector string or empty.</p>
Property PartialFilterSelector As %String(MAXLEN = "");

/// <p>Unique index for duplicate detection.</p>
Index IdxDbDDocName On (DbName, DDoc, Name) [ Unique ];

/// <p>Index for listing all indexes in a database.</p>
Index IdxDb On (DbName);

/// <p>Create a new index definition.</p>
/// @param pDB The database name
/// @param pDDoc The design document ID
/// @param pName The index name
/// @param pType The index type (default "json")
/// @param pFields JSON array of field objects
/// @param pPartialFilter JSON partial filter selector string
/// @return %Status
ClassMethod Create(pDB As %String, pDDoc As %String, pName As %String, pType As %String = "json", pFields As %String = "", pPartialFilter As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tObj = ..%New()
        Set tObj.DbName = pDB
        Set tObj.DDoc = pDDoc
        Set tObj.Name = pName
        Set tObj.Type = pType
        Set tObj.Fields = pFields
        Set tObj.PartialFilterSelector = pPartialFilter
        Set tSC = tObj.%Save()
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Check if an index definition exists by database, ddoc, and name.</p>
/// @param pDB The database name
/// @param pDDoc The design document ID
/// @param pName The index name
/// @return %Boolean
ClassMethod Exists(pDB As %String, pDDoc As %String, pName As %String) As %Boolean
{
    Set tObj = ..IdxDbDDocNameOpen(pDB, pDDoc, pName)
    Quit $IsObject(tObj)
}

/// <p>Check if an identical index definition exists (for idempotency).</p>
/// @param pDB The database name
/// @param pFields JSON array of field objects
/// @param pPartialFilter JSON partial filter selector
/// @return %Boolean
ClassMethod ExistsByDefinition(pDB As %String, pFields As %String, pPartialFilter As %String = "") As %Boolean
{
    Set tDDoc = ""
    Set tName = ""
    Quit ..FindByDefinition(pDB, pFields, pPartialFilter, .tDDoc, .tName)
}

/// <p>Find an existing identical index definition.</p>
/// @param pDB The database name
/// @param pFields JSON array of field objects
/// @param pPartialFilter JSON partial filter selector
/// @param pDDoc Output: design document ID if found
/// @param pName Output: index name if found
/// @return %Boolean 1 if found, 0 otherwise
ClassMethod FindByDefinition(pDB As %String, pFields As %String, pPartialFilter As %String = "", Output pDDoc As %String, Output pName As %String) As %Boolean
{
    Set pDDoc = ""
    Set pName = ""
    Try {
        If pPartialFilter = "" {
            &sql(SELECT DDoc, Name INTO :pDDoc, :pName
                 FROM IRISCouch_Projection.MangoIndexDef
                 WHERE DbName = :pDB AND Fields = :pFields AND (PartialFilterSelector IS NULL OR PartialFilterSelector = ''))
        } Else {
            &sql(SELECT DDoc, Name INTO :pDDoc, :pName
                 FROM IRISCouch_Projection.MangoIndexDef
                 WHERE DbName = :pDB AND Fields = :pFields AND PartialFilterSelector = :pPartialFilter)
        }
        If SQLCODE = 0 {
            Quit
        }
        Set pDDoc = ""
        Set pName = ""
        Quit
    }
    Catch ex {
        Set pDDoc = ""
        Set pName = ""
        Quit
    }
    Quit (pDDoc '= "")
}

/// <p>List all index definitions for a database as a JSON array.</p>
/// @param pDB The database name
/// @return %DynamicArray of index definition objects
ClassMethod List(pDB As %String) As %DynamicArray
{
    Set tArr = []
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT DDoc, Name, Type, Fields, PartialFilterSelector FROM IRISCouch_Projection.MangoIndexDef WHERE DbName = ?", pDB)
        While tRS.%Next() {
            Set tObj = {}
            Do tObj.%Set("ddoc", tRS.%Get("DDoc"))
            Do tObj.%Set("name", tRS.%Get("Name"))
            Do tObj.%Set("type", tRS.%Get("Type"))
            ; Parse fields back to array
            Set tFieldsStr = tRS.%Get("Fields")
            If tFieldsStr '= "" {
                Set tFieldsArr = ##class(%DynamicAbstractObject).%FromJSON(tFieldsStr)
            } Else {
                Set tFieldsArr = []
            }
            Set tDef = {}
            Do tDef.%Set("fields", tFieldsArr)
            ; Add partial_filter_selector if present
            Set tPartial = tRS.%Get("PartialFilterSelector")
            If tPartial '= "" {
                Set tPartialObj = ##class(%DynamicAbstractObject).%FromJSON(tPartial)
                Do tDef.%Set("partial_filter_selector", tPartialObj)
            }
            Do tObj.%Set("def", tDef)
            Do tArr.%Push(tObj)
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tArr
}

/// <p>Delete one index definition.</p>
/// @param pDB The database name
/// @param pDDoc The design document ID
/// @param pName The index name
/// @return %Status
ClassMethod Delete(pDB As %String, pDDoc As %String, pName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tObj = ..IdxDbDDocNameOpen(pDB, pDDoc, pName)
        If $IsObject(tObj) {
            Set tSC = ##class(IRISCouch.Projection.MangoIndexDef).%DeleteId(tObj.%Id())
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Delete all index definitions for a database.</p>
/// @param pDB The database name
/// @return %Status
ClassMethod DeleteAll(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        &sql(DELETE FROM IRISCouch_Projection.MangoIndexDef WHERE DbName = :pDB)
        If SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "SQL error deleting MangoIndexDef: " _ SQLCODE)
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Get active index definitions for a database (for MangoIndex population during writes).</p>
/// @param pDB The database name
/// @return %DynamicArray of index definition objects with DDoc, Name, Fields, PartialFilterSelector
ClassMethod GetActiveIndexes(pDB As %String) As %DynamicArray
{
    Set tArr = []
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT DDoc, Name, Fields, PartialFilterSelector FROM IRISCouch_Projection.MangoIndexDef WHERE DbName = ?", pDB)
        While tRS.%Next() {
            Set tObj = {}
            Do tObj.%Set("ddoc", tRS.%Get("DDoc"))
            Do tObj.%Set("name", tRS.%Get("Name"))
            Do tObj.%Set("fields", tRS.%Get("Fields"))
            Do tObj.%Set("partialFilter", tRS.%Get("PartialFilterSelector"))
            Do tArr.%Push(tObj)
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tArr
}

/// <p>Generate a deterministic index name from the definition using SHA-1 hash.</p>
/// @param pFields JSON string of fields array
/// @param pPartialFilter JSON string of partial filter selector
/// @return %String hex-encoded SHA-1 hash
ClassMethod GenerateName(pFields As %String, pPartialFilter As %String = "") As %String
{
    Set tInput = pFields
    If pPartialFilter '= "" Set tInput = tInput _ "|" _ pPartialFilter
    Set tHash = $System.Encryption.SHA1Hash(tInput)
    Set tHex = ##class(%xsd.hexBinary).LogicalToXSD(tHash)
    Quit $ZConvert(tHex, "L")
}

/// <p>Generate a deterministic design document name from the definition using SHA-1 hash.</p>
/// @param pFields JSON string of fields array
/// @param pPartialFilter JSON string of partial filter selector
/// @return %String "_design/" prefixed hex-encoded SHA-1 hash
ClassMethod GenerateDDoc(pFields As %String, pPartialFilter As %String = "") As %String
{
    Quit "_design/" _ ..GenerateName(pFields, pPartialFilter)
}

Storage Default
{
<Data name="MangoIndexDefDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>DbName</Value>
</Value>
<Value name="3">
<Value>DDoc</Value>
</Value>
<Value name="4">
<Value>Name</Value>
</Value>
<Value name="5">
<Value>Type</Value>
</Value>
<Value name="6">
<Value>Fields</Value>
</Value>
<Value name="7">
<Value>PartialFilterSelector</Value>
</Value>
</Data>
<DataLocation>^IRISCouch.Pr4479.MangoIndexDefD</DataLocation>
<DefaultData>MangoIndexDefDefaultData</DefaultData>
<IdLocation>^IRISCouch.Pr4479.MangoIndexDefD</IdLocation>
<IndexLocation>^IRISCouch.Pr4479.MangoIndexDefI</IndexLocation>
<StreamLocation>^IRISCouch.Pr4479.MangoIndexDefS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
