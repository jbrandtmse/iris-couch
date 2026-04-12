/// <p>UUID generation utility for IRISCouch.</p>
/// <p>Generates CouchDB-compatible UUIDs as 32-character lowercase hex strings
/// (no dashes). Uses <code>$System.Util.CreateGUID()</code> for generation.</p>
Class IRISCouch.Util.UUID Extends %RegisteredObject
{

/// <p>Generate a single CouchDB-compatible UUID.</p>
/// <p>Returns a 32-character lowercase hex string with no dashes or braces.</p>
/// @return %String 32-character lowercase hex UUID
ClassMethod Generate() As %String
{
    Set tGUID = $System.Util.CreateGUID()
    Set tHex = $Translate(tGUID, "{}-", "")
    Quit $ZConvert(tHex, "L")
}

/// <p>Generate N CouchDB-compatible UUIDs.</p>
/// <p>Returns a <class>%DynamicArray</class> containing the specified number
/// of unique 32-character lowercase hex UUID strings.</p>
/// @param pCount Number of UUIDs to generate (must be >= 1)
/// @return %DynamicArray containing N UUID strings
ClassMethod GenerateN(pCount As %Integer) As %DynamicArray
{
    Set tArray = []
    For tI = 1:1:pCount {
        Do tArray.%Push(..Generate())
    }
    Quit tArray
}

}
