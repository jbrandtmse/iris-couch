# hello-document example (PowerShell edition).
# See run.sh for protocol commentary; this is the Windows-native equivalent.

$ErrorActionPreference = 'Stop'

$IrisCouchUrl = if ($env:IRISCOUCH_URL) { $env:IRISCOUCH_URL } else { 'http://localhost:52773/iris-couch' }
$User = if ($env:IRISCOUCH_USER) { $env:IRISCOUCH_USER } else { '_system' }
$Pass = if ($env:IRISCOUCH_PASS) { $env:IRISCOUCH_PASS } else { 'SYS' }
$Db = 'hello-document-example'

$pair = "${User}:${Pass}"
$basic = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$Headers = @{ Authorization = $basic }

function Invoke-Rest([string]$Method, [string]$Path, [string]$Body) {
    $uri = "$IrisCouchUrl$Path"
    $params = @{ Uri = $uri; Method = $Method; Headers = $Headers; ErrorAction = 'SilentlyContinue' }
    if ($Body) { $params['Body'] = $Body; $params['ContentType'] = 'application/json' }
    try {
        return Invoke-RestMethod @params
    } catch {
        return $null
    }
}

# Clean slate
Invoke-Rest -Method 'DELETE' -Path "/$Db" | Out-Null

Write-Output "Step 1: PUT /$Db"
Invoke-Rest -Method 'PUT' -Path "/$Db" | ConvertTo-Json -Compress

Write-Output "Step 2: PUT /$Db/greeting (initial body)"
$r1 = Invoke-Rest -Method 'PUT' -Path "/$Db/greeting" -Body '{"message":"hello, iris-couch","lang":"en"}'
$r1 | ConvertTo-Json -Compress
$rev1 = $r1.rev

Write-Output "Step 3: GET /$Db/greeting"
Invoke-Rest -Method 'GET' -Path "/$Db/greeting" | ConvertTo-Json -Compress

Write-Output "Step 4: PUT /$Db/greeting?rev=$rev1 (update)"
$r2 = Invoke-Rest -Method 'PUT' -Path "/$Db/greeting?rev=$rev1" -Body '{"message":"hello again, iris-couch","lang":"en"}'
$r2 | ConvertTo-Json -Compress
$rev2 = $r2.rev

Write-Output "Step 5: DELETE /$Db/greeting?rev=$rev2"
Invoke-Rest -Method 'DELETE' -Path "/$Db/greeting?rev=$rev2" | ConvertTo-Json -Compress

Write-Output "Step 6: GET /$Db/greeting (expect 404)"
try {
    Invoke-WebRequest -Uri "$IrisCouchUrl/$Db/greeting" -Headers $Headers -Method 'GET' -ErrorAction Stop | Out-Null
    Write-Output 'HTTP 200'
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Output "HTTP $code"
}

Write-Output "Step 7: DELETE /$Db"
Invoke-Rest -Method 'DELETE' -Path "/$Db" | ConvertTo-Json -Compress
