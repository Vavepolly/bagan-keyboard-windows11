# Inspect the real MSI, extract its payload, install/test/uninstall on the
# disposable Windows Server runner. This is NOT Windows 11 desktop acceptance.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $env:GITHUB_ACTIONS -or $env:RUNNER_OS -ne 'Windows') { throw 'Temporary Windows GitHub runner only.' }
$Root = Split-Path $PSScriptRoot -Parent
$Build = Join-Path $Root 'ci-output'
$Logs = Join-Path $Build 'diagnostics'
$Release = Join-Path $Root 'release'
$Msi = Join-Path $Release 'Bagan-Myanmar-Native-x64.msi'
$RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\a7b90409'
Start-Transcript -Path (Join-Path $Logs 'verification-transcript.txt')
function Assert([bool]$Value, [string]$Message) { if (-not $Value) { throw $Message }; Write-Host "PASS: $Message" }
function Query([object]$Database, [string]$Sql, [int]$Columns) {
    $View = $Database.OpenView($Sql)
    $View.Execute()
    $Rows = @()
    while ($Record = $View.Fetch()) {
        $Values = @()
        for ($i=1; $i -le $Columns; $i++) { $Values += $Record.StringData($i) }
        $Rows += ,$Values
    }
    $View.Close()
    return ,$Rows
}
function Machine([string]$Path) {
    $Data = [IO.File]::ReadAllBytes($Path)
    Assert ($Data.Length -gt 64 -and $Data[0] -eq 0x4d -and $Data[1] -eq 0x5a) "PE signature: $Path"
    $Offset = [BitConverter]::ToInt32($Data, 0x3c)
    Assert ($Offset -gt 0 -and $Offset + 24 -lt $Data.Length -and [BitConverter]::ToUInt32($Data,$Offset) -eq 0x4550) 'Valid PE header'
    return [BitConverter]::ToUInt16($Data,$Offset+4)
}
function MsiExec([string[]]$Arguments, [string]$Name) {
    $Log = Join-Path $Logs "$Name.log"
    $Process = Start-Process "$env:WINDIR\System32\msiexec.exe" -ArgumentList ($Arguments + @('/qn','/norestart','/l*v',('"' + $Log + '"'))) -PassThru -Wait
    Assert ($Process.ExitCode -in @(0,3010)) "$Name MSI exit code $($Process.ExitCode)"
}
$Installed = $false
try {
    Assert (Test-Path $Msi) 'A real installer exists'
    Assert ((Machine (Join-Path $Build 'amd64\bgmyuni.dll')) -eq 0x8664) 'AMD64 DLL architecture'
    Assert ((Machine (Join-Path $Build 'wow64\bgmyuni.dll')) -eq 0x14c) 'WOW64 DLL PE architecture'
    $Installer = New-Object -ComObject WindowsInstaller.Installer
    $Db = $Installer.GetType().InvokeMember('OpenDatabase','InvokeMethod',$null,$Installer,@($Msi,0))
    $Summary = $Db.GetType().InvokeMember('SummaryInformation','GetProperty',$null,$Db,@(0))
    $Template = $Summary.GetType().InvokeMember('Property','GetProperty',$null,$Summary,@(7))
    Assert ($Template -match '^x64(;|$)') 'MSI architecture is x64'
    $Files = Query $Db 'SELECT `File`, `FileName`, `Component_` FROM `File`' 3
    Assert ($Files.Count -eq 4) 'MSI has only two keyboard DLLs and two help files'
    $Names = @($Files | ForEach-Object { ($_[1] -split '\|')[-1] })
    Assert (@($Names | Where-Object { $_ -eq 'bgmyuni.dll' }).Count -eq 2) 'Both architecture payloads present'
    Assert (@($Names | Where-Object { $_ -notin @('bgmyuni.dll','START-HERE.txt','KEYMAP.md') }).Count -eq 0) 'No downloaded third-party tool bundled'
    $Media = Query $Db 'SELECT `Cabinet` FROM `Media`' 1
    Assert ($Media.Count -eq 1 -and $Media[0][0].StartsWith('#')) 'Installer cabinet is embedded'
    $Registry = Query $Db 'SELECT `Root`, `Key`, `Name`, `Value` FROM `Registry`' 4
    Assert ($Registry.Count -eq 4) 'Only own keyboard and ownership marker registry values'
    foreach ($Entry in $Registry) {
        Assert ($Entry[0] -eq '2' -and $Entry[1] -in @('SYSTEM\CurrentControlSet\Control\Keyboard Layouts\a7b90409','SOFTWARE\BaganNativeProject')) 'Registry write scope is restricted'
    }
    # Extract the embedded cabinet and compare to the compiled input, not just filenames.
    $Extract = Join-Path $env:RUNNER_TEMP 'bagan-payload-check'
    MsiExec @('/a',('"' + $Msi + '"'),('TARGETDIR="' + $Extract + '"')) 'extract-our-msi'
    $Dlls = @(Get-ChildItem $Extract -Recurse -File -Filter 'bgmyuni.dll')
    Assert ($Dlls.Count -eq 2) 'Exactly two extracted keyboard DLLs'
    foreach ($Dll in $Dlls) {
        $Arch = Machine $Dll.FullName
        $Original = if ($Arch -eq 0x8664) { Join-Path $Build 'amd64\bgmyuni.dll' } elseif ($Arch -eq 0x14c) { Join-Path $Build 'wow64\bgmyuni.dll' } else { throw 'Unexpected extracted architecture' }
        Assert ((Get-FileHash $Dll.FullName).Hash -eq (Get-FileHash $Original).Hash) 'Embedded DLL hash equals compiled DLL hash'
    }
    $Baseline = @{}
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts' | ForEach-Object {
        $Baseline[$_.PSChildName] = Get-ItemPropertyValue $_.PSPath -Name 'Layout File' -ErrorAction SilentlyContinue
    }
    Assert (-not (Test-Path $RegistryPath)) 'Fresh runner has no conflicting own layout'
    Assert (-not (Test-Path "$env:WINDIR\System32\bgmyuni.dll")) 'Fresh runner has no conflicting DLL'
    MsiExec @('/i',('"' + $Msi + '"')) 'install-native-msi'
    $Installed = $true
    Assert (Test-Path $RegistryPath) 'Own native layout registration installed'
    foreach ($Arch in @('x64','wow64')) {
        $PowerShell = if ($Arch -eq 'x64') { "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" } else { "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" }
        $Script = Join-Path $Root 'scripts\Test-InstalledLayout.ps1'
        $Process = Start-Process $PowerShell -ArgumentList @('-NoProfile','-NonInteractive','-File',('"' + $Script + '"')) -PassThru -Wait -RedirectStandardOutput (Join-Path $Logs "native-api-$Arch.stdout.txt") -RedirectStandardError (Join-Path $Logs "native-api-$Arch.stderr.txt")
        Get-Content (Join-Path $Logs "native-api-$Arch.stdout.txt")
        Get-Content (Join-Path $Logs "native-api-$Arch.stderr.txt")
        Assert ($Process.ExitCode -eq 0) "Native $Arch API test process passed"
        $ReportPath = Join-Path $Root 'windows-native-api-results.json'
        $Report = Get-Content $ReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert ($Report.failed -eq 0 -and $Report.passed -eq 221) "221 $Arch mapping/control API checks passed"
        Copy-Item $ReportPath (Join-Path $Logs "native-api-$Arch.json")
    }
    MsiExec @('/x',('"' + $Msi + '"')) 'uninstall-native-msi'
    $Installed = $false
    # MSI removes its own values; an empty layout key is harmless but cannot have Layout File.
    $Left = Get-ItemPropertyValue $RegistryPath -Name 'Layout File' -ErrorAction SilentlyContinue
    Assert ([string]::IsNullOrEmpty($Left)) 'Own layout registration removed'
    foreach ($Key in $Baseline.Keys) {
        $Actual = Get-ItemPropertyValue ("HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\" + $Key) -Name 'Layout File' -ErrorAction SilentlyContinue
        Assert ($Actual -eq $Baseline[$Key]) "Existing layout unchanged: $Key"
    }
    [ordered]@{
        status='MSI built and verified on GitHub Windows Server 2022; Windows 11 desktop acceptance NOT performed'
        runUrl="https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
        commit=$env:GITHUB_SHA
        msiSha256=(Get-FileHash $Msi -Algorithm SHA256).Hash
        x64ApiChecks=221; wow64ApiChecks=221
        msiContents='Embedded DLL payload hashes match; native and WOW64 architectures checked'
        runnerInstallUninstall='Passed; pre-existing layout file registrations unchanged'
        windows11Acceptance='NOT RUN'; codeSigning='Unsigned project MSI/DLLs'
    } | ConvertTo-Json | Set-Content (Join-Path $Release 'BUILD-VERIFICATION.json') -Encoding UTF8
    Get-ChildItem $Release -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | ForEach-Object {
        '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash, $_.Name
    } | Set-Content (Join-Path $Release 'SHA256SUMS.txt') -Encoding UTF8
}
finally {
    if ($Installed) {
        $p = Start-Process "$env:WINDIR\System32\msiexec.exe" -ArgumentList @('/x',('"' + $Msi + '"'),'/qn','/norestart') -Wait -PassThru
        Write-Host "Cleanup uninstall exit code: $($p.ExitCode)"
    }
    Stop-Transcript
}
