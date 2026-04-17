/// <p>Subprocess JavaScript runtime backend (Story 12.2).</p>
/// <p>Spawns a configured JS interpreter (Node / Bun / Deno / vendored
/// couchjs) per view query, drives it through the couchjs line protocol
/// via <class>IRISCouch.JSRuntime.Subprocess.Pipe</class>, and returns the
/// parsed results. The canonical command reference is
/// <code>sources/couchdb/share/server/loop.js</code>; the entry-point
/// script shipped alongside this backend is
/// <code>documentation/couchjs/couchjs-entry.js</code>.</p>
///
/// <h3>Lifecycle</h3>
/// <p>Story 12.2 uses a <b>process-per-query</b> model: every call to
/// <method>ExecuteMap</method> or <method>ExecuteReduce</method> opens a
/// fresh Pipe, issues the full command sequence, reads the responses, and
/// closes. Story 12.5 will add a persistent pool on top of the same Pipe
/// API without changing caller code.</p>
///
/// <h3>Story 12.3 (validate_doc_update + custom filters)</h3>
/// <p><method>ExecuteValidateDocUpdate</method> and
/// <method>ExecuteFilter</method> are implemented using the same
/// process-per-call Pipe model. They follow the couchjs <code>ddoc</code>
/// dispatcher protocol (<code>["ddoc","new",id,body]</code> to register
/// then <code>["ddoc",id,funPath,funArgs]</code> to invoke) per
/// <code>sources/couchdb/share/server/loop.js::DDoc</code>. Every call opens
/// its own Pipe, issues the full command stream, reads the response lines,
/// and closes — mirroring ExecuteMap/ExecuteReduce. The entry script
/// <code>documentation/couchjs/couchjs-entry.js</code> handles both ddoc
/// registration and the validate/filters dispatch branches.</p>
Class IRISCouch.JSRuntime.Subprocess Extends IRISCouch.JSRuntime.Sandbox
{

/// <p>Report whether the configured interpreter launches successfully.</p>
/// <p>Performs a lightweight sanity check: the interpreter path must be
/// non-empty, the file must exist on disk, and the entry-point script
/// must be present in <code>documentation/couchjs/couchjs-entry.js</code>.
/// Does NOT spawn a test subprocess on every call — that would double the
/// latency of every view query; instead, real failures surface as an
/// exception from <method>ExecuteMap</method>. Result is cached in a
/// process-private variable on first call so repeated ViewHandler checks
/// are free.</p>
Method IsAvailable() As %Boolean
{
    ; Process-private cache key off the current interpreter path so config
    ; flips (e.g., tests switching to /nonexistent) take effect immediately
    ; rather than being sticky for the process lifetime.
    Set tPath = ##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSPATH")
    If tPath = "" Quit 0
    If '##class(%File).Exists(tPath) Quit 0
    Set tEntry = ..GetEntryScriptPath()
    If '##class(%File).Exists(tEntry) Quit 0
    Quit 1
}

/// <p>Resolve the absolute path to <code>couchjs-entry.js</code>.</p>
/// <p>Checks the <code>JSRUNTIMESUBPROCESSENTRY</code> config override
/// first; if unset, derives it from the install root using the convention
/// <code>&lt;IRIS install dir&gt;/documentation/couchjs/couchjs-entry.js</code>
/// relative to the repo layout. Subclasses / tests may override via the
/// config key.</p>
ClassMethod GetEntryScriptPath() As %String [ Internal ]
{
    ; Allow an explicit override (tests, custom deployments).
    Set tOverride = ##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSENTRY")
    If tOverride '= "" Quit tOverride
    ; Fallback: derive from the repo layout. The IRISCouch classes live at
    ; <repo>/src/IRISCouch/..., so the entry script is two directories
    ; above the class folder.
    ; IRIS does not expose the source path at runtime, so use the project
    ; install marker: ^IRISCouch.Install("RepoRoot") is set by the
    ; installer; if absent, fall back to the hardcoded Windows dev path.
    Set tRoot = $Get(^IRISCouch.Install("RepoRoot"))
    If tRoot '= "" {
        Quit tRoot _ "\documentation\couchjs\couchjs-entry.js"
    }
    ; Last-resort default -- the Story 12.2 dev environment path. Operators
    ; in other environments must set JSRUNTIMESUBPROCESSENTRY.
    Quit "C:\git\iris-couch\documentation\couchjs\couchjs-entry.js"
}

/// <p>Execute a CouchDB map function against a single document.</p>
/// <p>Spawns a subprocess, sends <code>reset</code>, <code>add_fun</code>,
/// <code>map_doc</code>, parses the three response lines, and returns the
/// single-function emission array.</p>
/// @param pMapFn The JavaScript map function source
/// @param pDoc The target document as a <class>%DynamicObject</class>
/// @return %DynamicArray of <code>[key, value]</code> pairs
Method ExecuteMap(pMapFn As %String, pDoc As %DynamicObject) As %DynamicArray
{
    Set tResult = []
    Set tPipe = ""
    Try {
        Set tPipe = ..StartPipe()
        Do tPipe.WriteLine("[""reset""]")
        Do tPipe.WriteLine(..EncodeCommand("add_fun", pMapFn))
        Do tPipe.WriteLine(..EncodeCommandObj("map_doc", pDoc))
        Set tSC = tPipe.Flush()
        If $$$ISERR(tSC) {
            Do ..ThrowSubprocessError(tPipe, tSC)
        }
        ; Expect three response lines: reset ack, add_fun ack, map_doc result
        Do tPipe.ReadLine(.tResetAck)
        Do tPipe.ReadLine(.tAddFunAck)
        Do tPipe.ReadLine(.tMapResult)
        ; Also drain any trailing [log, ...] lines the subprocess may have
        ; emitted before the map_doc response -- couchjs interleaves them.
        ; We already captured the sequence in order, so the last non-log
        ; line is the map_doc result. If tMapResult starts with ["log", we
        ; keep reading. The literal we compare to is the 6-character prefix
        ; ["log" (open-bracket, quote, "log", quote); $Extract with a length
        ; of 7 would never match because it includes the trailing comma of
        ; the log payload.
        While ($Extract(tMapResult, 1, 6) = "[""log""") && '(tPipe.AtEnd()) {
            Do tPipe.ReadLine(.tMapResult)
        }
        ; tMapResult per share/server/views.js::mapDoc is an array of
        ; arrays-of-[key,value] pairs, one inner array per registered map
        ; function. We only registered one function, so unwrap the outer.
        If tMapResult = "" {
            Do ..ThrowSubprocessError(tPipe, $$$ERROR($$$GeneralError, "map_doc returned empty response"))
        }
        Set tOuter = [].%FromJSON(tMapResult)
        If tOuter.%Size() > 0 {
            Set tResult = tOuter.%Get(0)
        }
    }
    Catch ex {
        If $IsObject(tPipe) Do tPipe.Close()
        Throw ex
    }
    If $IsObject(tPipe) Do tPipe.Close()
    Quit tResult
}

/// <p>Execute a CouchDB reduce function over collected keys/values.</p>
/// <p>Spawns a subprocess, sends <code>reset</code> then the appropriate
/// <code>reduce</code> or <code>rereduce</code> command, and wraps the
/// result in the envelope expected by callers.</p>
/// @param pReduceFn The reduce function source
/// @param pKeys Emission keys (may be null in rereduce mode)
/// @param pValues Emission values
/// @param pRereduce 1 for rereduce, 0 for normal reduce
/// @return %DynamicObject envelope <code>{"ok":true, "value":&lt;reduced&gt;}</code>
Method ExecuteReduce(pReduceFn As %String, pKeys As %DynamicArray, pValues As %DynamicArray, pRereduce As %Boolean) As %DynamicObject
{
    Set tResult = {}
    Set tPipe = ""
    Try {
        Set tPipe = ..StartPipe()
        Do tPipe.WriteLine("[""reset""]")
        If pRereduce {
            ; ["rereduce", [<fn-source>], <values>]
            Set tCmd = ..EncodeRereduce(pReduceFn, pValues)
        } Else {
            ; ["reduce", [<fn-source>], [[k,v], ...]]
            Set tCmd = ..EncodeReduce(pReduceFn, pKeys, pValues)
        }
        Do tPipe.WriteLine(tCmd)
        Set tSC = tPipe.Flush()
        If $$$ISERR(tSC) {
            Do ..ThrowSubprocessError(tPipe, tSC)
        }
        Do tPipe.ReadLine(.tResetAck)
        Do tPipe.ReadLine(.tReduceLine)
        ; Drain trailing log lines if present (see ExecuteMap for why the
        ; literal is 6 chars, not 7).
        While ($Extract(tReduceLine, 1, 6) = "[""log""") && '(tPipe.AtEnd()) {
            Do tPipe.ReadLine(.tReduceLine)
        }
        If tReduceLine = "" {
            Do ..ThrowSubprocessError(tPipe, $$$ERROR($$$GeneralError, "reduce returned empty response"))
        }
        ; Reduce response shape: [true, [<reduced_value>]]
        Set tOuter = [].%FromJSON(tReduceLine)
        Set tReducedArr = tOuter.%Get(1)
        Set tReduced = ""
        If $IsObject(tReducedArr) && (tReducedArr.%Size() > 0) {
            Set tReduced = tReducedArr.%Get(0)
        }
        Do tResult.%Set("ok", 1, "boolean")
        Do tResult.%Set("value", tReduced)
    }
    Catch ex {
        If $IsObject(tPipe) Do tPipe.Close()
        Throw ex
    }
    If $IsObject(tPipe) Do tPipe.Close()
    Quit tResult
}

/// <p>Execute a <code>validate_doc_update</code> function (Story 12.3).</p>
/// <p>Spawns a subprocess, sends <code>reset</code>, registers a synthetic
/// ddoc that carries only the function under
/// <code>_design/__iriscouch_validate__</code>, then invokes via
/// <code>["ddoc", id, ["validate_doc_update"], [newDoc, oldDoc, userCtx, secObj]]</code>.
/// Approval returns <code>$$$OK</code>; rejection returns an error
/// <class>%Status</class> whose message is prefixed <code>forbidden: </code>,
/// <code>unauthorized: </code>, or <code>validate_error: </code>. Callers
/// (<method>Util.Error.RenderValidateError</method>) parse the prefix to map to
/// HTTP 401 / 403 / 500.</p>
/// <p>See <code>sources/couchdb/share/server/validate.js</code> for the thrown-
/// value → response mapping; <code>sources/couchdb/share/server/loop.js::DDoc</code>
/// for the <code>ddoc</code> registration + invocation protocol.</p>
/// @param pValidateFn The JavaScript function source
/// @param pNewDoc The document being written
/// @param pOldDoc The prior revision's body, or <code>$$$NULLOREF</code> on create
/// @param pUserCtx The user context <code>{name, roles}</code>
/// @param pSecObj The database <code>_security</code> object
/// @return %Status
Method ExecuteValidateDocUpdate(pValidateFn As %String, pNewDoc As %DynamicObject, pOldDoc As %DynamicObject, pUserCtx As %DynamicObject, pSecObj As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set tPipe = ""
    Try {
        Set tPipe = ..StartPipe()
        ; 1. reset
        Do tPipe.WriteLine("[""reset""]")
        ; 2. register a minimal ddoc body that exposes only the named fn.
        ;    The full ddoc is not required -- the couchjs protocol only reads
        ;    the field addressed by funPath. Use a synthetic id so we do not
        ;    collide with real ddocs.
        Set tDDocId = "_design/__iriscouch_validate__"
        Set tDDocBody = {}
        Do tDDocBody.%Set("validate_doc_update", pValidateFn)
        Do tPipe.WriteLine(..EncodeDDocRegister(tDDocId, tDDocBody))
        ; 3. invocation: ["ddoc", id, ["validate_doc_update"],
        ;                 [newDoc, oldDoc, userCtx, secObj]]
        Do tPipe.WriteLine(..EncodeValidateInvoke(tDDocId, pNewDoc, pOldDoc, pUserCtx, pSecObj))
        Set tFlushSC = tPipe.Flush()
        If $$$ISERR(tFlushSC) {
            Do ..ThrowSubprocessError(tPipe, tFlushSC)
        }
        ; Drain the three response lines: reset ack, new-ddoc ack, invoke result
        Do tPipe.ReadLine(.tResetAck)
        Do tPipe.ReadLine(.tNewDDocAck)
        Do tPipe.ReadLine(.tResult)
        While ($Extract(tResult, 1, 6) = "[""log""") && '(tPipe.AtEnd()) {
            Do tPipe.ReadLine(.tResult)
        }
        If tResult = "" {
            Do ..ThrowSubprocessError(tPipe, $$$ERROR($$$GeneralError, "validate_doc_update returned empty response"))
        }
        ; Interpret response:
        ;   "1" or "true" -> approved
        ;   {"forbidden":"..."} / {"unauthorized":"..."} -> rejection envelopes
        ;   ["error", <name>, <reason>] -> hard failure (compilation / runtime)
        ;   anything else -> pass through as "validate_error: <raw>"
        Set tTrimmed = $ZStrip(tResult, "<>WC")
        If (tTrimmed = "1") || (tTrimmed = "true") {
            Quit
        }
        Set tFirst = $Extract(tTrimmed, 1)
        If tFirst = "[" {
            ; Error line from the entry script
            Set tArr = [].%FromJSON(tTrimmed)
            If tArr.%Size() >= 3 {
                Set tSC = $$$ERROR($$$GeneralError, "validate_error: " _ tArr.%Get(2))
            } Else {
                Set tSC = $$$ERROR($$$GeneralError, "validate_error: " _ tTrimmed)
            }
            Quit
        }
        If tFirst = "{" {
            Set tObj = {}.%FromJSON(tTrimmed)
            If tObj.%IsDefined("forbidden") {
                Set tReason = tObj.%Get("forbidden")
                If '$IsObject(tReason), tReason = "" Set tReason = "rejected"
                Set tSC = $$$ERROR($$$GeneralError, "forbidden: " _ tReason)
                Quit
            }
            If tObj.%IsDefined("unauthorized") {
                Set tReason = tObj.%Get("unauthorized")
                If '$IsObject(tReason), tReason = "" Set tReason = "unauthorized"
                Set tSC = $$$ERROR($$$GeneralError, "unauthorized: " _ tReason)
                Quit
            }
        }
        ; Fall-through: unknown response shape -- surface as generic validate_error
        Set tSC = $$$ERROR($$$GeneralError, "validate_error: " _ tTrimmed)
    }
    Catch ex {
        ; Preserve the exception's status so callers can introspect. The Pipe
        ; is closed once in the common-exit path below; Pipe.Close is
        ; idempotent but we still avoid the redundant second call for clarity.
        Set tSC = ex.AsStatus()
        Quit
    }
    If $IsObject(tPipe) Do tPipe.Close()
    Quit tSC
}

/// <p>Execute a custom changes-feed filter (Story 12.3).</p>
/// <p>Spawns a subprocess, registers a synthetic ddoc with the single filter
/// function under the <code>filters.fn</code> property, then invokes via
/// <code>["ddoc", id, ["filters","fn"], [[doc], req]]</code>. Returns the
/// boolean from <code>[true, [bool]]</code>.</p>
/// <p>See <code>sources/couchdb/share/server/filter.js</code> for per-doc
/// invocation semantics. One-call-per-doc is acceptable for Story 12.3;
/// batching is deferred to Story 12.5 (persistent pool).</p>
/// @param pFilterFn The JavaScript filter function source
/// @param pDoc The candidate document
/// @param pReq The HTTP request object (method, path, query, headers)
/// @return %Boolean 1 to include, 0 to exclude
Method ExecuteFilter(pFilterFn As %String, pDoc As %DynamicObject, pReq As %DynamicObject) As %Boolean
{
    Set tInclude = 0
    Set tPipe = ""
    Try {
        Set tPipe = ..StartPipe()
        Do tPipe.WriteLine("[""reset""]")
        Set tDDocId = "_design/__iriscouch_filter__"
        Set tDDocBody = {}
        Set tFilters = {}
        Do tFilters.%Set("fn", pFilterFn)
        Do tDDocBody.%Set("filters", tFilters)
        Do tPipe.WriteLine(..EncodeDDocRegister(tDDocId, tDDocBody))
        Do tPipe.WriteLine(..EncodeFilterInvoke(tDDocId, pDoc, pReq))
        Set tFlushSC = tPipe.Flush()
        If $$$ISERR(tFlushSC) {
            Do ..ThrowSubprocessError(tPipe, tFlushSC)
        }
        Do tPipe.ReadLine(.tResetAck)
        Do tPipe.ReadLine(.tNewDDocAck)
        Do tPipe.ReadLine(.tResult)
        While ($Extract(tResult, 1, 6) = "[""log""") && '(tPipe.AtEnd()) {
            Do tPipe.ReadLine(.tResult)
        }
        If tResult = "" {
            Do ..ThrowSubprocessError(tPipe, $$$ERROR($$$GeneralError, "filters returned empty response"))
        }
        Set tTrimmed = $ZStrip(tResult, "<>WC")
        ; Expected shape: [true, [<bool>]]. Error shape: ["error",...]. Treat
        ; error shape as "exclude" with a log -- failing a filter fn on a doc
        ; should not poison the entire feed. Matches CouchDB behaviour where
        ; the filter returning falsy excludes the doc.
        If $Extract(tTrimmed, 1) '= "[" {
            Set tInclude = 0
            Quit
        }
        Set tArr = [].%FromJSON(tTrimmed)
        If tArr.%Size() = 0 {
            Set tInclude = 0
            Quit
        }
        If tArr.%Get(0) = "error" {
            Set tInclude = 0
            Quit
        }
        Set tInner = tArr.%Get(1)
        If '$IsObject(tInner) || (tInner.%Size() = 0) {
            Set tInclude = 0
            Quit
        }
        Set tBool = tInner.%Get(0)
        Set tInclude = $Select(tBool: 1, 1: 0)
    }
    Catch ex {
        If $IsObject(tPipe) Do tPipe.Close()
        Throw ex
    }
    If $IsObject(tPipe) Do tPipe.Close()
    Quit tInclude
}

/// <p>Build a <code>["ddoc","new",&lt;id&gt;,&lt;body&gt;]</code> line.</p>
ClassMethod EncodeDDocRegister(pDDocId As %String, pDDocBody As %DynamicObject) As %String [ Internal ]
{
    Set tArr = []
    Do tArr.%Push("ddoc")
    Do tArr.%Push("new")
    Do tArr.%Push(pDDocId)
    Do tArr.%Push(pDDocBody)
    Quit tArr.%ToJSON()
}

/// <p>Build a <code>["ddoc",&lt;id&gt;,["validate_doc_update"],[newDoc,oldDoc,userCtx,secObj]]</code>
/// line. Emits JSON <code>null</code> (not the string <code>"null"</code>) for
/// a missing <var>pOldDoc</var> per
/// <code>.claude/rules/iris-objectscript-basics.md::feedback_json_null_pattern</code>.</p>
ClassMethod EncodeValidateInvoke(pDDocId As %String, pNewDoc As %DynamicObject, pOldDoc As %DynamicObject, pUserCtx As %DynamicObject, pSecObj As %DynamicObject) As %String [ Internal ]
{
    Set tArr = []
    Do tArr.%Push("ddoc")
    Do tArr.%Push(pDDocId)
    Set tFunPath = []
    Do tFunPath.%Push("validate_doc_update")
    Do tArr.%Push(tFunPath)
    Set tFunArgs = []
    Do tFunArgs.%Push(pNewDoc)
    If $IsObject(pOldDoc) {
        Do tFunArgs.%Push(pOldDoc)
    } Else {
        ; Emit JSON null for a creation (no prior rev). The literal string
        ; "null" would be a 4-char JSON string, not a JSON null token.
        Do tFunArgs.%Set(tFunArgs.%Size(), "", "null")
    }
    Do tFunArgs.%Push(pUserCtx)
    Do tFunArgs.%Push(pSecObj)
    Do tArr.%Push(tFunArgs)
    Quit tArr.%ToJSON()
}

/// <p>Build a <code>["ddoc",&lt;id&gt;,["filters","fn"],[[doc],req]]</code> line.</p>
ClassMethod EncodeFilterInvoke(pDDocId As %String, pDoc As %DynamicObject, pReq As %DynamicObject) As %String [ Internal ]
{
    Set tArr = []
    Do tArr.%Push("ddoc")
    Do tArr.%Push(pDDocId)
    Set tFunPath = []
    Do tFunPath.%Push("filters")
    Do tFunPath.%Push("fn")
    Do tArr.%Push(tFunPath)
    Set tFunArgs = []
    Set tDocsArr = []
    Do tDocsArr.%Push(pDoc)
    Do tFunArgs.%Push(tDocsArr)
    If $IsObject(pReq) {
        Do tFunArgs.%Push(pReq)
    } Else {
        Do tFunArgs.%Set(tFunArgs.%Size(), "", "null")
    }
    Do tArr.%Push(tFunArgs)
    Quit tArr.%ToJSON()
}

/// <p>Allocate and open a new Pipe instance pointing at the configured
/// interpreter and entry script.</p>
/// <p>Throws a subprocess error if the interpreter is not available.</p>
Method StartPipe() As IRISCouch.JSRuntime.Subprocess.Pipe [ Internal ]
{
    Set tPath = ##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSPATH")
    Set tEntry = ..GetEntryScriptPath()
    If '..IsAvailable() {
        Throw ##class(%Exception.General).%New("view execution", "subprocess_error", "", "Subprocess JSRuntime unavailable: interpreter=" _ tPath _ " entry=" _ tEntry)
    }
    Set tPipe = ##class(IRISCouch.JSRuntime.Subprocess.Pipe).%New()
    Set tSC = tPipe.Open(tPath, tEntry)
    If $$$ISERR(tSC) {
        Throw ##class(%Exception.General).%New("view execution", "subprocess_error", "", "Pipe.Open failed: " _ $System.Status.GetErrorText(tSC))
    }
    Quit tPipe
}

/// <p>Build an <code>["add_fun", "&lt;source&gt;"]</code> line.</p>
ClassMethod EncodeCommand(pCmd As %String, pSource As %String) As %String [ Internal ]
{
    ; Use %DynamicArray so quoting / backslashes / unicode are safe.
    Set tArr = []
    Do tArr.%Push(pCmd)
    Do tArr.%Push(pSource)
    Quit tArr.%ToJSON()
}

/// <p>Build a <code>["map_doc", &lt;doc-json&gt;]</code> line.</p>
ClassMethod EncodeCommandObj(pCmd As %String, pObj As %DynamicObject) As %String [ Internal ]
{
    Set tArr = []
    Do tArr.%Push(pCmd)
    Do tArr.%Push(pObj)
    Quit tArr.%ToJSON()
}

/// <p>Build a <code>["reduce", [&lt;fn-src&gt;], [[k,v],...]]</code> line.</p>
ClassMethod EncodeReduce(pReduceFn As %String, pKeys As %DynamicArray, pValues As %DynamicArray) As %String [ Internal ]
{
    Set tFns = []
    Do tFns.%Push(pReduceFn)
    Set tKvs = []
    Set tI = 0
    If $IsObject(pKeys) && $IsObject(pValues) {
        Set tN = pKeys.%Size()
        While tI < tN {
            Set tPair = []
            Do tPair.%Push(pKeys.%Get(tI))
            Do tPair.%Push(pValues.%Get(tI))
            Do tKvs.%Push(tPair)
            Set tI = tI + 1
        }
    }
    Set tArr = []
    Do tArr.%Push("reduce")
    Do tArr.%Push(tFns)
    Do tArr.%Push(tKvs)
    Quit tArr.%ToJSON()
}

/// <p>Build a <code>["rereduce", [&lt;fn-src&gt;], &lt;values&gt;]</code> line.</p>
ClassMethod EncodeRereduce(pReduceFn As %String, pValues As %DynamicArray) As %String [ Internal ]
{
    Set tFns = []
    Do tFns.%Push(pReduceFn)
    Set tArr = []
    Do tArr.%Push("rereduce")
    Do tArr.%Push(tFns)
    Do tArr.%Push(pValues)
    Quit tArr.%ToJSON()
}

/// <p>Raise a subprocess-error exception with diagnostic context.</p>
/// <p>Includes the interpreter path, exit code (if known), and first 2KB
/// of stderr from the Pipe so operators can triage crashes without
/// re-running.</p>
ClassMethod ThrowSubprocessError(pPipe As IRISCouch.JSRuntime.Subprocess.Pipe, pSC As %Status) [ Internal ]
{
    Set tPath = ##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSPATH")
    Set tStderr = ""
    If $IsObject(pPipe) {
        Set tStderr = pPipe.ReadStderrSnippet()
    }
    Set tReason = "Subprocess JSRuntime error; interpreter=" _ tPath
    If $$$ISERR(pSC) {
        Set tReason = tReason _ "; status=" _ $System.Status.GetErrorText(pSC)
    }
    If tStderr '= "" {
        Set tReason = tReason _ "; stderr=" _ $Extract(tStderr, 1, 512)
    }
    Throw ##class(%Exception.General).%New("view execution", "subprocess_error", "", tReason)
}

/// <p>Throw <code>not_yet_implemented</code> for 12.3-scope methods.</p>
ClassMethod ThrowNotYetImplemented(pSubsystem As %String) [ Internal ]
{
    Set tReason = "Subprocess JSRuntime " _ pSubsystem _ " is not yet implemented (Story 12.3 scope). See documentation/js-runtime.md."
    Throw ##class(%Exception.General).%New(pSubsystem, "not_implemented", "", tReason)
}

}
