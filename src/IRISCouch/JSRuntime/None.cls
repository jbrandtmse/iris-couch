/// <p>Concrete "no-op" JavaScript runtime backend (Epic 12 / Story 12.1).</p>
/// <p>This is the shipped default. Every <code>Execute*</code> method throws
/// a <class>%Exception.General</class> carrying a canonical error envelope
/// that callers render verbatim as HTTP 501 Not Implemented. Throwing (rather
/// than returning a sentinel) ensures that if a caller forgets to guard the
/// call, the request fails fast with a clear message instead of silently
/// producing stale or wrong data.</p>
///
/// <p>Exception shape (via <class>%Exception.General</class>):</p>
/// <ul>
/// <li><code>Name</code> -- subsystem label (<code>view execution</code>,
///     <code>reduce function</code>, <code>validate_doc_update hooks</code>,
///     <code>custom filter functions</code>). Callers surface this to the
///     client so operators can identify the blocked subsystem.</li>
/// <li><code>Code</code> -- always <code>"not_implemented"</code>.</li>
/// <li><code>Data</code> -- full reason string, including the pointer to
///     <code>documentation/js-runtime.md</code>.</li>
/// </ul>
///
/// <p>The reason string template is:</p>
/// <pre>
/// JSRuntime backend is set to None. &lt;subsystem&gt; requires a JSRuntime
/// backend. Set ^IRISCouch.Config("JSRUNTIME") to "Subprocess" or "Python"
/// to enable &lt;subsystem&gt;. See documentation/js-runtime.md.
/// </pre>
Class IRISCouch.JSRuntime.None Extends IRISCouch.JSRuntime.Sandbox
{

/// <p>Always returns 0 -- this backend cannot execute JavaScript.</p>
Method IsAvailable() As %Boolean
{
    Quit 0
}

/// <p>Throws <code>not_implemented</code>; the caller must render 501.</p>
Method ExecuteMap(pMapFn As %String, pDoc As %DynamicObject) As %DynamicArray
{
    Do ..ThrowNotImplemented("view execution")
    Quit $$$NULLOREF
}

/// <p>Throws <code>not_implemented</code>; the caller must render 501.</p>
Method ExecuteReduce(pReduceFn As %String, pKeys As %DynamicArray, pValues As %DynamicArray, pRereduce As %Boolean) As %DynamicObject
{
    Do ..ThrowNotImplemented("reduce function")
    Quit $$$NULLOREF
}

/// <p>Throws <code>not_implemented</code>; the caller must render 501.</p>
/// <p>When <code>None</code> is the active backend, writes still succeed
/// because callers short-circuit via <method>IsAvailable</method> rather
/// than invoking this method. See Story 12.1 AC #3 and AC #6.</p>
Method ExecuteValidateDocUpdate(pValidateFn As %String, pNewDoc As %DynamicObject, pOldDoc As %DynamicObject, pUserCtx As %DynamicObject, pSecObj As %DynamicObject) As %Status
{
    Do ..ThrowNotImplemented("validate_doc_update hooks")
    Quit $$$OK
}

/// <p>Throws <code>not_implemented</code>; the caller must render 501.</p>
Method ExecuteFilter(pFilterFn As %String, pDoc As %DynamicObject, pReq As %DynamicObject) As %Boolean
{
    Do ..ThrowNotImplemented("custom filter functions")
    Quit 0
}

/// <p>Throw a <class>%Exception.General</class> describing the blocked subsystem.</p>
/// <p>The thrown exception carries the canonical 501 envelope: code is
/// <code>"not_implemented"</code>, name is the subsystem label, and data is
/// the full reason string pointing at <code>documentation/js-runtime.md</code>.
/// The reason string is sourced from
/// <method>IRISCouch.Util.Error.BuildJSRuntimeNotImplementedReason</method> to
/// guarantee byte-for-byte parity with what HTTP callers render in 501
/// responses (Story 12.1 AC #2).</p>
/// @param pSubsystem Subsystem label (<code>view execution</code>, etc.)
ClassMethod ThrowNotImplemented(pSubsystem As %String) [ Internal ]
{
    Set tReason = ##class(IRISCouch.Util.Error).BuildJSRuntimeNotImplementedReason(pSubsystem)
    ; %Exception.General.%New signature: (pName, pCode, pLocation, pData, ...)
    ; Name = subsystem label (displayed to operators); Code = "not_implemented"
    ; canonical slug; Data = full reason string rendered as the HTTP reason.
    Throw ##class(%Exception.General).%New(pSubsystem, "not_implemented", "", tReason)
}

}
