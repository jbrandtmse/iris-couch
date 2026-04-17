/// <p>Transient probe helper for validating the Story 12.3 ExecuteValidateDocUpdate
/// / ExecuteFilter pipeline end-to-end from an MCP execute_classmethod call.</p>
/// <p>Intentional temporary: delete after Story 12.3 is marked done.</p>
Class IRISCouch.Test.SubprocessValidateProbe Extends %RegisteredObject
{

/// <p>Run an approve-path validate and return the resulting status as a string.</p>
ClassMethod ProbeApprove() As %String
{
    Do ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")
    Do ##class(IRISCouch.Config).Set("JSRUNTIMESUBPROCESSPATH", "C:\Program Files\nodejs\node.exe")
    Set tSandbox = ##class(IRISCouch.JSRuntime.Subprocess).%New()
    Set tFn = "function(newDoc,oldDoc,userCtx,secObj){return;}"
    Set tNew = {"name":"alice"}
    Set tUC = {"name":"u","roles":[]}
    Set tSec = {"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}
    Set tSC = tSandbox.ExecuteValidateDocUpdate(tFn, tNew, $$$NULLOREF, tUC, tSec)
    If $$$ISOK(tSC) Quit "approve_ok"
    Quit "approve_err: " _ $System.Status.GetErrorText(tSC)
}

/// <p>Run a forbidden-path validate.</p>
ClassMethod ProbeForbid() As %String
{
    Do ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")
    Do ##class(IRISCouch.Config).Set("JSRUNTIMESUBPROCESSPATH", "C:\Program Files\nodejs\node.exe")
    Set tSandbox = ##class(IRISCouch.JSRuntime.Subprocess).%New()
    Set tFn = "function(newDoc,oldDoc,userCtx,secObj){throw({forbidden:'nope'});}"
    Set tNew = {"name":"alice"}
    Set tUC = {"name":"u","roles":[]}
    Set tSec = {"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}
    Set tSC = tSandbox.ExecuteValidateDocUpdate(tFn, tNew, $$$NULLOREF, tUC, tSec)
    If $$$ISOK(tSC) Quit "approve_unexpected"
    Quit $System.Status.GetErrorText(tSC)
}

/// <p>Run an unauthorized-path validate.</p>
ClassMethod ProbeUnauth() As %String
{
    Do ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")
    Do ##class(IRISCouch.Config).Set("JSRUNTIMESUBPROCESSPATH", "C:\Program Files\nodejs\node.exe")
    Set tSandbox = ##class(IRISCouch.JSRuntime.Subprocess).%New()
    Set tFn = "function(newDoc,oldDoc,userCtx,secObj){throw({unauthorized:'need login'});}"
    Set tNew = {"name":"alice"}
    Set tUC = {"name":"u","roles":[]}
    Set tSec = {"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}
    Set tSC = tSandbox.ExecuteValidateDocUpdate(tFn, tNew, $$$NULLOREF, tUC, tSec)
    If $$$ISOK(tSC) Quit "approve_unexpected"
    Quit $System.Status.GetErrorText(tSC)
}

/// <p>Run a filter that returns truthy.</p>
ClassMethod ProbeFilterTrue() As %String
{
    Do ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")
    Do ##class(IRISCouch.Config).Set("JSRUNTIMESUBPROCESSPATH", "C:\Program Files\nodejs\node.exe")
    Set tSandbox = ##class(IRISCouch.JSRuntime.Subprocess).%New()
    Set tFn = "function(doc,req){return doc.public===true;}"
    Set tDoc = {"_id":"a","public":true}
    Set tReq = {"method":"GET","path":"/db/_changes","query":{}}
    Set tBool = tSandbox.ExecuteFilter(tFn, tDoc, tReq)
    Quit "filter_true_" _ tBool
}

/// <p>Probe what $System.Status.GetErrorText returns.</p>
ClassMethod ProbeStatusText() As %String
{
    Set tSC = $$$ERROR($$$GeneralError, "forbidden: admins only")
    Quit $System.Status.GetErrorText(tSC)
}

/// <p>Probe the peel logic from DocumentHandler.RenderValidate.</p>
ClassMethod ProbePeel() As %String
{
    Set tSC = $$$ERROR($$$GeneralError, "forbidden: admins only")
    Set tMsg = $System.Status.GetErrorText(tSC)
    Set tColon = $Find(tMsg, ": ")
    Set tResult = "msg=[" _ tMsg _ "] colon=" _ tColon
    If tColon > 0 {
        Set tTail = $Extract(tMsg, tColon, *)
        Set tResult = tResult _ " tail=[" _ tTail _ "]"
        If $Extract(tTail, 1, 11) = "forbidden: " {
            Set tResult = tResult _ " MATCH_FORBIDDEN"
        } Else {
            Set tResult = tResult _ " no-match first11=[" _ $Extract(tTail, 1, 11) _ "]"
        }
    }
    Quit tResult
}

/// <p>Manually invoke all tests in JSRuntimeValidateHttpTest and aggregate.</p>
ClassMethod RunAllValidateHttpTests() As %String
{
    Set tResults = ""
    Set tTests = "TestValidateApprovesWrite,TestValidateRejectsWithForbidden,TestValidateRejectsWithUnauthorized,TestValidateRunsOnSaveDeleted,TestValidateRunsOnSaveWithHistory,TestValidateRunsOnSaveWithAttachments,TestMultipleValidatesFailFast,TestValidateReturns501WhenRuntimeIsNoneAndValidateIsPresent,TestWritesWithoutValidateStillPassUnderNone"
    Set tN = $Length(tTests, ",")
    Set tPass = 0, tFail = 0
    For tI = 1:1:tN {
        Set tMethod = $Piece(tTests, ",", tI)
        Set tInst = ##class(IRISCouch.Test.JSRuntimeValidateHttpTest).%New("")
        Do tInst.OnBeforeOneTest()
        Kill ^UnitTest.Result
        Set ^UnitTest.Result = ""
        Try {
            Do $METHOD(tInst, tMethod)
            Set tResults = tResults _ tI _ ". " _ tMethod _ " : OK" _ $Char(10)
            Set tPass = tPass + 1
        } Catch ex {
            Set tResults = tResults _ tI _ ". " _ tMethod _ " : FAIL (" _ ex.DisplayString() _ ")" _ $Char(10)
            Set tFail = tFail + 1
        }
        Do tInst.OnAfterOneTest()
    }
    Quit $Char(10) _ tResults _ "Pass: " _ tPass _ ", Fail: " _ tFail
}

/// <p>Manually invoke all tests in JSRuntimeFilterHttpTest.</p>
ClassMethod RunAllFilterHttpTests() As %String
{
    Set tResults = ""
    Set tTests = "TestCustomFilterIncludesMatches,TestCustomFilterExcludesAll,TestCustomFilterMissingDocReturns404,TestBuiltinFiltersRegressGreen"
    Set tN = $Length(tTests, ",")
    Set tPass = 0, tFail = 0
    For tI = 1:1:tN {
        Set tMethod = $Piece(tTests, ",", tI)
        Set tInst = ##class(IRISCouch.Test.JSRuntimeFilterHttpTest).%New("")
        Do tInst.OnBeforeOneTest()
        Try {
            Do $METHOD(tInst, tMethod)
            Set tResults = tResults _ tI _ ". " _ tMethod _ " : OK" _ $Char(10)
            Set tPass = tPass + 1
        } Catch ex {
            Set tResults = tResults _ tI _ ". " _ tMethod _ " : FAIL (" _ ex.DisplayString() _ ")" _ $Char(10)
            Set tFail = tFail + 1
        }
        Do tInst.OnAfterOneTest()
    }
    Quit $Char(10) _ tResults _ "Pass: " _ tPass _ ", Fail: " _ tFail
}

/// <p>Inspect the last ^UnitTest.Result entry and summarise pass/fail.</p>
ClassMethod LastUnitTestSummary() As %String
{
    Set tIdx = $Order(^UnitTest.Result(""), -1)
    If tIdx = "" Quit "no results"
    Set tOut = "idx=" _ tIdx _ $Char(10)
    Set tPass = 0, tFail = 0, tTotal = 0
    Set tK1 = ""
    For {
        Set tK1 = $Order(^UnitTest.Result(tIdx, tK1))
        Quit:tK1=""
        Set tK2 = ""
        For {
            Set tK2 = $Order(^UnitTest.Result(tIdx, tK1, tK2))
            Quit:tK2=""
            Set tCls = ""
            For {
                Set tCls = $Order(^UnitTest.Result(tIdx, tK1, tK2, tCls))
                Quit:tCls=""
                Set tOut = tOut _ $Char(10) _ "[" _ tCls _ "]"
                Set tM = ""
                For {
                    Set tM = $Order(^UnitTest.Result(tIdx, tK1, tK2, tCls, tM))
                    Quit:tM=""
                    Set tTotal = tTotal + 1
                    ; Test-level pass/fail lives under ...(idx,k1,k2,cls,m,"status")
                    Set tStatus = $Get(^UnitTest.Result(tIdx, tK1, tK2, tCls, tM, "status"), -1)
                    ; Fallback: walk the assertion nodes and compute
                    If tStatus = -1 {
                        Set tStatus = 1
                        Set tA = ""
                        For {
                            Set tA = $Order(^UnitTest.Result(tIdx, tK1, tK2, tCls, tM, tA))
                            Quit:tA=""
                            If tA = "status" Continue
                            If tA = "timing" Continue
                            Set tAssertData = $Get(^UnitTest.Result(tIdx, tK1, tK2, tCls, tM, tA))
                            ; $ListBuild node; $List(tAssertData,1) = pass flag
                            Set tPassFlag = $ListGet(tAssertData, 1, 1)
                            If 'tPassFlag Set tStatus = 0
                        }
                    }
                    Set tLabel = $Select(tStatus=1: "PASS", 1: "FAIL")
                    If tStatus = 1 { Set tPass = tPass + 1 } Else { Set tFail = tFail + 1 }
                    Set tOut = tOut _ $Char(10) _ " " _ tLabel _ " " _ tM
                }
            }
        }
    }
    Set tOut = tOut _ $Char(10) _ $Char(10) _ "TOTAL=" _ tTotal _ " PASS=" _ tPass _ " FAIL=" _ tFail
    Quit tOut
}

/// <p>Run a filter that returns falsy.</p>
ClassMethod ProbeFilterFalse() As %String
{
    Do ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")
    Do ##class(IRISCouch.Config).Set("JSRUNTIMESUBPROCESSPATH", "C:\Program Files\nodejs\node.exe")
    Set tSandbox = ##class(IRISCouch.JSRuntime.Subprocess).%New()
    Set tFn = "function(doc,req){return doc.public===true;}"
    Set tDoc = {"_id":"b","public":false}
    Set tReq = {"method":"GET","path":"/db/_changes","query":{}}
    Set tBool = tSandbox.ExecuteFilter(tFn, tDoc, tReq)
    Quit "filter_false_" _ tBool
}

}
