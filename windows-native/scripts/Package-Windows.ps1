# Validate an MSKLC-produced installer folder and make a beginner handoff ZIP.
# Does not execute the generated DLLs, setup.exe or MSI, or write the registry.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageDirectory,
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'release')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Run on Windows; MSI metadata checks require Windows Installer.' }
$Root = Split-Path $PSScriptRoot -Parent
$PackageDirectory = (Resolve-Path -LiteralPath $PackageDirectory).Path
$Setup = Join-Path $PackageDirectory 'setup.exe'
if (-not (Test-Path -LiteralPath $Setup -PathType Leaf)) { throw 'Select the MSKLC output folder containing setup.exe.' }

function Get-PeMachine([string]$Path) {
    $Bytes = [IO.File]::ReadAllBytes($Path)
    if ($Bytes.Length -lt 64 -or $Bytes[0] -ne 0x4d -or $Bytes[1] -ne 0x5a) { throw "Not a PE file: $Path" }
    $Offset = [BitConverter]::ToInt32($Bytes, 0x3c)
    if ($Offset -lt 0 -or $Offset + 24 -gt $Bytes.Length -or [BitConverter]::ToUInt32($Bytes, $Offset) -ne 0x4550) {
        throw "Invalid PE header: $Path"
    }
    return [BitConverter]::ToUInt16($Bytes, $Offset + 4)
}
$null = Get-PeMachine $Setup # Often an x86 bootstrapper, even for x64 installations.
$Dlls = @(Get-ChildItem -LiteralPath $PackageDirectory -Recurse -File -Filter '*.dll')
if ($Dlls.Count -eq 0) { throw 'No layout DLLs found.' }
$Machines = @()
foreach ($Dll in $Dlls) {
    if ($Dll.Name -ne 'bgmyuni.dll') { throw "Unexpected DLL: $($Dll.Name). Refusing a package for a different keyboard." }
    $Machines += Get-PeMachine $Dll.FullName
}
if ($Machines -notcontains 0x8664) { throw 'No AMD64 (x64) layout DLL found.' }
if ($Machines -notcontains 0x014c) { throw 'No x86 layout DLL found for 32-bit applications on x64 Windows.' }
$Msis = @(Get-ChildItem -LiteralPath $PackageDirectory -File -Filter '*.msi')
if ($Msis.Count -eq 0) { throw 'No generated MSI found beside setup.exe.' }
$Installer = New-Object -ComObject WindowsInstaller.Installer
$X64Msi = @()
foreach ($Msi in $Msis) {
    # OpenDatabase mode 0 is read-only. No install/configure methods are called.
    $Db = $Installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $Installer, @($Msi.FullName, 0))
    $Summary = $Db.GetType().InvokeMember('SummaryInformation', 'GetProperty', $null, $Db, @(0))
    $Template = $Summary.GetType().InvokeMember('Property', 'GetProperty', $null, $Summary, @(7))
    if ($Template -match '^x64(;|$)') {
        $View = $Db.OpenView('SELECT `FileName` FROM `File`')
        $View.Execute()
        $Found = $false
        while ($Record = $View.Fetch()) {
            $FileName = $Record.StringData(1)
            if (($FileName -split '\|')[-1] -ieq 'bgmyuni.dll') { $Found = $true }
        }
        $View.Close()
        if (-not $Found) { throw 'The x64 MSI does not list bgmyuni.dll in its File table.' }
        $X64Msi += $Msi.Name
    }
}
if ($X64Msi.Count -ne 1) { throw "Expected one x64 MSI; found $($X64Msi.Count)." }

# Preserve the complete setup tree: its bootstrapper expects sibling MSI files
# and architecture folders. Reject an output folder inside the input tree.
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if ($OutputDirectory.TrimEnd('\') -eq $PackageDirectory.TrimEnd('\') -or
    $OutputDirectory.StartsWith($PackageDirectory.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDirectory must be outside PackageDirectory.'
}
if (Test-Path -LiteralPath $OutputDirectory) { throw 'OutputDirectory already exists. Choose a fresh directory to avoid mixing builds.' }
$Stage = Join-Path $OutputDirectory 'Bagan-Myanmar-Native-x64'
$null = New-Item -ItemType Directory -Path $Stage -Force
Get-ChildItem -LiteralPath $PackageDirectory -Force | Copy-Item -Destination $Stage -Recurse
Copy-Item -LiteralPath (Join-Path $Root 'INSTALL-WINDOWS.md') -Destination (Join-Path $Stage 'START-HERE.txt')
Copy-Item -LiteralPath (Join-Path $Root 'ACCEPTANCE-WINDOWS.md') -Destination $Stage
Copy-Item -LiteralPath (Join-Path $Root 'KEYMAP.md') -Destination $Stage
Copy-Item -LiteralPath (Join-Path $Root 'source\bgmyuni.klc') -Destination $Stage
Copy-Item -LiteralPath (Join-Path $Root 'source\mapping.json') -Destination $Stage
$Report = [ordered]@{
    status = 'Windows package structure checked; installation and typing acceptance NOT verified'
    x64Msi = $X64Msi[0]
    architectures = @('x64', 'x86 for WOW64')
    sourceKlcSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Stage 'bgmyuni.klc')).Hash
    note = 'Structure checks do not prove that the generated DLL implements the source; run native acceptance checks.'
}
$Report | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $Stage 'BUILD-CHECK.json')
$Hashes = Get-ChildItem -LiteralPath $Stage -Recurse -File | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash, $_.FullName.Substring($Stage.Length + 1)
}
$Hashes | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $Stage 'SHA256SUMS.txt')
$Zip = Join-Path $OutputDirectory 'Bagan-Myanmar-Native-x64.zip'
Compress-Archive -LiteralPath $Stage -DestinationPath $Zip
Write-Host "Created handoff ZIP: $Zip"
Write-Host "Installer: $(Join-Path $Stage 'setup.exe')"
Write-Host 'No installation was performed. Complete ACCEPTANCE-WINDOWS.md before release.'
