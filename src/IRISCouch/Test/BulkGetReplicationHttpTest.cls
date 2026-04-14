/// <p>HTTP integration tests for IRISCouch replication-ready <code>_bulk_get</code> enhancements.</p>
/// <p>Tests full request/response cycle via live HTTP requests against the running webapp.
/// Validates <code>revs=true</code>, <code>attachments=true</code>, combined flags,
/// missing doc error entries, and stub-only defaults. Covers AC #1-#3, #5-#6 for Story 8.3.</p>
Class IRISCouch.Test.BulkGetReplicationHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create a test database before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.DB("bgrephttp")
    Kill ^IRISCouch.Docs("bgrephttp")
    Kill ^IRISCouch.Tree("bgrephttp")
    Kill ^IRISCouch.Changes("bgrephttp")
    Kill ^IRISCouch.Seq("bgrephttp")
    Kill ^IRISCouch.Atts("bgrephttp")
    Kill ^IRISCouch.Local("bgrephttp")
    Kill ^IRISCouch.Proj("bgrephttp")
    Kill ^IRISCouch.MangoIdx("bgrephttp")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("bgrephttp")
    Quit tSC
}

/// <p>Clean up test database after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("bgrephttp")
    Kill ^IRISCouch.Docs("bgrephttp")
    Kill ^IRISCouch.Tree("bgrephttp")
    Kill ^IRISCouch.Changes("bgrephttp")
    Kill ^IRISCouch.Seq("bgrephttp")
    Kill ^IRISCouch.Atts("bgrephttp")
    Kill ^IRISCouch.Local("bgrephttp")
    Kill ^IRISCouch.Proj("bgrephttp")
    Kill ^IRISCouch.MangoIdx("bgrephttp")
    Quit $$$OK
}

/// <p>AC #1: POST _bulk_get with revs=true returns _revisions in each doc.</p>
Method TestBulkGetHttpRevsTrue()
{
    ; Create a document then update it to have 2 revisions
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/bgrephttp/rvdoc1", .tStatus, .tBody, "{""v"":1}")
    Do $$$AssertEquals(tStatus, 201, "Create doc rvdoc1")
    Set tRev1 = tBody.rev
    Set tUpdateBody = "{""_rev"":""" _ tRev1 _ """,""v"":2}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/bgrephttp/rvdoc1", .tStatus, .tBody, tUpdateBody)
    Do $$$AssertEquals(tStatus, 201, "Update doc rvdoc1")
    Set tRev2 = tBody.rev
    ; POST _bulk_get with revs=true
    Set tReqBody = "{""docs"":[{""id"":""rvdoc1""}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/bgrephttp/_bulk_get?revs=true", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _bulk_get?revs=true completed")
    Do $$$AssertEquals(tStatus, 200, "Returns HTTP 200")
    Set tResults = tBody.results
    Do $$$AssertEquals(tResults.%Size(), 1, "Results has 1 entry")
    Set tOkDoc = tResults.%Get(0).docs.%Get(0).ok
    Do $$$AssertEquals(tOkDoc."_id", "rvdoc1", "Doc has correct _id")
    Do $$$AssertEquals(tOkDoc."_rev", tRev2, "Doc has latest _rev")
    ; Check _revisions
    Set tRevisions = tOkDoc."_revisions"
    Do $$$AssertTrue($IsObject(tRevisions), "_revisions is present")
    Do $$$AssertEquals(tRevisions.start, 2, "_revisions.start is 2")
    Do $$$AssertEquals(tRevisions.ids.%Size(), 2, "_revisions.ids has 2 entries")
}

/// <p>AC #2: POST _bulk_get with attachments=true returns inline base64 data.</p>
Method TestBulkGetHttpAttachmentsTrue()
{
    ; Create doc
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/bgrephttp/attdoc1", .tStatus, .tBody, "{""name"":""att-test""}")
    Do $$$AssertEquals(tStatus, 201, "Create doc attdoc1")
    Set tRev1 = tBody.rev
    ; Upload an attachment via standalone PUT
    Set tAttContent = "Hello from attachment!"
    Set tBinStream = ##class(%Stream.GlobalBinary).%New()
    Do tBinStream.Write(tAttContent)
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/bgrephttp/attdoc1/readme.txt?rev=" _ tRev1, .tStatus, .tBody, "", "text/plain", tBinStream)
    Do $$$AssertEquals(tStatus, 201, "Upload attachment readme.txt")
    Set tRev2 = tBody.rev
    ; POST _bulk_get with attachments=true
    Set tReqBody = "{""docs"":[{""id"":""attdoc1""}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/bgrephttp/_bulk_get?attachments=true", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _bulk_get?attachments=true completed")
    Do $$$AssertEquals(tStatus, 200, "Returns HTTP 200")
    Set tResults = tBody.results
    Do $$$AssertEquals(tResults.%Size(), 1, "Results has 1 entry")
    Set tOkDoc = tResults.%Get(0).docs.%Get(0).ok
    Do $$$AssertEquals(tOkDoc."_id", "attdoc1", "Doc has correct _id")
    ; Check _attachments with inline data
    Set tAtts = tOkDoc."_attachments"
    Do $$$AssertTrue($IsObject(tAtts), "_attachments is present")
    Set tAtt = tAtts.%Get("readme.txt")
    Do $$$AssertTrue($IsObject(tAtt), "readme.txt attachment exists")
    Do $$$AssertEquals(tAtt.%Get("content_type"), "text/plain", "content_type is text/plain")
    Do $$$AssertTrue(+tAtt.%Get("length") > 0, "length is positive")
    Do $$$AssertTrue(tAtt.%Get("digest") '= "", "digest is present")
    Do $$$AssertTrue($Extract(tAtt.%Get("digest"), 1, 4) = "md5-", "digest in md5-base64 format")
    ; Verify data field (base64 inline) is present
    Set tData = tAtt.%Get("data")
    Do $$$AssertTrue(tData '= "", "data field is present (base64)")
    ; Verify NO stub field
    Do $$$AssertTrue('tAtt.%IsDefined("stub"), "No stub field when data is inline")
    ; Verify base64 decodes to original content
    Set tDecoded = $System.Encryption.Base64Decode(tData)
    Do $$$AssertEquals(tDecoded, tAttContent, "Decoded base64 matches original attachment content")
}

/// <p>AC #3: POST _bulk_get with non-existent doc returns error entry.</p>
Method TestBulkGetHttpMissingDoc()
{
    Set tReqBody = "{""docs"":[{""id"":""ghost-doc-999""}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/bgrephttp/_bulk_get", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _bulk_get completed")
    Do $$$AssertEquals(tStatus, 200, "Returns HTTP 200 even for missing docs")
    Set tResults = tBody.results
    Do $$$AssertEquals(tResults.%Size(), 1, "Results has 1 entry")
    Set tR1 = tResults.%Get(0)
    Do $$$AssertEquals(tR1.id, "ghost-doc-999", "Result id matches request")
    ; Check error entry format
    Set tErrDoc = tR1.docs.%Get(0).error
    Do $$$AssertTrue($IsObject(tErrDoc), "Error entry is an object")
    Do $$$AssertEquals(tErrDoc.id, "ghost-doc-999", "Error id matches")
    Do $$$AssertEquals(tErrDoc.error, "not_found", "Error is not_found")
    Do $$$AssertEquals(tErrDoc.reason, "missing", "Reason is missing")
}

/// <p>AC #5: POST _bulk_get without attachments flag returns stubs (stub:true).</p>
Method TestBulkGetHttpStubs()
{
    ; Create doc and upload attachment
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/bgrephttp/stubdoc1", .tStatus, .tBody, "{""name"":""stub-test""}")
    Do $$$AssertEquals(tStatus, 201, "Create doc stubdoc1")
    Set tRev1 = tBody.rev
    Set tBinStream = ##class(%Stream.GlobalBinary).%New()
    Do tBinStream.Write("stub content data")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/bgrephttp/stubdoc1/file.dat?rev=" _ tRev1, .tStatus, .tBody, "", "application/octet-stream", tBinStream)
    Do $$$AssertEquals(tStatus, 201, "Upload attachment file.dat")
    ; POST _bulk_get WITHOUT attachments flag
    Set tReqBody = "{""docs"":[{""id"":""stubdoc1""}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/bgrephttp/_bulk_get", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _bulk_get completed")
    Do $$$AssertEquals(tStatus, 200, "Returns HTTP 200")
    Set tResults = tBody.results
    Set tOkDoc = tResults.%Get(0).docs.%Get(0).ok
    Do $$$AssertEquals(tOkDoc."_id", "stubdoc1", "Doc has correct _id")
    ; Check _attachments with stubs
    Set tAtts = tOkDoc."_attachments"
    Do $$$AssertTrue($IsObject(tAtts), "_attachments is present")
    Set tAtt = tAtts.%Get("file.dat")
    Do $$$AssertTrue($IsObject(tAtt), "file.dat attachment exists")
    Do $$$AssertEquals(tAtt.%Get("content_type"), "application/octet-stream", "content_type correct")
    Do $$$AssertTrue(tAtt.%Get("stub") = 1, "stub is true")
    Do $$$AssertTrue('tAtt.%IsDefined("data"), "No data field in stub mode")
    Do $$$AssertTrue(+tAtt.%Get("length") > 0, "length is positive")
    Do $$$AssertTrue(tAtt.%Get("digest") '= "", "digest is present")
}

/// <p>AC #6: POST _bulk_get with both revs=true and attachments=true returns both.</p>
Method TestBulkGetHttpBothFlags()
{
    ; Create doc, update, and add attachment
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/bgrephttp/bothdoc1", .tStatus, .tBody, "{""v"":1}")
    Do $$$AssertEquals(tStatus, 201, "Create doc bothdoc1")
    Set tRev1 = tBody.rev
    Set tUpdateBody = "{""_rev"":""" _ tRev1 _ """,""v"":2}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/bgrephttp/bothdoc1", .tStatus, .tBody, tUpdateBody)
    Do $$$AssertEquals(tStatus, 201, "Update doc bothdoc1")
    Set tRev2 = tBody.rev
    ; Upload attachment on latest rev
    Set tBinStream = ##class(%Stream.GlobalBinary).%New()
    Do tBinStream.Write("combined test data")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/bgrephttp/bothdoc1/combo.txt?rev=" _ tRev2, .tStatus, .tBody, "", "text/plain", tBinStream)
    Do $$$AssertEquals(tStatus, 201, "Upload attachment combo.txt")
    Set tRev3 = tBody.rev
    ; POST _bulk_get with both flags
    Set tReqBody = "{""docs"":[{""id"":""bothdoc1""}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/bgrephttp/_bulk_get?revs=true&attachments=true", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST _bulk_get?revs=true&attachments=true completed")
    Do $$$AssertEquals(tStatus, 200, "Returns HTTP 200")
    Set tResults = tBody.results
    Set tOkDoc = tResults.%Get(0).docs.%Get(0).ok
    Do $$$AssertEquals(tOkDoc."_id", "bothdoc1", "Doc has correct _id")
    ; Verify _revisions present
    Set tRevisions = tOkDoc."_revisions"
    Do $$$AssertTrue($IsObject(tRevisions), "_revisions is present")
    Do $$$AssertEquals(tRevisions.start, 3, "_revisions.start is 3 (3 revisions)")
    Do $$$AssertTrue(tRevisions.ids.%Size() >= 2, "_revisions.ids has multiple entries")
    ; Verify _attachments with inline data
    Set tAtts = tOkDoc."_attachments"
    Do $$$AssertTrue($IsObject(tAtts), "_attachments is present")
    Set tAtt = tAtts.%Get("combo.txt")
    Do $$$AssertTrue($IsObject(tAtt), "combo.txt attachment exists")
    Do $$$AssertTrue(tAtt.%Get("data") '= "", "data field is present (inline)")
    Do $$$AssertTrue('tAtt.%IsDefined("stub"), "No stub field when data is inline")
    Do $$$AssertEquals(tAtt.%Get("content_type"), "text/plain", "content_type correct")
}

}
