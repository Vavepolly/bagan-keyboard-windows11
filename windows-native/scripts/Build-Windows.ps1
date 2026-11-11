# Prepare a clean, hash-checked MSKLC workspace. Does not install anything.
# Windows PowerShell 5.1. MSKLC's GUI performs the DLL/MSI build, not this script.
[CmdletBinding()]
param(
    [string]$WorkDirectory = (Join-Path $env:TEMP 'BaganNativeBuild'),
    [string]$MsklcPath = (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Keyboard Layout Creator 1.4\MSKLC.exe')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Run on Windows x64.' }
if (-not [Environment]::Is64BitOperatingSystem) { throw 'This project targets Windows x64.' }
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
    throw 'ARM64 is not a supported build or acceptance target for this project.'
}
$Root = Split-Path $PSScriptRoot -Parent
$WorkDirectory = [IO.Path]::GetFullPath($WorkDirectory)
if ($WorkDirectory -match '\s|[^\x00-\x7f]') {
    throw 'Legacy MSKLC needs a simple build path. Create an empty C:\BaganNativeBuild folder and pass -WorkDirectory C:\BaganNativeBuild.'
}
if (-not (Test-Path -LiteralPath $MsklcPath -PathType Leaf)) {
    throw 'MSKLC 1.4 is missing. See BUILD.md. Nothing has been downloaded or installed. Use -MsklcPath if installed elsewhere.'
}
$Hashes = Get-Content -LiteralPath (Join-Path $Root 'source\generated-sha256.json') -Raw | ConvertFrom-Json
foreach ($Entry in $Hashes.PSObject.Properties) {
    $Actual = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Root $Entry.Name)).Hash
    if ($Actual -ne $Entry.Value) { throw "Generated file changed: $($Entry.Name). Regenerate and validate first." }
}
if ((Test-Path -LiteralPath $WorkDirectory) -and @(Get-ChildItem -LiteralPath $WorkDirectory -Force).Count -ne 0) {
    throw 'Build directory is not empty. Choose a new empty directory; existing files will not be overwritten.'
}
$null = New-Item -ItemType Directory -Path $WorkDirectory -Force
$Source = Join-Path $WorkDirectory 'bgmyuni.klc'
Copy-Item -LiteralPath (Join-Path $Root 'source\bgmyuni.klc') -Destination $Source
Write-Host "Prepared: $Source"
Write-Host 'In MSKLC: File > Load Source File, and select that file.'
Write-Host 'Project > Properties: keep name bgmyuni and the existing description/language.'
Write-Host 'Keep the output folder under this empty workspace. Run Project > Validate Layout.'
Write-Host 'Review the validation log, then Project > Build DLL and Setup Package.'
Write-Host 'Keep the entire generated package folder. Follow BUILD.md to validate and package it.'
Write-Host 'Opening MSKLC only; this script does not run setup.exe or register any layout.'
Start-Process -FilePath $MsklcPath
