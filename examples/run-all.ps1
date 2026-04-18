# run-all.ps1 — PowerShell edition of the example-runner harness. See run-all.sh
# for commentary. Exit codes: 0 = all pass, 1 = any failure. Skipped (exit 2)
# counts as pass-with-caveat.

param(
    [string]$Filter = '',
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'
$DIR = $PSScriptRoot
$LogDir = Join-Path $DIR '_logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$examples = @(
    @{ name = 'hello-document';          cmd = '.\run.ps1' }
    @{ name = 'pouchdb-sync';            cmd = 'node run.mjs' }
    @{ name = 'replicate-from-couchdb';  cmd = '.\run.ps1' }
    @{ name = 'mango-query';             cmd = '.\run.ps1' }
    @{ name = 'attachment-upload';       cmd = 'node run.mjs' }
    @{ name = 'jsruntime-subprocess-node'; cmd = '.\run.ps1' }
)

$pass = 0; $fail = 0; $skip = 0
$failedNames = @(); $skippedNames = @()

foreach ($ex in $examples) {
    if ($Filter -and ($ex.name -notlike "*$Filter*")) { continue }

    Write-Output ''
    Write-Output '=========================================================='
    Write-Output ('RUNNING: ' + $ex.name)
    Write-Output '=========================================================='

    $log = Join-Path $LogDir ($ex.name + '.log')
    Push-Location (Join-Path $DIR $ex.name)
    try {
        Invoke-Expression $ex.cmd *> $log
        $status = $LASTEXITCODE
        if (-not $status) { $status = 0 }
    } finally {
        Pop-Location
    }

    switch ($status) {
        0 {
            $pass++
            Write-Output ('[PASS] ' + $ex.name)
            if (-not $Quiet) { Get-Content $log }
        }
        2 {
            $skip++
            $skippedNames += $ex.name
            Write-Output ('[SKIP] ' + $ex.name + ' (conditional prerequisite missing)')
            if (-not $Quiet) { Get-Content $log }
        }
        default {
            $fail++
            $failedNames += $ex.name
            Write-Output ('[FAIL] ' + $ex.name + ' (exit ' + $status + ')')
            Get-Content $log
        }
    }
}

Write-Output ''
Write-Output '=========================================================='
Write-Output ('SUMMARY: ' + $pass + ' passed, ' + $fail + ' failed, ' + $skip + ' skipped')
if ($skippedNames.Count -gt 0) { Write-Output ('Skipped: ' + ($skippedNames -join ', ')) }
if ($failedNames.Count -gt 0) { Write-Output ('Failed: ' + ($failedNames -join ', ')) }
Write-Output '=========================================================='

exit $(if ($fail -eq 0) { 0 } else { 1 })
