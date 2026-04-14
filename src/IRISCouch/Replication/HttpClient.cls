/// <p>HTTP client wrapper for CouchDB replication protocol.</p>
/// <p>Provides a simplified interface over <class>%Net.HttpRequest</class>
/// for making HTTP requests to remote CouchDB peers during replication.
/// Handles URL parsing, authentication, and SSL configuration.</p>
Class IRISCouch.Replication.HttpClient Extends %RegisteredObject
{

/// <p>The server hostname or IP address.</p>
Property Server As %String;

/// <p>The server port number.</p>
Property Port As %Integer;

/// <p>The base path prefix for all requests (e.g., "/dbname").</p>
Property BasePath As %String;

/// <p>Username for HTTP Basic authentication.</p>
Property Username As %String;

/// <p>Password for HTTP Basic authentication.</p>
Property Password As %String;

/// <p>Whether to use HTTPS (SSL/TLS).</p>
Property UseSSL As %Boolean [ InitialExpression = 0 ];

/// <p>Custom HTTP headers to include on every request.</p>
Property Headers As %DynamicObject;

/// <p>Create an HttpClient from a full URL string.</p>
/// <p>Parses the URL into server, port, basePath, and SSL flag.
/// Supports embedded credentials (http://user:pass@host:port/path)
/// and explicit auth via pAuth object.</p>
/// @param pUrl The full URL string
/// @param pAuth Optional auth object with "username" and "password" keys
/// @return IRISCouch.Replication.HttpClient The configured client
ClassMethod FromUrl(pUrl As %String, pAuth As %DynamicObject = "") As IRISCouch.Replication.HttpClient
{
    Set tClient = ""
    Try {
        Set tClient = ..%New()
        Set tUrl = pUrl
        ; Determine SSL
        Set tLower = $ZConvert(tUrl, "L")
        If $Extract(tLower, 1, 8) = "https://" {
            Set tClient.UseSSL = 1
            Set tUrl = $Extract(tUrl, 9, *)
        } ElseIf $Extract(tLower, 1, 7) = "http://" {
            Set tClient.UseSSL = 0
            Set tUrl = $Extract(tUrl, 8, *)
        }
        ; Check for embedded credentials (user:pass@host)
        Set tAtPos = $Find(tUrl, "@")
        If tAtPos > 0 {
            Set tCredPart = $Extract(tUrl, 1, tAtPos - 2)
            Set tUrl = $Extract(tUrl, tAtPos, *)
            Set tColonPos = $Find(tCredPart, ":")
            If tColonPos > 0 {
                Set tClient.Username = $Extract(tCredPart, 1, tColonPos - 2)
                Set tClient.Password = $Extract(tCredPart, tColonPos, *)
            } Else {
                Set tClient.Username = tCredPart
            }
        }
        ; Split host:port from path
        Set tSlashPos = $Find(tUrl, "/")
        If tSlashPos > 0 {
            Set tHostPort = $Extract(tUrl, 1, tSlashPos - 2)
            Set tClient.BasePath = $Extract(tUrl, tSlashPos - 1, *)
        } Else {
            Set tHostPort = tUrl
            Set tClient.BasePath = ""
        }
        ; Remove trailing slash from BasePath
        If ($Length(tClient.BasePath) > 1) && ($Extract(tClient.BasePath, *) = "/") {
            Set tClient.BasePath = $Extract(tClient.BasePath, 1, *-1)
        }
        ; Split host:port
        Set tColonPos = $Find(tHostPort, ":")
        If tColonPos > 0 {
            Set tClient.Server = $Extract(tHostPort, 1, tColonPos - 2)
            Set tClient.Port = +$Extract(tHostPort, tColonPos, *)
        } Else {
            Set tClient.Server = tHostPort
            If tClient.UseSSL {
                Set tClient.Port = 443
            } Else {
                Set tClient.Port = 80
            }
        }
        ; Override auth from pAuth if provided
        If $IsObject(pAuth) {
            If pAuth.%IsDefined("username") {
                Set tClient.Username = pAuth.%Get("username")
            }
            If pAuth.%IsDefined("password") {
                Set tClient.Password = pAuth.%Get("password")
            }
        }
        ; Initialize headers
        Set tClient.Headers = {}
        Quit
    }
    Catch ex {
        Set tClient = ""
        Quit
    }
    Quit tClient
}

/// <p>Execute an HTTP request to the remote server.</p>
/// <p>Creates a <class>%Net.HttpRequest</class>, configures server, port,
/// authentication, SSL, and custom headers. Writes body if provided.
/// Captures response status code and body.</p>
/// @param pMethod The HTTP method (GET, PUT, POST, DELETE, HEAD)
/// @param pPath The request path (appended to BasePath)
/// @param pBody The request body string (empty for bodyless requests)
/// @param Output pStatusCode The HTTP response status code
/// @param Output pResponseBody The HTTP response body as string
/// @return %Status
Method Request(pMethod As %String, pPath As %String, pBody As %String = "", Output pStatusCode As %Integer, Output pResponseBody As %String) As %Status
{
    Set tSC = $$$OK
    Set pStatusCode = 0
    Set pResponseBody = ""
    Try {
        Set tReq = ##class(%Net.HttpRequest).%New()
        Set tReq.Server = ..Server
        Set tReq.Port = ..Port
        If ..UseSSL {
            Set tReq.Https = 1
            Set tReq.SSLConfiguration = "ISC.FeatureTracker.SSL.Config"
        }
        If ..Username '= "" {
            Set tReq.Username = ..Username
            Set tReq.Password = ..Password
        }
        ; Set standard headers
        Do tReq.SetHeader("Accept", "application/json")
        Do tReq.SetHeader("Content-Type", "application/json")
        ; Set custom headers
        If $IsObject(..Headers) {
            Set tIter = ..Headers.%GetIterator()
            While tIter.%GetNext(.tKey, .tVal) {
                Do tReq.SetHeader(tKey, tVal)
            }
        }
        ; Write body if provided
        If pBody '= "" {
            Do tReq.EntityBody.Write(pBody)
        }
        ; Build full path
        Set tFullPath = ..BasePath _ pPath
        ; Execute request based on method
        Set tMethod = $ZConvert(pMethod, "U")
        If tMethod = "GET" {
            Set tSC = tReq.Get(tFullPath)
        } ElseIf tMethod = "PUT" {
            Set tSC = tReq.Put(tFullPath)
        } ElseIf tMethod = "POST" {
            Set tSC = tReq.Post(tFullPath)
        } ElseIf tMethod = "DELETE" {
            Set tSC = tReq.Delete(tFullPath)
        } ElseIf tMethod = "HEAD" {
            Set tSC = tReq.Head(tFullPath)
        }
        If $$$ISERR(tSC) Quit
        ; Capture response
        Set pStatusCode = tReq.HttpResponse.StatusCode
        If $IsObject(tReq.HttpResponse.Data) {
            Set pResponseBody = tReq.HttpResponse.Data.Read()
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Perform an HTTP GET request.</p>
/// @param pPath The request path
/// @param Output pStatusCode The HTTP response status code
/// @param Output pBody The HTTP response body
/// @return %Status
Method Get(pPath As %String, Output pStatusCode As %Integer, Output pBody As %String) As %Status
{
    Quit ..Request("GET", pPath, "", .pStatusCode, .pBody)
}

/// <p>Perform an HTTP PUT request.</p>
/// @param pPath The request path
/// @param pBody The request body
/// @param Output pStatusCode The HTTP response status code
/// @param Output pRespBody The HTTP response body
/// @return %Status
Method Put(pPath As %String, pBody As %String, Output pStatusCode As %Integer, Output pRespBody As %String) As %Status
{
    Quit ..Request("PUT", pPath, pBody, .pStatusCode, .pRespBody)
}

/// <p>Perform an HTTP POST request.</p>
/// @param pPath The request path
/// @param pBody The request body
/// @param Output pStatusCode The HTTP response status code
/// @param Output pRespBody The HTTP response body
/// @return %Status
Method Post(pPath As %String, pBody As %String, Output pStatusCode As %Integer, Output pRespBody As %String) As %Status
{
    Quit ..Request("POST", pPath, pBody, .pStatusCode, .pRespBody)
}

}
