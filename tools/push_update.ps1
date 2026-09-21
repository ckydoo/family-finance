# One command: overlay the sandbox download, commit, push.
# Usage: .\tools\push_update.ps1 -Zip C:\...\mhuri-money.zip [-Message "..."]
param(
  [Parameter(Mandatory=$true)][string]$Zip,
  [Parameter(Mandatory=$false)][string]$Message
)
$ErrorActionPreference='Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$from = $Zip; $tmp = Join-Path $env:TEMP ("mhuri_"+[guid]::NewGuid().ToString("N"))
if (Test-Path $Zip -PathType Container) { $from = $Zip }
elseif (Test-Path $Zip -PathType Leaf) {
  New-Item -ItemType Directory -Path $tmp | Out-Null
  Expand-Archive -Path $Zip -DestinationPath $tmp -Force
  $f = Get-ChildItem $tmp -Recurse -Directory -Filter 'mhuri-money' | Select-Object -First 1
  $from = if ($f) { $f.FullName } else { $tmp }
} else { throw "not a file or folder: $Zip" }

Set-Location $Repo
robocopy $from $Repo /E /NFL /NDL /NJH /NJS /XD .git build .dart_tool | Out-Null
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }

if (-not $Message -and (Test-Path "$Repo\RELEASE_NOTE.md")) {
  $Message = (Get-Content "$Repo\RELEASE_NOTE.md" -TotalCount 1)
}
git add -A
$staged = git diff --staged --name-only
if (-not $staged) { Write-Host "Nothing new to commit."; exit 0 }
git commit -m $(if ($Message) { $Message } else { "Sync from sandbox" })
git push
Write-Host "pushed"
