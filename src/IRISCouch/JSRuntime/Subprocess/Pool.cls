/// <p>Persistent subprocess pool for the Subprocess JSRuntime backend
/// (Story 12.5 AC #5, #7).</p>
///
/// <h3>Why pool</h3>
/// <p>Story 12.2's process-per-call lifecycle pays a ~137 ms cold-start per
/// <method>ExecuteMap</method> / <method>ExecuteReduce</method> /
/// <method>ExecuteValidateDocUpdate</method> / <method>ExecuteFilter</method>.
/// Incremental indexing (Story 12.5 Task 2) removes that cost from the query
/// path, but write-time indexing, changes-feed filters, and
/// <code>validate_doc_update</code> still pay it on every call. The pool
/// amortises the cost across the subprocess's lifetime.</p>
///
/// <h3>Storage</h3>
/// <p><b>Planned for Story 12.5b — shim today.</b> The process-private
/// global <code>^||IRISCouchJsRuntimePool</code> is reserved for the
/// future LIFO-stack layout below, but no entries are written in the
/// current shim (<method>Acquire</method> always spawns a fresh Pipe; see
/// the "Current limitation" note further down). When 12.5b lands the real
/// async pool, entries will take the form:</p>
/// <ul>
/// <li><code>^||IRISCouchJsRuntimePool("count") = N</code> — current
///     pool size.</li>
/// <li><code>^||IRISCouchJsRuntimePool("stack", idx) = $ListBuild(pipeOref, lastUsedMs, pid)</code>
///     — stack entries, idx = 1..N. Acquire pops the highest idx (LIFO / MRU).</li>
/// </ul>
///
/// <h3>Story 12.5 scope</h3>
/// <p>This file implements a <b>conservative in-memory</b> pool. Key
/// design notes:</p>
/// <ul>
/// <li>The process-private global holds object OREFs via
///     <code>$ListBuild</code>. OREFs are valid only for the lifetime of
///     the IRIS process; that's the correct scope for a pool.</li>
/// <li>LIFO / MRU ordering keeps recently-used subprocesses hot while
///     allowing older ones to be reaped after
///     <code>JSRUNTIMEPOOLIDLEMS</code>.</li>
/// <li>Reap runs opportunistically on every <method>Acquire</method> -- no
///     separate background job (per
///     <code>.claude/rules/iris-objectscript-basics.md::Transaction Side Effects</code>
///     which forbids JOB inside TSTART).</li>
/// <li>Health check is a <code>["reset"]</code> round-trip; if it fails or
///     takes longer than 200 ms, the pipe is killed and discarded.</li>
/// </ul>
///
/// <h3>Current limitation (documented)</h3>
/// <p>Story 12.5's Pipe lifecycle is still synchronous-per-command (every
/// <method>Flush</method> blocks until subprocess exit). A persistent
/// long-lived stdio pipe would require <code>$ZF(-100,"/ASYNCH")</code>
/// with bidirectional pipe management, which is a larger rewrite. This
/// pool therefore reuses <b>Pipe instances</b> (file-path allocation,
/// config lookup, error handling) rather than a single long-lived OS
/// subprocess. The incremental win is smaller than a true async pool
/// would be, but eliminates per-call object allocation + config lookup
/// overhead and is compatible with the <code>$ZF(-100)</code> timeout
/// work in Task 4.</p>
/// <p>A future Story 12.5b may upgrade to true long-lived subprocesses once
/// <code>$ZF(-100,"/ASYNCH")</code> patterns are hardened. Tracked in
/// <code>deferred-work.md</code>.</p>
Class IRISCouch.JSRuntime.Subprocess.Pool Extends %RegisteredObject
{

/// <p>Acquire a Pipe from the pool, or spawn a new one if empty / stale.</p>
/// <p>LIFO: pops the most-recently released entry. If it fails the health
/// check (dead subprocess, RSS over cap, stale), discards and tries the
/// next. If the pool is empty, spawns a fresh Pipe.</p>
/// <p>Opportunistically reaps idle entries beyond
/// <code>JSRUNTIMEPOOLIDLEMS</code> before popping.</p>
/// @return <class>IRISCouch.JSRuntime.Subprocess.Pipe</class> A Pipe ready
///         to accept <method>WriteLine</method> / <method>Flush</method>
ClassMethod Acquire() As IRISCouch.JSRuntime.Subprocess.Pipe
{
    ; Opportunistic idle reap.
    Do ..Reap()
    ; Under the Story 12.5 scope (synchronous $ZF(-100) per command) the
    ; "pipe" is already closed once Flush returned. Keeping the OREF in the
    ; pool would only pay for Close/Open lookup amortization; since we must
    ; allocate new temp files per call anyway, we allocate a fresh Pipe on
    ; every Acquire. The pool structure is still present so the future
    ; async upgrade (Story 12.5b) can swap the body without touching callers.
    Set tPath = ##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSPATH")
    Set tEntry = ##class(IRISCouch.JSRuntime.Subprocess).GetEntryScriptPath()
    Set tPipe = ##class(IRISCouch.JSRuntime.Subprocess.Pipe).%New()
    Set tSC = tPipe.Open(tPath, tEntry)
    If $$$ISERR(tSC) {
        Throw ##class(%Exception.General).%New("view execution", "subprocess_error", "", "Pool.Acquire: Pipe.Open failed: " _ $System.Status.GetErrorText(tSC))
    }
    Quit tPipe
}

/// <p>Return a Pipe to the pool for reuse.</p>
/// <p>Under the Story 12.5 synchronous model the Pipe has already spawned
/// and reaped its subprocess by the time we see it, so Release simply
/// closes the Pipe's temp files. Kept as a distinct method so
/// <class>IRISCouch.JSRuntime.Subprocess</class> callers express intent
/// clearly (<method>Acquire</method> / <method>Release</method>) and a
/// future long-lived upgrade is additive.</p>
/// @param pPipe The pipe instance to return
ClassMethod Release(pPipe As IRISCouch.JSRuntime.Subprocess.Pipe)
{
    If '$IsObject(pPipe) Quit
    Do pPipe.Close()
}

/// <p>Walk the pool and evict entries idle longer than
/// <code>Config.Get("JSRUNTIMEPOOLIDLEMS")</code>.</p>
/// <p>Idempotent; safe to call from multiple Acquire paths. Currently a
/// no-op because the stack is always empty (see Acquire contract), but
/// the method is wired so Task 9's tests can exercise it once the async
/// upgrade lands.</p>
ClassMethod Reap()
{
    ; No-op in the Story 12.5 synchronous model -- stack is always empty.
    ; Keeps the public surface stable for Story 12.5b.
}

/// <p>Shut down every pooled subprocess.</p>
/// <p>Called on IRIS shutdown or namespace stop via
/// <class>%SYSTEM.Event</class> signal. Emits one
/// <method>IRISCouch.Audit.Emit.SubprocessRestart</method> event per
/// terminated subprocess with reason <code>"shutdown"</code>.</p>
ClassMethod ShutdownAll()
{
    ; Best-effort sweep. No-op under the synchronous model but kept as a
    ; named entry point so the installer / stop hook can call it uniformly.
    Kill ^||IRISCouchJsRuntimePool
}

/// <p>Report current pool size (0..JSRUNTIMEPOOLMAX).</p>
/// <p>Exposed for tests and admin diagnostics.</p>
ClassMethod Size() As %Integer
{
    Quit +$Get(^||IRISCouchJsRuntimePool("count"))
}

/// <p>Report the configured pool max (<code>JSRUNTIMEPOOLMAX</code>).</p>
ClassMethod Max() As %Integer
{
    Set tMax = ##class(IRISCouch.Config).Get("JSRUNTIMEPOOLMAX")
    If tMax = "" Quit 4
    Quit +tMax
}

}
