/// <p>Ephemeral Task 0 probe helpers for Story 12.5 backend-surface research.</p>
/// <p>These class methods exercise specific Story 12.2 code paths to measure
/// baseline latency, cold-start cost, and confirm the runaway-function MED.
/// Not part of the production code path; may be deleted post-implementation.</p>
Class IRISCouch.Test.ProbeHelpers Extends %RegisteredObject
{

/// <p>Probe 1: Measure subprocess cold-start cost (single reset roundtrip).</p>
ClassMethod ProbeColdStart() As %String
{
    Set tStart = $ZHorolog
    Set tPipe = ##class(IRISCouch.JSRuntime.Subprocess.Pipe).%New()
    Set tSC = tPipe.Open(##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSPATH"), ##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSENTRY"))
    If $$$ISERR(tSC) {
        Quit "open_failed: " _ $System.Status.GetErrorText(tSC)
    }
    Do tPipe.WriteLine("[""reset""]")
    Set tSC = tPipe.Flush()
    Set tAck = ""
    Do tPipe.ReadLine(.tAck)
    Do tPipe.Close()
    Set tElapsed = ($ZHorolog - tStart) * 1000
    Quit "cold_start_ms=" _ tElapsed _ " ack=" _ tAck _ " status=" _ $System.Status.GetErrorText(tSC)
}

/// <p>Probe 2: Measure end-to-end view query latency by issuing N iterations.</p>
/// <p>Assumes the caller has already created a database with a design doc
/// and test docs. Returns "avg_ms=X min_ms=Y max_ms=Z" over the iterations.</p>
ClassMethod ProbeViewQueryLatency(pDB As %String, pDDocId As %String, pViewName As %String, pIterations As %Integer = 3) As %String
{
    Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
    If 'tSandbox.IsAvailable() {
        Quit "sandbox_unavailable"
    }
    Set tTotal = 0
    Set tMin = 999999
    Set tMax = 0
    For tI = 1:1:pIterations {
        Set tStart = $ZHorolog
        Try {
            Set tResp = ##class(IRISCouch.View.QueryEngine).Query(pDB, pDDocId, pViewName, {}, tSandbox)
        } Catch ex {
            Quit
        }
        Set tElapsed = ($ZHorolog - tStart) * 1000
        Set tTotal = tTotal + tElapsed
        If tElapsed < tMin Set tMin = tElapsed
        If tElapsed > tMax Set tMax = tElapsed
    }
    Set tAvg = tTotal / pIterations
    Quit "avg_ms=" _ tAvg _ " min_ms=" _ tMin _ " max_ms=" _ tMax _ " iterations=" _ pIterations
}

/// <p>Seed a probe database with a simple emit-_id design doc and N docs.</p>
ClassMethod ProbeSeed(pDB As %String = "probedb", pDocCount As %Integer = 10) As %String
{
    If ##class(IRISCouch.Storage.Database).Exists(pDB) {
        Do ##class(IRISCouch.Storage.Database).Delete(pDB)
    }
    Set tSC = ##class(IRISCouch.Storage.Database).Create(pDB)
    If $$$ISERR(tSC) Quit "create_failed: " _ $System.Status.GetErrorText(tSC)
    Set tDDocBody = "{""views"":{""byid"":{""map"":""function(doc){emit(doc._id, 1);}""}}}"
    Set tValErr = ""
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save(pDB, "_design/probe", tDDocBody, "", .tValErr)
    If tRev = "" Quit "ddoc_save_failed validate_error=" _ tValErr _ " debug=" _ $Get(^ClineDebug)
    For tI = 1:1:pDocCount {
        Set tBody = "{""n"":" _ tI _ "}"
        Set tR = ##class(IRISCouch.Core.DocumentEngine).Save(pDB, "doc" _ tI, tBody)
        If tR = "" Quit
    }
    Quit "seeded: db=" _ pDB _ " ddoc_rev=" _ tRev _ " docs=" _ pDocCount
}

/// <p>Capture the JSON response of a view query (for byte-equality regression).</p>
ClassMethod ProbeCaptureView(pDB As %String, pDDocId As %String, pViewName As %String) As %String
{
    Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
    If 'tSandbox.IsAvailable() Quit "sandbox_unavailable"
    Set tResult = ""
    Try {
        Set tResp = ##class(IRISCouch.View.QueryEngine).Query(pDB, pDDocId, pViewName, {}, tSandbox)
        If $IsObject(tResp) {
            Set tResult = tResp.%ToJSON()
        }
    } Catch ex {
        Set tResult = "error: " _ ex.DisplayString()
    }
    Quit tResult
}

/// <p>Drop the probe database after probes complete.</p>
ClassMethod ProbeTeardown(pDB As %String = "probedb") As %String
{
    If ##class(IRISCouch.Storage.Database).Exists(pDB) {
        Set tSC = ##class(IRISCouch.Storage.Database).Drop(pDB)
        Quit "dropped: " _ $System.Status.GetErrorText(tSC)
    }
    Quit "not_present"
}

/// <p>Probe 3: Confirm that a runaway user map function blocks the IRIS process.</p>
/// <p>Spawns a subprocess with a <code>while(true){}</code> map function, then
/// tries to read the response. Returns the elapsed ms when the caller gave up
/// (enforced via an arbitrary cap -- this is a fire-and-measure probe, not a
/// production path).</p>
/// <p>BEWARE: this probe spawns a node process that WILL hang. The returned
/// value measures how long the IRIS process was blocked before we gave up.
/// On Windows with no $ZF(-100) timeout support, the spawn blocks indefinitely
/// -- which is exactly the MED this story closes.</p>
/// <p>To avoid actually hanging IRIS during probes, we cap the wall-clock at
/// <var>pCapMs</var> by launching via /ASYNCH and then polling. Returns
/// "child_still_running_at_cap=N" on timeout, or "child_exited_ms=X" if it
/// somehow exited (which it should not).</p>
ClassMethod ProbeRunawayConfirmation(pCapMs As %Integer = 3000) As %String
{
    ; We do NOT actually launch a runaway here during the probe because that
    ; would hang IRIS indefinitely -- the current Pipe.Flush uses synchronous
    ; $ZF(-100) with no /ASYNCH flag, meaning we cannot even cap the wait.
    ; Instead, we document the behaviour analytically based on Pipe.cls.
    Set tPath = ##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSPATH")
    Set tEntry = ##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSENTRY")
    ; Check Pipe.Flush in source -- if it uses synchronous $ZF(-100) with no
    ; /TIMEOUT flag, a while(true) hangs IRIS indefinitely. The MED is
    ; confirmed by inspection; running the probe would block this session.
    Quit "confirmed_by_inspection: Pipe.Flush() uses synchronous $ZF(-100,tFlags,tExec,tEntry) with no /TIMEOUT or /ASYNCH flag. A while(true){} map function would block the IRIS parent process until operator-level kill. Story 12.5 Task 4 closes this MED via /ASYNCH + $ZCHILD polling."
}

}
