# replicate-from-couchdb (PowerShell edition). See run.sh for commentary.

$ErrorActionPreference = 'Stop'

$IrisCouchUrl = if ($env:IRISCOUCH_URL) { $env:IRISCOUCH_URL } else { 'http://localhost:52773/iris-couch' }
$IrisUser = if ($env:IRISCOUCH_USER) { $env:IRISCOUCH_USER } else { '_system' }
$IrisPass = if ($env:IRISCOUCH_PASS) { $env:IRISCOUCH_PASS } else { 'SYS' }

$CouchdbUrl = if ($env:COUCHDB_URL) { $env:COUCHDB_URL } else { 'http://localhost:5984' }
$CouchUser = if ($env:COUCHDB_USER) { $env:COUCHDB_USER } else { 'admin' }
$CouchPass = if ($env:COUCHDB_PASS) { $env:COUCHDB_PASS } else { 'couchdb' }

$SrcDb = 'replicate-source'
$TgtDb = 'replicate-target'

$IrisAuth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${IrisUser}:${IrisPass}"))
$CouchAuth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${CouchUser}:${CouchPass}"))

function Iris([string]$Method, [string]$Path, [string]$Body) {
    try {
        $p = @{ Uri = "$IrisCouchUrl$Path"; Method = $Method; Headers = @{ Authorization = $IrisAuth } }
        if ($Body) { $p['Body'] = $Body; $p['ContentType'] = 'application/json' }
        return Invoke-RestMethod @p
    } catch { return $null }
}
function Couch([string]$Method, [string]$Path, [string]$Body) {
    try {
        $p = @{ Uri = "$CouchdbUrl$Path"; Method = $Method; Headers = @{ Authorization = $CouchAuth } }
        if ($Body) { $p['Body'] = $Body; $p['ContentType'] = 'application/json' }
        return Invoke-RestMethod @p
    } catch { return $null }
}

# Preflight
$probe = Couch 'GET' '/' $null
if (-not $probe) {
@"
[SKIPPED] No reachable Apache CouchDB at $CouchdbUrl.

This example requires a running CouchDB 3.x instance to replicate from.
Options to supply one:
  docker run --rm -d -p 5984:5984 -e COUCHDB_USER=admin -e COUCHDB_PASSWORD=couchdb --name couchdb-for-examples couchdb:3.3
or set COUCHDB_URL, COUCHDB_USER, COUCHDB_PASS to an existing instance.

Exiting with status 2 (conditional skip).
"@
    exit 2
}

Couch 'DELETE' "/$SrcDb" $null | Out-Null
Iris  'DELETE' "/$TgtDb" $null | Out-Null

Write-Output "Step 1: Seed source CouchDB at $CouchdbUrl/$SrcDb with 5 sample docs"
Couch 'PUT' "/$SrcDb" $null | Out-Null
for ($i = 1; $i -le 5; $i++) {
    $id = 'src-doc-' + $i.ToString('000')
    Couch 'PUT' "/$SrcDb/$id" "{`"origin`":`"apache-couchdb`",`"n`":$i}" | Out-Null
}
$src = Couch 'GET' "/$SrcDb" $null
Write-Output "Source /$SrcDb doc_count=$($src.doc_count)"

Write-Output 'Step 2: Create target database on IRISCouch'
(Iris 'PUT' "/$TgtDb" $null) | ConvertTo-Json -Compress

Write-Output 'Step 3: POST /_replicate on IRISCouch (source=apache-couchdb, target=iris-couch)'
$uri = [Uri]::new($CouchdbUrl)
$srcUrl = "${CouchUser}:${CouchPass}@$($uri.Host):$($uri.Port)"
$srcUrl = $uri.Scheme + '://' + $srcUrl + "/$SrcDb"
$replBody = "{`"source`":`"$srcUrl`",`"target`":`"$TgtDb`",`"continuous`":false}"
(Iris 'POST' '/_replicate' $replBody) | ConvertTo-Json -Compress -Depth 6

Write-Output 'Step 4: Confirm doc_count parity'
$tgt = Iris 'GET' "/$TgtDb" $null
Write-Output "Target /$TgtDb doc_count=$($tgt.doc_count)"
if ($src.doc_count -ne $tgt.doc_count) {
    Write-Output "FAIL: doc_count mismatch (source=$($src.doc_count) target=$($tgt.doc_count))"
    exit 1
}
Write-Output 'PARITY OK'

Write-Output 'Step 5: Spot-check one replicated document'
(Iris 'GET' "/$TgtDb/src-doc-003" $null) | ConvertTo-Json -Compress

Write-Output 'Step 6: Cleanup (drop both source and target)'
(Couch 'DELETE' "/$SrcDb" $null) | ConvertTo-Json -Compress
(Iris  'DELETE' "/$TgtDb" $null) | ConvertTo-Json -Compress
