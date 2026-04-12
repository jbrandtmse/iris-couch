/// <p>HTTP request utilities for IRISCouch.</p>
/// <p>Provides helper methods for reading and parsing request data.</p>
Class IRISCouch.Util.Request Extends %RegisteredObject
{

/// <p>Read the HTTP request body and parse it as a <class>%DynamicObject</class>.</p>
/// <p>Reads from <code>%request.Content</code> and parses the JSON content.
/// Returns an empty <class>%DynamicObject</class> if the body is empty or not valid JSON.</p>
/// @return %DynamicObject parsed from the request body
ClassMethod ReadBody() As %DynamicObject
{
    Set tResult = {}
    Try {
        If '$IsObject(%request.Content) {
            Quit
        }
        Set tContent = %request.Content.Read()
        If tContent = "" {
            Quit
        }
        Set tResult = {}.%FromJSON(tContent)
    }
    Catch ex {
        ; Return empty object on parse failure
        Set tResult = {}
    }
    Quit tResult
}

}
