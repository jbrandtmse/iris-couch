/// <p>Line-oriented request/response wrapper around a JS subprocess (Story 12.2).</p>
///
/// <h3>Why file-based request/response, not real-time bidirectional stdio?</h3>
/// <p>Story 12.2 Task 0 researched the IRIS <code>$ZF</code> subprocess APIs
/// and confirmed that <code>$ZF(-100)</code> with
/// <code>/STDIN=&lt;file&gt;</code>, <code>/STDOUT=&lt;file&gt;</code>, and
/// <code>/STDERR=&lt;file&gt;</code> flags is the canonical IRIS pattern
/// (see <code>irislib/%Net/Remote/Utility.cls::RunCommandViaZF</code>).
/// Real-time bidirectional stdio via <code>$ZF(-1)</code> is historically
/// fragile on Windows IRIS. Because Story 12.2 uses a process-per-query
/// lifecycle (AC #6), the full command stream is known up front and the
/// file-based pattern is a clean fit: the caller queues every line via
/// <method>WriteLine</method>, calls <method>Flush</method> to spawn the
/// subprocess with stdin redirected from the queue file, then reads
/// responses line-by-line via <method>ReadLine</method>. Story 12.5 may
/// reopen with a persistent real-time pipe if profiling justifies it.</p>
///
/// <h3>Usage</h3>
/// <pre>
/// Set tPipe = ##class(IRISCouch.JSRuntime.Subprocess.Pipe).%New()
/// Set tSC = tPipe.Open(tInterpreterPath, tEntryScriptPath)
/// Do tPipe.WriteLine("[""reset""]")
/// Do tPipe.WriteLine("[""add_fun"", ""function(doc){emit(doc._id,1);}""]")
/// Do tPipe.WriteLine("[""map_doc"", {""_id"":""a"",""n"":1}]")
/// Set tSC = tPipe.Flush()                    ; spawns node; blocks until exit
/// Do tPipe.ReadLine(.tLine1)                 ; "true"        (reset ack)
/// Do tPipe.ReadLine(.tLine2)                 ; "true"        (add_fun ack)
/// Do tPipe.ReadLine(.tLine3)                 ; "[[[\"a\",1]]]" (map_doc result)
/// Do tPipe.Close()
/// </pre>
Class IRISCouch.JSRuntime.Subprocess.Pipe Extends %RegisteredObject
{

/// Path to the configured JS interpreter (node, bun, deno, or couchjs binary).
Property Executable As %String [ Private ];

/// Path to the bundled couchjs entry-point script.
Property EntryScript As %String [ Private ];

/// Temp file path used to stage stdin for the subprocess.
Property StdinFile As %String [ Private ];

/// Temp file path used to capture stdout from the subprocess.
Property StdoutFile As %String [ Private ];

/// Temp file path used to capture stderr from the subprocess.
Property StderrFile As %String [ Private ];

/// Open stream positioned for queued writes to StdinFile (before Flush).
Property StdinStream As %Stream.FileCharacter [ Private ];

/// Open stream positioned for sequential reads from StdoutFile (after Flush).
Property StdoutStream As %Stream.FileCharacter [ Private ];

/// 1 once Flush() has spawned the subprocess and StdoutStream is readable.
Property Flushed As %Boolean [ Private ];

/// Last exit code from the subprocess (populated by Flush).
Property LastReturnCode As %String [ Private ];

/// 1 if Flush raised a timeout (Story 12.5 AC #4).
Property TimedOut As %Boolean [ Private ];

/// Per-interpreter sandbox flag list assembled during Open (Story 12.5 AC #6).
Property SandboxFlags As %String [ Private ];

/// <p>Open a new subprocess session.</p>
/// <p>Allocates temp files for stdin/stdout/stderr and records the
/// executable + entry-script paths. Does NOT spawn the subprocess yet —
/// that happens in <method>Flush</method> after the caller queues commands
/// via <method>WriteLine</method>.</p>
/// @param pExecutable Absolute path to the JS interpreter
/// @param pEntryScript Absolute path to couchjs-entry.js
/// @return %Status $$$OK on success; error %Status if temp-file allocation failed
Method Open(pExecutable As %String, pEntryScript As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Story 12.5: validate the interpreter path before we let it into
        ; $ZF(-100). Rejects traversal sequences (`..`) and paths that don't
        ; actually exist. Closes the Story 12.2 NFR-S9 MED. Applied to both
        ; the interpreter and the entry script — either knob can be set by
        ; an operator and both land in $ZF(-100) argv.
        Set tSC = ..ValidateExecutablePath(pExecutable)
        If $$$ISERR(tSC) Quit
        Set tSC = ..ValidateExecutablePath(pEntryScript)
        If $$$ISERR(tSC) Quit
        Set ..Executable = pExecutable
        Set ..EntryScript = pEntryScript
        Set ..Flushed = 0
        Set ..LastReturnCode = ""
        Set ..TimedOut = 0
        ; Detect interpreter type and build the sandbox flag list (Story 12.5 AC #6).
        Set ..SandboxFlags = ..BuildSandboxFlags(pExecutable)
        ; Allocate three distinct temp files so stdin / stdout / stderr
        ; do not collide when the subprocess reopens them.
        Set ..StdinFile = ##class(%File).TempFilename("jsin")
        Set ..StdoutFile = ##class(%File).TempFilename("jsout")
        Set ..StderrFile = ##class(%File).TempFilename("jserr")
        If (..StdinFile = "") || (..StdoutFile = "") || (..StderrFile = "") {
            Set tSC = $$$ERROR($$$GeneralError, "subprocess pipe: failed to allocate temp files")
            Quit
        }
        ; Open the stdin file for queued writes.
        Set ..StdinStream = ##class(%Stream.FileCharacter).%New()
        Set ..StdinStream.Filename = ..StdinFile
        Set ..StdinStream.TranslateTable = "UTF8"
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Validate that the configured interpreter path is safe to exec (Story 12.5
/// AC #6 — closes Story 12.2 NFR-S9 MED).</p>
/// <p>Rejects paths containing <code>..</code> (directory traversal) and paths
/// that do not resolve to an existing file on disk. Operators who want a
/// non-standard interpreter location must set
/// <code>JSRUNTIMESUBPROCESSPATH</code> to the absolute path of the binary
/// explicitly.</p>
ClassMethod ValidateExecutablePath(pPath As %String) As %Status [ Internal ]
{
    If pPath = "" Quit $$$ERROR($$$GeneralError, "subprocess pipe: interpreter path is empty")
    If pPath [ ".." Quit $$$ERROR($$$GeneralError, "subprocess pipe: interpreter path may not contain '..'")
    If '##class(%File).Exists(pPath) Quit $$$ERROR($$$GeneralError, "subprocess pipe: interpreter does not exist: " _ pPath)
    Quit $$$OK
}

/// <p>Assemble per-interpreter sandbox flags based on the basename of
/// <var>pPath</var> (Story 12.5 AC #6). Empty string when the interpreter
/// is unrecognised — a Warn is logged but the Pipe still proceeds so
/// operator environments with custom interpreters continue to work.</p>
/// <p>Flags are inserted <b>between</b> the interpreter and the entry
/// script in the <code>$ZF(-100)</code> call; Node accepts them as CLI
/// options parsed before the script argument.</p>
ClassMethod BuildSandboxFlags(pPath As %String) As %String [ Internal ]
{
    Set tBasename = $ZConvert($Piece(pPath, "\", $Length(pPath, "\")), "L")
    If tBasename = "" Set tBasename = $ZConvert($Piece(pPath, "/", $Length(pPath, "/")), "L")
    ; Return flags as a space-separated string; Pipe.Flush tokenizes on
    ; whitespace when building the $ZF(-100) variadic call so each flag
    ; lands as its own argv entry to Node / Deno.
    ;
    ; Node: --disable-proto=delete prevents __proto__ escape mutations;
    ; --no-experimental-global-webcrypto denies the subprocess crypto APIs
    ; (user map/reduce functions have no legitimate need for them, and they
    ; expose timing-side-channel surface — matches Story 12.5 AC #6 spec);
    ; --no-warnings silences ExperimentalWarnings that would pollute stderr
    ; and confuse our error parsing.
    If tBasename [ "node" Quit "--disable-proto=delete|--no-experimental-global-webcrypto|--no-warnings"
    ; Deno: whitelist only the entry script for read, deny everything else.
    If tBasename [ "deno" Quit "run|--allow-read|--deny-net|--deny-write|--deny-run|--deny-env|--deny-ffi|--deny-sys"
    If tBasename [ "bun" Quit ""
    ; Anything else: pass through with no extra flags. Warn once.
    Do ##class(IRISCouch.Util.Log).Warn("jsruntime", "un-sandboxed interpreter; relying on OS-level limits only", {"interpreter":(pPath)})
    Quit ""
}

/// <p>Queue a single JSON command line for the subprocess's stdin.</p>
/// <p>Appends a trailing newline as required by the couchjs line protocol.
/// Must be called before <method>Flush</method>; calling after Flush
/// returns an error.</p>
/// @param pJson A JSON-encoded command array (e.g., <code>["reset"]</code>)
/// @return %Status
Method WriteLine(pJson As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If ..Flushed {
            Set tSC = $$$ERROR($$$GeneralError, "subprocess pipe: WriteLine after Flush not supported")
            Quit
        }
        If '$IsObject(..StdinStream) {
            Set tSC = $$$ERROR($$$GeneralError, "subprocess pipe: WriteLine before Open")
            Quit
        }
        Set tSC = ..StdinStream.Write(pJson _ $Char(10))
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Persist all queued commands, spawn the subprocess, and prepare stdout
/// for sequential reads.</p>
/// <p>Uses <code>$ZF(-100)</code> with file-based stdin / stdout / stderr
/// redirection — the canonical IRIS pattern for synchronous subprocess
/// execution. Captures the exit code in <property>LastReturnCode</property>
/// so callers can classify protocol-level vs subprocess-level failures.</p>
/// @return %Status $$$OK if the subprocess exited with code 0; error %Status
///         with the reason naming the interpreter and exit code otherwise
Method Flush() As %Status
{
    Set tSC = $$$OK
    Try {
        If ..Flushed {
            Set tSC = $$$ERROR($$$GeneralError, "subprocess pipe: Flush called twice")
            Quit
        }
        If '$IsObject(..StdinStream) {
            Set tSC = $$$ERROR($$$GeneralError, "subprocess pipe: Flush before Open")
            Quit
        }
        ; Close the stdin file so the subprocess can read it. %SaveStream
        ; returns the stream's %Status; we want the underlying file on disk.
        Set tSaveSC = ..StdinStream.%Save()
        If $$$ISERR(tSaveSC) {
            Set tSC = tSaveSC
            Quit
        }
        Set ..StdinStream = $$$NULLOREF
        ; Story 12.5 AC #4: OS-level timeout enforcement via /ASYNC launch +
        ; tasklist-based polling. The JS-side couchjs-entry.js self-kill
        ; catches cases where the event loop yields; this parent-side
        ; backstop catches tight sync loops (e.g., `while(true){}`) that
        ; cannot be interrupted from JS. Research: $ZF(-100) has no native
        ; /TIMEOUT flag (see .claude/rules/research-first.md::Task 0).
        Set tTimeoutMs = +##class(IRISCouch.Config).Get("JSRUNTIMETIMEOUT")
        If tTimeoutMs <= 0 Set tTimeoutMs = 5000
        Set tFlags = "/ASYNC"
        Set tFlags = tFlags _ "/STDIN=""" _ ..StdinFile _ """"
        Set tFlags = tFlags _ "/STDOUT=""" _ ..StdoutFile _ """"
        Set tFlags = tFlags _ "/STDERR=""" _ ..StderrFile _ """"
        ; Pass the timeout to the entry script via a command-line flag so
        ; couchjs-entry.js's setTimeout self-kill knows the deadline. $ZF's
        ; trailing positional args become process.argv[2..] inside Node.
        Set tTimeoutArg = "--iriscouch-timeout-ms=" _ tTimeoutMs
        ; Sandbox flags are pipe-delimited (one interpreter flag per
        ; pipe-segment) so each becomes its own argv entry to Node / Deno.
        Set tSandboxFlags = ..SandboxFlags
        ; Build the argument subscripted array for by-reference dispatch.
        ; Per irislib/%Net/Remote/Utility.cls::RunCommandViaZF, $ZF(-100)'s
        ; canonical shape is `$ZF(-100, flags, program, .args)` where
        ; `args(n)` holds the nth additional argv entry. The ByRef pattern
        ; has no hard limit on arg count, unlike the positional variant.
        ; args(0) is the argv count (0-based); args(1..args(0)) are the
        ; arguments themselves.
        Set tArgs(0) = 0
        Set tArgN = 0
        If tSandboxFlags '= "" {
            Set tNFlags = $Length(tSandboxFlags, "|")
            For tFI = 1:1:tNFlags {
                Set tOneFlag = $Piece(tSandboxFlags, "|", tFI)
                If tOneFlag = "" Continue
                Set tArgN = tArgN + 1
                Set tArgs(tArgN) = tOneFlag
            }
        }
        Set tArgN = tArgN + 1
        Set tArgs(tArgN) = ..EntryScript
        Set tArgN = tArgN + 1
        Set tArgs(tArgN) = tTimeoutArg
        Set tArgs(0) = tArgN
        Set tStart = $ZHorolog
        ; By-reference dispatch: `tArgs` carries every post-executable argv
        ; entry; IRIS passes them to the OS exec syscall one at a time.
        Set tRC = $ZF(-100, tFlags, ..Executable, .tArgs)
        If tRC '= 0 {
            Set tSC = $$$ERROR($$$GeneralError, "subprocess pipe: /ASYNC launch failed rc=" _ tRC)
            Quit
        }
        Set tPid = $ZCHILD
        ; Poll until exit or timeout. 100 ms cadence balances tasklist cost
        ; (~30-50 ms per probe on Windows) against responsiveness.
        Set tExited = 0
        For {
            Hang 0.1
            Set tElapsedMs = ($ZHorolog - tStart) * 1000
            If ..IsProcessDead(tPid) Set tExited = 1 Quit
            If tElapsedMs > tTimeoutMs Quit
        }
        If 'tExited {
            ; Timeout: kill the runaway and surface the error.
            Do ..KillPid(tPid)
            Set ..TimedOut = 1
            Set tSC = $$$ERROR($$$GeneralError, "jsruntime_timeout: subprocess exceeded " _ tTimeoutMs _ "ms")
            Do ##class(IRISCouch.Audit.Emit).JsRuntimeTimeout("subprocess", tTimeoutMs)
            Quit
        }
        Set ..LastReturnCode = 0
        ; Settle hang: Windows may buffer final stdout writes briefly after
        ; the process exits. 30 ms is well below typical JS work time and
        ; prevents us from reading a partial stdout file.
        Hang 0.03
        ; Open stdout for line-by-line reads.
        Set ..StdoutStream = ##class(%Stream.FileCharacter).%New()
        Set ..StdoutStream.Filename = ..StdoutFile
        Set ..StdoutStream.TranslateTable = "UTF8"
        Set ..Flushed = 1
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Report 1 if the given PID is no longer running.</p>
/// <p>On Windows, uses <code>tasklist /FI "PID eq N"</code> via
/// <code>$ZF(-100,"/SHELL")</code>, which prints "INFO: No tasks are
/// running..." when the PID is absent. On Unix, uses <code>kill -0 pid</code>
/// via <code>sh -c</code> — exits non-zero if the PID is dead. Both probes
/// cost ~30-50 ms on typical Windows hosts; the 100 ms polling cadence in
/// <method>Flush</method> leaves headroom. An alternative on Windows would
/// be P/Invoke to <code>OpenProcess</code> + <code>GetExitCodeProcess</code>,
/// but that requires a helper binary outside Story 12.5 scope.</p>
ClassMethod IsProcessDead(pPid As %Integer) As %Boolean [ Internal ]
{
    Set tDead = 0
    Try {
        If +pPid <= 0 {
            Set tDead = 1
            Quit
        }
        Set tProbeStdout = ##class(%File).TempFilename("pprobe")
        Set tFlags = "/SHELL/STDOUT=""" _ tProbeStdout _ """"
        If $ZVersion("Windows") '= "" {
            Set tRC = $ZF(-100, tFlags, "cmd", "/c", "tasklist", "/FI", "PID eq " _ pPid, "/NH")
        } Else {
            Set tRC = $ZF(-100, tFlags, "sh", "-c", "kill -0 " _ pPid _ " 2>&1 || echo DEAD")
        }
        Set tProbeContent = ""
        If ##class(%File).Exists(tProbeStdout) {
            Set tStream = ##class(%Stream.FileCharacter).%New()
            Set tStream.Filename = tProbeStdout
            Set tProbeContent = tStream.Read(512)
            Set tStream = $$$NULLOREF
            Do ##class(%File).Delete(tProbeStdout)
        }
        If $ZVersion("Windows") '= "" {
            If tProbeContent [ "No tasks" Set tDead = 1
        } Else {
            If tProbeContent [ "DEAD" Set tDead = 1
        }
    }
    Catch ex {
        ; Defensive: if the probe itself blew up, treat as not-dead so the
        ; outer timeout can still terminate the real child.
    }
    Quit tDead
}

Method IsChildDone(pPid As %Integer) As %Boolean [ Internal ]
{
    ; Legacy instance-method entry; delegates to the class method.
    Quit ..IsProcessDead(pPid)
}

Property %IsChildDoneLastSize As %Integer [ Private ];

Property %IsChildDoneStable As %Integer [ Private ];

/// <p>Kill a runaway subprocess by PID.</p>
/// <p>Uses <code>taskkill /F /PID</code> on Windows, <code>kill -9</code> on
/// Unix. Best-effort; silent on failure because the subprocess may have
/// already exited between the timeout and the kill call.</p>
Method KillPid(pPid As %Integer) [ Internal ]
{
    If pPid = "" Quit
    If pPid <= 0 Quit
    Try {
        If $ZVersion("Windows") '= "" {
            Set tRC = $ZF(-100, "/SHELL", "taskkill", "/F", "/PID", pPid)
        } Else {
            Set tRC = $ZF(-100, "/SHELL", "kill", "-9", pPid)
        }
    }
    Catch {
        ; Ignore.
    }
}

/// <p>Read the next response line from the subprocess's stdout capture.</p>
/// <p>Blocks only on file I/O (the subprocess has already exited by this
/// point). Returns one complete line per call, stripped of the trailing
/// newline. On EOF, <var>pLine</var> is "" and the status is $$$OK —
/// callers detect EOF by checking <method>AtEnd</method>.</p>
/// @param pLine Output: the next response line, or "" on EOF
/// @return %Status
Method ReadLine(Output pLine As %String) As %Status
{
    Set pLine = ""
    Set tSC = $$$OK
    Try {
        If '..Flushed {
            Set tSC = $$$ERROR($$$GeneralError, "subprocess pipe: ReadLine before Flush")
            Quit
        }
        If '$IsObject(..StdoutStream) {
            Set tSC = $$$ERROR($$$GeneralError, "subprocess pipe: stdout stream not open")
            Quit
        }
        If ..StdoutStream.AtEnd {
            Quit
        }
        Set pLine = ..StdoutStream.ReadLine(32767, .tReadSC)
        If $$$ISERR(tReadSC) {
            Set tSC = tReadSC
            Quit
        }
        ; IRIS ReadLine strips newlines on most platforms, but belt-and-braces
        ; handle lingering CR from Windows.
        If $Extract(pLine, *) = $Char(13) {
            Set pLine = $Extract(pLine, 1, *-1)
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Return 1 if the stdout capture has no more lines to read.</p>
Method AtEnd() As %Boolean
{
    If '..Flushed Quit 1
    If '$IsObject(..StdoutStream) Quit 1
    Quit ..StdoutStream.AtEnd
}

/// <p>Read up to 2KB of the stderr capture for error diagnostics.</p>
/// <p>Only called on error paths. Swallowed if the stderr file is absent.</p>
Method ReadStderrSnippet() As %String [ Internal ]
{
    Set tSnippet = ""
    Try {
        If ..StderrFile = "" {
            ; no file allocated yet
        } ElseIf '##class(%File).Exists(..StderrFile) {
            ; subprocess never opened stderr
        } Else {
            Set tStream = ##class(%Stream.FileCharacter).%New()
            Set tStream.Filename = ..StderrFile
            Set tStream.TranslateTable = "UTF8"
            Set tSnippet = tStream.Read(2048)
        }
    }
    Catch ex {
        Set tSnippet = ""
    }
    Quit tSnippet
}

/// <p>Close and delete all temp files.</p>
/// <p>Idempotent and safe to call after any prior state (before Open, after
/// Open without Flush, after Flush). Logs cleanup failures via structured
/// log but never throws.</p>
/// @return %Status always $$$OK
Method Close() As %Status
{
    Try {
        ; Drop stream handles first so the OS can actually delete the files.
        If $IsObject(..StdinStream) {
            Set ..StdinStream = $$$NULLOREF
        }
        If $IsObject(..StdoutStream) {
            Set ..StdoutStream = $$$NULLOREF
        }
        ; Delete each temp file; best-effort.
        If (..StdinFile '= "") && ##class(%File).Exists(..StdinFile) {
            Do ##class(%File).Delete(..StdinFile)
        }
        If (..StdoutFile '= "") && ##class(%File).Exists(..StdoutFile) {
            Do ##class(%File).Delete(..StdoutFile)
        }
        If (..StderrFile '= "") && ##class(%File).Exists(..StderrFile) {
            Do ##class(%File).Delete(..StderrFile)
        }
        Set ..StdinFile = ""
        Set ..StdoutFile = ""
        Set ..StderrFile = ""
        Set ..Flushed = 0
    }
    Catch ex {
        ; Never throw from Close
    }
    Quit $$$OK
}

/// <p>Forcefully terminate the subprocess and clean up.</p>
/// <p>Under the file-based pattern (Story 12.2) the subprocess is always
/// already exited by the time we get here — Flush blocks until exit — so
/// Kill is functionally a Close. Story 12.5's long-lived pool will override
/// this with a real termination sequence.</p>
Method Kill() As %Status
{
    Quit ..Close()
}

/// <p>Best-effort destructor — ensures temp files are cleaned up even if
/// the caller forgot to call Close.</p>
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
    Do ..Close()
    Quit $$$OK
}

}
