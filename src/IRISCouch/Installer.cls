/// <p>Installer utility for IRISCouch.</p>
/// <p>Provides programmatic installation and uninstallation of the IRISCouch
/// web application. Use this class when ZPM is not available and you need
/// to configure the web application after a manual <code>$System.OBJ.ImportDir</code> import.</p>
/// <h4>Usage</h4>
/// <example language="objectscript">
/// Do ##class(IRISCouch.Installer).Install($Namespace, "/iris-couch/")
/// </example>
Class IRISCouch.Installer Extends %RegisteredObject
{

/// <p>Default web application path.</p>
Parameter DEFAULTWEBAPPPATH = "/iris-couch/";

/// <p>Default dispatch class for the web application.</p>
Parameter DISPATCHCLASS = "IRISCouch.API.Router";

/// <p>Default authentication mode (64 = Password).</p>
Parameter DEFAULTAUTHEENABLED = 64;

/// <p>Install the IRISCouch web application.</p>
/// <p>Creates a CSP web application entry pointing to <class>IRISCouch.API.Router</class>
/// as the dispatch class. Requires access to the <code>Security.Applications</code> API
/// in the <code>%SYS</code> namespace.</p>
/// <p>If the web application already exists, the method returns <code>$$$OK</code>
/// without modifying the existing configuration.</p>
/// @param pNamespace Target namespace where IRISCouch classes are installed. Defaults to current namespace.
/// @param pWebAppPath URL path for the web application. Defaults to "/iris-couch/".
/// @return %Status indicating success or failure
ClassMethod Install(pNamespace As %String = "", pWebAppPath As %String = "/iris-couch/") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If pNamespace = "" Set pNamespace = $Namespace

        ; Switch to %SYS for Security.Applications access
        Set $NAMESPACE = "%SYS"

        ; Check if webapp already exists
        If ##class(Security.Applications).Exists(pWebAppPath) {
            Set $NAMESPACE = tOrigNS
            Quit
        }

        ; Create properties for new web application
        Set tProps("NameSpace") = pNamespace
        Set tProps("DispatchClass") = ..#DISPATCHCLASS
        Set tProps("AutheEnabled") = ..#DEFAULTAUTHEENABLED
        Set tProps("Enabled") = 1
        Set tProps("IsNameSpaceDefault") = 0
        Set tProps("Description") = "IRISCouch - CouchDB-compatible REST API"

        Set tSC = ##class(Security.Applications).Create(pWebAppPath, .tProps)
        Set $NAMESPACE = tOrigNS
    }
    Catch ex {
        Set $NAMESPACE = $Get(tOrigNS, $Namespace)
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Uninstall the IRISCouch web application.</p>
/// <p>Removes the CSP web application entry. If the web application does not
/// exist, the method returns <code>$$$OK</code> without error.</p>
/// @param pWebAppPath URL path of the web application to remove. Defaults to "/iris-couch/".
/// @return %Status indicating success or failure
ClassMethod Uninstall(pWebAppPath As %String = "/iris-couch/") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        ; Switch to %SYS for Security.Applications access
        Set $NAMESPACE = "%SYS"

        ; Check if webapp exists before attempting deletion
        If '##class(Security.Applications).Exists(pWebAppPath) {
            Set $NAMESPACE = tOrigNS
            Quit
        }

        Set tSC = ##class(Security.Applications).Delete(pWebAppPath)
        Set $NAMESPACE = tOrigNS
    }
    Catch ex {
        Set $NAMESPACE = $Get(tOrigNS, $Namespace)
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Check if the IRISCouch web application is currently installed.</p>
/// @param pWebAppPath URL path of the web application to check. Defaults to "/iris-couch/".
/// @return %Boolean 1 if installed, 0 if not
ClassMethod IsInstalled(pWebAppPath As %String = "/iris-couch/") As %Boolean
{
    Set tResult = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(Security.Applications).Exists(pWebAppPath)
        Set $NAMESPACE = tOrigNS
    }
    Catch ex {
        Set $NAMESPACE = $Get(tOrigNS, $Namespace)
    }
    Quit tResult
}

}
