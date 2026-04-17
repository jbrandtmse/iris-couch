/// <p>Placeholder stub for the Python-embedded JavaScript runtime backend.</p>
/// <p>Exists so <class>IRISCouch.JSRuntime.Factory</class> can resolve the
/// <code>"Python"</code> config value without crashing while Story 12.4 is
/// pending. Every <code>Execute*</code> method throws a
/// <code>not_yet_implemented</code> exception carrying a pointer to Story 12.4.</p>
Class IRISCouch.JSRuntime.Python Extends IRISCouch.JSRuntime.Sandbox
{

/// <p>Always returns 0 -- the Python backend is not yet implemented (Story 12.4).</p>
Method IsAvailable() As %Boolean
{
    Quit 0
}

/// <p>Throws <code>not_yet_implemented</code> until Story 12.4 lands.</p>
Method ExecuteMap(pMapFn As %String, pDoc As %DynamicObject) As %DynamicArray
{
    Do ..ThrowNotYetImplemented("view execution")
    Quit $$$NULLOREF
}

/// <p>Throws <code>not_yet_implemented</code> until Story 12.4 lands.</p>
Method ExecuteReduce(pReduceFn As %String, pKeys As %DynamicArray, pValues As %DynamicArray, pRereduce As %Boolean) As %DynamicObject
{
    Do ..ThrowNotYetImplemented("reduce function")
    Quit $$$NULLOREF
}

/// <p>Throws <code>not_yet_implemented</code> until Story 12.4 lands.</p>
Method ExecuteValidateDocUpdate(pValidateFn As %String, pNewDoc As %DynamicObject, pOldDoc As %DynamicObject, pUserCtx As %DynamicObject, pSecObj As %DynamicObject) As %Status
{
    Do ..ThrowNotYetImplemented("validate_doc_update hooks")
    Quit $$$OK
}

/// <p>Throws <code>not_yet_implemented</code> until Story 12.4 lands.</p>
Method ExecuteFilter(pFilterFn As %String, pDoc As %DynamicObject, pReq As %DynamicObject) As %Boolean
{
    Do ..ThrowNotYetImplemented("custom filter functions")
    Quit 0
}

/// <p>Throw a <class>%Exception.General</class> with the "not yet implemented" envelope.</p>
/// @param pSubsystem Subsystem label (<code>view execution</code>, etc.)
ClassMethod ThrowNotYetImplemented(pSubsystem As %String) [ Internal ]
{
    Set tReason = "Python JSRuntime backend is not yet implemented (Story 12.4). " _ pSubsystem _ " is unavailable until the embedded-Python runtime ships. Set JSRUNTIME to None to disable. See documentation/js-runtime.md."
    ; %Exception.General.%New signature: (pName, pCode, pLocation, pData, ...)
    Throw ##class(%Exception.General).%New(pSubsystem, "not_implemented", "", tReason)
}

}
