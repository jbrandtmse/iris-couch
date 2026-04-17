/// <p>Temp helper that runs all tests from IRISCouch.Test.JSRuntimeSubprocessHttpTest
/// inline and returns structured results. Works around the iris_execute_tests
/// MCP discovery issue noted in deferred-work.md (Story 12.1).</p>
/// <p>Delete after Story 12.2 review.</p>
Class IRISCouch.Test.SubprocessTestRunner Extends %RegisteredObject
{

ClassMethod RunAll() As %String
{
    Set tMethods = $LB("TestSubprocessMapSimpleView","TestSubprocessMapEmptyView","TestSubprocessMapWithBuiltinSum","TestSubprocessBuiltinStats","TestSubprocessMapWithCustomReduce","TestSubprocessMapErrorSkipsDoc","TestSubprocessFallsBackTo501WhenPathMissing","TestSubprocessKeeps404ForMissingDesignDoc","TestSubprocessMultipleQueriesDoNotShareState","TestSubprocessMapWithLogCall","TestSubprocessReduceTrueOnMapOnlyReturns400","TestSubprocessContentTypeIsJson")
    Quit ..RunTestClass("IRISCouch.Test.JSRuntimeSubprocessHttpTest", tMethods)
}

ClassMethod RunAllBuiltinReduce() As %String
{
    Set tMethods = $LB("TestIsBuiltinRecognisesAllTokens","TestSumNumericValues","TestSumEmptyIsZero","TestSumMixedSkipsNonNumeric","TestSumSingleValue","TestCountReturnsSize","TestStatsShapeAndValues","TestStatsEmpty","TestStatsSingleValue","TestApproxCountDistinctBasic","TestApproxCountDistinctDistinguishesTypes","TestApplyDispatches")
    Quit ..RunTestClass("IRISCouch.Test.BuiltinReduceTest", tMethods)
}

ClassMethod RunTestClass(pClass As %String, pMethods As %List) As %String
{
    Set tTotal = 0
    Set tPassed = 0
    Set tFailed = 0
    Set tMessages = ""
    For tI = 1:1:$ListLength(pMethods) {
        Set tMethod = $ListGet(pMethods, tI)
        Set tTotal = tTotal + 1
        Set tStatus = ..RunOne(pClass, tMethod, .tErr)
        If tStatus {
            Set tPassed = tPassed + 1
            Set tMessages = tMessages _ "PASS " _ tMethod _ $Char(10)
        } Else {
            Set tFailed = tFailed + 1
            Set tMessages = tMessages _ "FAIL " _ tMethod _ " - " _ tErr _ $Char(10)
        }
    }
    Quit pClass _ ": TOTAL=" _ tTotal _ " PASSED=" _ tPassed _ " FAILED=" _ tFailed _ $Char(10) _ tMessages
}

ClassMethod RunOne(pClass As %String, pMethod As %String, Output pErr As %String) As %Boolean
{
    Set pErr = ""
    Set tOK = 1
    Try {
        ; Use a probe-manager that counts LogAssert calls with success=0.
        Set tManager = ##class(IRISCouch.Test.SubprocessTestRunner.ProbeManager).%New()
        Set tCase = $CLASSMETHOD(pClass, "%New", tManager)
        If $IsObject(tCase) && $METHOD(tCase, "OnBeforeOneTest") {
            Set tSC = tCase.OnBeforeOneTest()
            If $$$ISERR(tSC) {
                Set pErr = "OnBefore: " _ $System.Status.GetErrorText(tSC)
                Set tOK = 0
                Do tCase.OnAfterOneTest()
                Quit
            }
        }
        Do $METHOD(tCase, pMethod)
        If tManager.FailCount > 0 {
            Set pErr = tManager.LastFailure
            Set tOK = 0
        }
        If $IsObject(tCase) && $METHOD(tCase, "OnAfterOneTest") {
            Do tCase.OnAfterOneTest()
        }
    }
    Catch ex {
        Set pErr = ex.DisplayString()
        Set tOK = 0
    }
    Quit tOK
}

}
