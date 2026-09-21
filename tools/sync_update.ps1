# Overlay a sandbox download onto your git clone, then show the diff.
# Usage: .\tools\sync_update.ps1 -Zip C:\Users\you\Downloads\mhuri-money.zip
param(
  [Parameter(Mandatory = $true)][string]$Zip
)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot

$from = $Zip
$tmp = Join-Path $env:TEMP ("mhuri_" + [guid]::NewGuid().ToString("N"))
if (Test-Path $Zip -PathType Container) {
  $from = $Zip
} elseif (Test-Path $Zip -PathType Leaf) {
  New-Item -ItemType Directory -Path $tmp | Out-Null
  Expand-Archive -Path $Zip -DestinationPath $tmp -Force
  $found = Get-ChildItem $tmp -Recurse -Directory -Filter 'mhuri-money' |
    Select-Object -First 1
  $from = if ($found) { $found.FullName } else { $tmp }
} else {
  throw "not a file or folder: $Zip"
}

Write-Host "Syncing $from -> $Repo"
robocopy $from $Repo /E /NFL /NDL /NJH /NJS /XD .git node_modules build .dart_tool `
  | Out-Null
# never touch local secrets
if (Test-Path "$from\app\.env") { Write-Warning "download contains .env - NOT copied" }

if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }

Set-Location $Repo
Write-Host ""
Write-Host "-- git status ------------------------------"
git status --short
Write-Host ""
Write-Host "Review: git diff   |   Commit: git add -A; git commit -m 'Sync from sandbox'"
