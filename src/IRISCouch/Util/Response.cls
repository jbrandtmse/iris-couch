/// <p>Standardized JSON response rendering for IRISCouch.</p>
/// <p>This is the standard way to write success responses.
/// Handlers must NEVER <code>Write</code> JSON directly.</p>
Class IRISCouch.Util.Response Extends %RegisteredObject
{

/// <p>Write a JSON success response with HTTP 200.</p>
/// <p>If <var>pData</var> is an object, calls <code>%ToJSON()</code>.
/// Otherwise writes the raw string value.</p>
/// @param pData A %DynamicObject, %DynamicArray, or pre-formatted JSON string
/// @return %Status
ClassMethod JSON(pData) As %Status
{
    Set %response.ContentType = "application/json"
    If $IsObject(pData) {
        Write pData.%ToJSON()
    } Else {
        Write pData
    }
    Quit $$$OK
}

/// <p>Write a JSON response with a specific HTTP status code.</p>
/// @param pStatus HTTP status code (e.g., 200, 201, 202)
/// @param pData A %DynamicObject, %DynamicArray, or pre-formatted JSON string
/// @return %Status
ClassMethod JSONStatus(pStatus As %Integer, pData) As %Status
{
    Set %response.Status = pStatus
    Quit ..JSON(pData)
}

}
