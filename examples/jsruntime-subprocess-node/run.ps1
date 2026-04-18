# jsruntime-subprocess-node (PowerShell edition). See run.sh for commentary.

$ErrorActionPreference = 'Stop'
$DIR = $PSScriptRoot

Write-Output 'Probe: verify JSRUNTIME=Subprocess is active'
node "$DIR/setup.js" probe
if ($LASTEXITCODE -ne 0) {
    Write-Output ''
    Write-Output '[SKIPPED] Subprocess JSRuntime not available; see instructions above.'
    exit 2
}
Write-Output ''

node "$DIR/setup.js" seed
Write-Output ''
node "$DIR/setup.js" query-map
Write-Output ''
node "$DIR/setup.js" query-reduce
Write-Output ''
node "$DIR/setup.js" cleanup
