/// <p>Factory for the configured JavaScript runtime backend (Story 12.1).</p>
/// <p>Reads <code>Config.Get("JSRUNTIME")</code> and returns a new
/// <class>IRISCouch.JSRuntime.Sandbox</class> instance of the matching
/// concrete subclass. Callers MUST declare the return value as the abstract
/// type; this keeps Stories 12.2 and 12.4 free to replace the concrete class
/// bodies without touching any caller code.</p>
///
/// <p>Mapping:</p>
/// <ul>
/// <li><code>"None"</code> (default) -> <class>IRISCouch.JSRuntime.None</class></li>
/// <li><code>"Subprocess"</code> -> <class>IRISCouch.JSRuntime.Subprocess</class></li>
/// <li><code>"Python"</code> -> <class>IRISCouch.JSRuntime.Python</class></li>
/// <li>any other value -> <class>IRISCouch.JSRuntime.None</class> (safe fallback;
///     a Warn is logged naming the unrecognised value so operators notice the typo).</li>
/// </ul>
///
/// <p>No micro-caching. Construction of a Sandbox instance is cheap (empty
/// <class>%RegisteredObject</class>) and the None backend's methods throw
/// immediately without touching any resource. If Story 12.2/12.4 benchmarks
/// indicate Factory.GetSandbox() is called in a hot loop, a process-private
/// cache keyed on the JSRUNTIME value can be added then.</p>
Class IRISCouch.JSRuntime.Factory Extends %RegisteredObject
{

/// <p>Resolve and return the active <class>IRISCouch.JSRuntime.Sandbox</class>.</p>
/// <p>Returns a fresh instance each call. Callers must cast the result to
/// the abstract Sandbox type and MUST NOT downcast to a concrete subclass.</p>
/// @return %ObjectHandle A concrete subclass of IRISCouch.JSRuntime.Sandbox
ClassMethod GetSandbox() As IRISCouch.JSRuntime.Sandbox
{
    Set tBackend = ##class(IRISCouch.Config).Get("JSRUNTIME")
    If tBackend = "None" {
        Quit ##class(IRISCouch.JSRuntime.None).%New()
    }
    If tBackend = "Subprocess" {
        Quit ##class(IRISCouch.JSRuntime.Subprocess).%New()
    }
    If tBackend = "Python" {
        Quit ##class(IRISCouch.JSRuntime.Python).%New()
    }
    ; Unrecognised value -- log a warning and fall back to None so a config
    ; typo does not take the server down.
    Set tLogData = {"configured":(tBackend),"resolved":"None"}
    Do ##class(IRISCouch.Util.Log).Warn("jsruntime", "Unrecognised JSRUNTIME value; falling back to None", tLogData)
    Quit ##class(IRISCouch.JSRuntime.None).%New()
}

}
