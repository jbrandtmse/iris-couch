/// <p>Minimal probe substitute for %UnitTest.Manager that counts
/// assertion failures. Used by
/// <class>IRISCouch.Test.SubprocessTestRunner</class> to run tests inline
/// and report results programmatically. Delete after Story 12.2 review.</p>
Class IRISCouch.Test.SubprocessTestRunner.ProbeManager Extends %RegisteredObject
{

Property FailCount As %Integer [ InitialExpression = 0 ];

Property LastFailure As %String;

Property Debug As %Boolean [ InitialExpression = 0 ];

Property OriginNS As %String;

Property CurrentDir As %String;

Property Display;

/// Stub implementations of the Manager methods TestCase calls.
Method LogAssert(pSuccess As %Boolean, pMacro As %String = "", pDescription As %String = "", pValue As %String = "", pLocation As %String = "")
{
    If 'pSuccess {
        Set ..FailCount = ..FailCount + 1
        Set ..LastFailure = pMacro _ ": " _ pDescription
    }
}

Method LogMessage(pMessage As %String = "")
{
    ; no-op
}

Method LogStateStatus(pStatus As %Integer, pStep As %String = "", pMessage As %String = "")
{
    ; no-op
}

}
