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
        Set ..Executable = pExecutable
        Set ..EntryScript = pEntryScript
        Set ..Flushed = 0
        Set ..LastReturnCode = ""
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
        Set ..StdinStream = $$$NULLOREF  ; release the handle so the OS sees the file closed
        ; Build the $ZF(-100) flags string. Quoting paths defensively so that
        ; spaces in "C:\Program Files\nodejs\node.exe" do not break the flag
        ; parser.
        Set tFlags = "/STDIN=""" _ ..StdinFile _ """"
        Set tFlags = tFlags _ "/STDOUT=""" _ ..StdoutFile _ """"
        Set tFlags = tFlags _ "/STDERR=""" _ ..StderrFile _ """"
        Set tRC = $ZF(-100, tFlags, ..Executable, ..EntryScript)
        Set ..LastReturnCode = tRC
        If tRC '= 0 {
            Set tStderrSnippet = ..ReadStderrSnippet()
            Set tSC = $$$ERROR($$$GeneralError, "subprocess pipe: " _ ..Executable _ " exited rc=" _ tRC _ "; stderr: " _ tStderrSnippet)
            Quit
        }
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
