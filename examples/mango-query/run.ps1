# mango-query example (PowerShell edition). See run.sh for protocol commentary.

$ErrorActionPreference = 'Stop'

$IrisCouchUrl = if ($env:IRISCOUCH_URL) { $env:IRISCOUCH_URL } else { 'http://localhost:52773/iris-couch' }
$User = if ($env:IRISCOUCH_USER) { $env:IRISCOUCH_USER } else { '_system' }
$Pass = if ($env:IRISCOUCH_PASS) { $env:IRISCOUCH_PASS } else { 'SYS' }
$Db = 'mango-query-example'

$basic = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${User}:${Pass}"))
$H = @{ Authorization = $basic }

function Safe-Rest([string]$Method, [string]$Path, [string]$Body) {
    try {
        $p = @{ Uri = "$IrisCouchUrl$Path"; Method = $Method; Headers = $H }
        if ($Body) { $p['Body'] = $Body; $p['ContentType'] = 'application/json' }
        return Invoke-RestMethod @p
    } catch { return $null }
}

Safe-Rest 'DELETE' "/$Db" $null | Out-Null

Write-Output "Step 1: PUT /$Db"
Safe-Rest 'PUT' "/$Db" $null | ConvertTo-Json -Compress

Write-Output 'Step 2: Seed 10 documents with status + created_at'
$seed = @(
    @{id='doc-001'; status='active'; ts='2026-06-01T10:00:00Z'},
    @{id='doc-002'; status='active'; ts='2026-06-02T10:00:00Z'},
    @{id='doc-003'; status='active'; ts='2026-06-03T10:00:00Z'},
    @{id='doc-004'; status='active'; ts='2025-12-30T10:00:00Z'},
    @{id='doc-005'; status='inactive'; ts='2026-06-04T10:00:00Z'},
    @{id='doc-006'; status='inactive'; ts='2026-06-05T10:00:00Z'},
    @{id='doc-007'; status='pending'; ts='2026-06-06T10:00:00Z'},
    @{id='doc-008'; status='pending'; ts='2025-11-15T10:00:00Z'},
    @{id='doc-009'; status='active'; ts='2026-06-07T10:00:00Z'},
    @{id='doc-010'; status='active'; ts='2026-06-08T10:00:00Z'}
)
foreach ($d in $seed) {
    $body = "{`"status`":`"$($d.status)`",`"created_at`":`"$($d.ts)`"}"
    Safe-Rest 'PUT' "/$Db/$($d.id)" $body | Out-Null
}
Write-Output "Seeded $($seed.Count) documents"

Write-Output "Step 3: POST /$Db/_index (status, created_at)"
Safe-Rest 'POST' "/$Db/_index" '{"index":{"fields":["status","created_at"]},"name":"status-created","type":"json"}' | ConvertTo-Json -Compress

Write-Output "Step 4: POST /$Db/_find selector={status:`$eq active, created_at:`$gt 2026-01-01}"
Safe-Rest 'POST' "/$Db/_find" '{"selector":{"$and":[{"status":{"$eq":"active"}},{"created_at":{"$gt":"2026-01-01"}}]},"execution_stats":true}' | ConvertTo-Json -Compress -Depth 10

Write-Output "Step 5: POST /$Db/_explain (confirm index used, not full-scan)"
Safe-Rest 'POST' "/$Db/_explain" '{"selector":{"$and":[{"status":{"$eq":"active"}},{"created_at":{"$gt":"2026-01-01"}}]}}' | ConvertTo-Json -Compress -Depth 10

Write-Output "Step 6: DELETE /$Db"
Safe-Rest 'DELETE' "/$Db" $null | ConvertTo-Json -Compress
