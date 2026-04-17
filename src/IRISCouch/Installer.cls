/// <p>Installer utility for IRISCouch.</p>
/// <p>Provides programmatic installation and uninstallation of the IRISCouch
/// web application. Use this class when ZPM is not available and you need
/// to configure the web application after a manual <code>$System.OBJ.ImportDir</code> import.</p>
/// <h4>Usage</h4>
/// <example language="objectscript">
/// Do ##class(IRISCouch.Installer).Install($Namespace, "/iris-couch/")
/// </example>
///
/// <h3>Namespace Requirements (Story 9.3)</h3>
/// <p>IRISCouch must be installed into a dedicated IRIS namespace (e.g., IRISCOUCH)
/// backed by its own database. All <code>^IRISCouch.*</code> globals reside within
/// this namespace. No cross-namespace global references are used.</p>
///
/// <h3>Web Application Configuration</h3>
/// <p>The installer creates a CSP web application entry pointing to
/// <class>IRISCouch.API.Router</class> as the dispatch class. The web application
/// is configured with password authentication (AutheEnabled=64) and is namespace-bound
/// to the target namespace.</p>
///
/// <h3>IRIS High Availability (HA) Coverage</h3>
/// <p>IRISCouch inherits IRIS HA capabilities automatically. Since all state resides
/// in <code>^IRISCouch.*</code> globals within a single namespace database:</p>
/// <ul>
/// <li><b>Mirroring</b>: Configure IRIS database mirroring on the IRISCOUCH database
/// to replicate all IRISCouch state to mirror members. No application-level
/// replication is needed.</li>
/// <li><b>Backup</b>: Standard IRIS online or freeze-based database backup covers
/// all IRISCouch globals. No special pre/post backup procedures required.</li>
/// <li><b>Journal Replay</b>: All writes are journaled. On crash recovery, IRIS
/// journal replay restores consistent state. Document writes use
/// <code>TSTART</code>/<code>TCOMMIT</code> for atomicity.</li>
/// <li><b>ECP</b>: If using Enterprise Cache Protocol (ECP), the IRISCOUCH database
/// can be served from an ECP data server to application servers.</li>
/// </ul>
Class IRISCouch.Installer Extends %RegisteredObject
{

/// <p>Default web application path.</p>
Parameter DEFAULTWEBAPPPATH = "/iris-couch/";

/// <p>Default dispatch class for the web application.</p>
Parameter DISPATCHCLASS = "IRISCouch.API.Router";

/// <p>Default authentication mode (64 = Password).</p>
Parameter DEFAULTAUTHEENABLED = 64;

/// <p>Name of the Admin UI access role (Story 11.5).</p>
Parameter ADMINROLE = "IRISCouch_Admin";

/// <p>Install the IRISCouch web application.</p>
/// <p>Creates a CSP web application entry pointing to <class>IRISCouch.API.Router</class>
/// as the dispatch class. Requires access to the <code>Security.Applications</code> API
/// in the <code>%SYS</code> namespace.</p>
/// <p>Also creates the <code>IRISCouch_Admin</code> role for Admin UI access and
/// grants it to the installing user and <code>_SYSTEM</code> (Story 11.5).</p>
/// <p>If the web application already exists, the method returns <code>$$$OK</code>
/// without modifying the existing configuration (but still ensures role exists).</p>
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
            ; Webapp exists — ensure role and audit events on upgrade path
            Do ..EnsureAdminRole()
            Set $NAMESPACE = tOrigNS
            Do ##class(IRISCouch.Audit.Emit).EnsureEvents()
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

        ; Create IRISCouch_Admin role and grant to installing user (Story 11.5)
        Do ..EnsureAdminRole()

        ; Register audit event types in Security.Events (Story 9.2)
        ; Must happen in %SYS with %Admin_Secure privilege (Installer runs as _SYSTEM)
        Set $NAMESPACE = tOrigNS
        Do ##class(IRISCouch.Audit.Emit).EnsureEvents()
    }
    Catch ex {
        Set $NAMESPACE = $Get(tOrigNS, $Namespace)
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure the <code>IRISCouch_Admin</code> role exists and is granted
/// to the installing user and <code>_SYSTEM</code> (Story 11.5).</p>
/// <p>Must be called while in the <code>%SYS</code> namespace.</p>
ClassMethod EnsureAdminRole() [ Private ]
{
    Try {
        ; Create role if it doesn't exist
        If '##class(Security.Roles).Exists(..#ADMINROLE) {
            Set tSC = ##class(Security.Roles).Create(..#ADMINROLE, "IRISCouch Admin UI access", "")
            ; Continue even if creation fails (e.g., insufficient privileges)
        }

        ; Grant to the installing user
        Set tUsername = $Username
        If tUsername '= "" {
            Do ..GrantAdminRole(tUsername)
        }

        ; Also grant to _SYSTEM if the installing user is not _SYSTEM
        If tUsername '= "_SYSTEM" {
            Do ..GrantAdminRole("_SYSTEM")
        }
    }
    Catch ex {
        ; Role creation is best-effort — do not fail the install
    }
    Quit
}

/// <p>Grant the <code>IRISCouch_Admin</code> role to a user if not already assigned.</p>
/// <p>Must be called while in the <code>%SYS</code> namespace.</p>
/// @param pUsername The username to grant the role to
ClassMethod GrantAdminRole(pUsername As %String) [ Private ]
{
    Try {
        If ##class(Security.Users).Exists(pUsername) {
            ; Get current roles
            Set tSC = ##class(Security.Users).Get(pUsername, .tProps)
            If $$$ISERR(tSC) Quit
            Set tCurrentRoles = $Get(tProps("Roles"), "")
            ; Check if role already assigned
            If $Find("," _ tCurrentRoles _ ",", "," _ ..#ADMINROLE _ ",") > 0 Quit
            ; Add the role
            If tCurrentRoles = "" {
                Set tNewRoles = ..#ADMINROLE
            } Else {
                Set tNewRoles = tCurrentRoles _ "," _ ..#ADMINROLE
            }
            Set tModProps("Roles") = tNewRoles
            Set tSC = ##class(Security.Users).Modify(pUsername, .tModProps)
        }
    }
    Catch ex {
        ; Best-effort — do not fail
    }
    Quit
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
