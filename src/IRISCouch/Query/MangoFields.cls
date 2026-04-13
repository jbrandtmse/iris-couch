/// <p>Field projection for Mango query results.</p>
/// <p>Filters document bodies to return only the fields specified
/// in the query's <code>fields</code> parameter. Supports dot-notation
/// for nested field extraction.</p>
Class IRISCouch.Query.MangoFields Extends %RegisteredObject
{

/// <p>Project specified fields from a document.</p>
/// <p>If pFields is empty or null, returns the full document.
/// Otherwise creates a new object with only the specified fields.
/// Supports dot-notation paths for nested value extraction.
/// Note: _id and _rev are NOT auto-included per CouchDB behavior.</p>
/// @param pDoc The document as %DynamicObject
/// @param pFields Array of field names to include
/// @return %DynamicObject with only specified fields
ClassMethod Project(pDoc As %DynamicObject, pFields As %DynamicArray) As %DynamicObject
{
    Set tResult = ""
    Try {
        If '$IsObject(pDoc) {
            Set tResult = {}
            Quit
        }
        ; If no fields specified, return full document
        If '$IsObject(pFields) || (pFields.%Size() = 0) {
            Set tResult = pDoc
            Quit
        }
        Set tResult = {}
        For tI = 0:1:(pFields.%Size() - 1) {
            Set tFieldPath = pFields.%Get(tI)
            If tFieldPath = "" Continue
            ; Extract value from source doc
            Set tValue = ##class(IRISCouch.Query.MangoSelector).GetFieldValue(pDoc, tFieldPath, .tFound)
            If 'tFound Continue
            ; Set value in result, handling dot-notation paths
            If tFieldPath [ "." {
                ; Determine type hint for nested value from source doc
                Set tNestedHint = ..GetNestedTypeHint(pDoc, tFieldPath)
                Do ..SetNestedValue(tResult, tFieldPath, tValue, tNestedHint)
            } Else {
                ; Preserve type for special JSON values
                If '$IsObject(tValue) {
                    ; Try to detect type from source
                    Set tSrcType = pDoc.%GetTypeOf(tFieldPath)
                    If tSrcType = "null" {
                        Do tResult.%Set(tFieldPath, "null", "null")
                    } ElseIf tSrcType = "boolean" {
                        Do tResult.%Set(tFieldPath, tValue, "boolean")
                    } ElseIf tSrcType = "number" {
                        Do tResult.%Set(tFieldPath, tValue, "number")
                    } Else {
                        Do tResult.%Set(tFieldPath, tValue)
                    }
                } Else {
                    Do tResult.%Set(tFieldPath, tValue)
                }
            }
        }
        Quit
    }
    Catch ex {
        If '$IsObject(tResult) Set tResult = {}
        Quit
    }
    Quit tResult
}

/// <p>Get the JSON type hint for a nested field path in a document.</p>
/// @param pDoc The source document
/// @param pFieldPath Dot-notation field path
/// @return %String The type hint ("null", "boolean", "number", "string", or "")
ClassMethod GetNestedTypeHint(pDoc As %DynamicObject, pFieldPath As %String) As %String
{
    Set tHint = ""
    Try {
        Set tParts = $Length(pFieldPath, ".")
        Set tObj = pDoc
        For tI = 1:1:(tParts - 1) {
            Set tPart = $Piece(pFieldPath, ".", tI)
            If '$IsObject(tObj) || 'tObj.%IsDefined(tPart) Quit
            Set tObj = tObj.%Get(tPart)
        }
        If $IsObject(tObj) {
            Set tLastPart = $Piece(pFieldPath, ".", tParts)
            If tObj.%IsDefined(tLastPart) {
                Set tHint = tObj.%GetTypeOf(tLastPart)
            }
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tHint
}

/// <p>Set a value at a dot-notation path in a %DynamicObject, creating intermediates.</p>
/// @param pObj The target object to set the value in
/// @param pPath Dot-notation path (e.g., "address.city")
/// @param pValue The value to set
/// @param pTypeHint Optional JSON type hint for non-object values ("null", "boolean", "number", "string")
ClassMethod SetNestedValue(pObj As %DynamicObject, pPath As %String, pValue, pTypeHint As %String = "")
{
    Try {
        Set tParts = $Length(pPath, ".")
        Set tCurrent = pObj
        For tI = 1:1:(tParts - 1) {
            Set tPart = $Piece(pPath, ".", tI)
            If 'tCurrent.%IsDefined(tPart) {
                Set tSub = {}
                Do tCurrent.%Set(tPart, tSub)
                Set tCurrent = tSub
            } Else {
                Set tCurrent = tCurrent.%Get(tPart)
            }
        }
        Set tLastPart = $Piece(pPath, ".", tParts)
        If $IsObject(pValue) {
            Do tCurrent.%Set(tLastPart, pValue)
        } ElseIf pTypeHint = "null" {
            Do tCurrent.%Set(tLastPart, "null", "null")
        } ElseIf pTypeHint = "boolean" {
            Do tCurrent.%Set(tLastPart, pValue, "boolean")
        } ElseIf pTypeHint = "number" {
            Do tCurrent.%Set(tLastPart, pValue, "number")
        } Else {
            Do tCurrent.%Set(tLastPart, pValue)
        }
        Quit
    }
    Catch ex {
        Quit
    }
}

}
