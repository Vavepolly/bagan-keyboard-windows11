# Official Microsoft compiler in temporary storage; WiX 3 creates our MSI.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $env:GITHUB_ACTIONS -or $env:RUNNER_OS -ne 'Windows') { throw 'Run this build on the disposable Windows GitHub Actions runner.' }
$Root = Split-Path $PSScriptRoot -Parent
$Output = Join-Path $Root 'ci-output'
$Logs = Join-Path $Output 'diagnostics'
$Temp = Join-Path $env:RUNNER_TEMP 'bagan-native'
New-Item -ItemType Directory -Force -Path $Logs, $Temp | Out-Null
Start-Transcript -Path (Join-Path $Logs 'build-transcript.txt')
function Run([string]$Exe, [string[]]$Arguments, [string]$Name, [int[]]$Allowed = @(0)) {
    Write-Host "Running $Name"
    $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $Logs "$Name.stdout.txt") -RedirectStandardError (Join-Path $Logs "$Name.stderr.txt")
    Get-Content -LiteralPath (Join-Path $Logs "$Name.stdout.txt")
    Get-Content -LiteralPath (Join-Path $Logs "$Name.stderr.txt")
    if ($Allowed -notcontains $p.ExitCode) { throw "$Name exited $($p.ExitCode); see diagnostics." }
}
try {
    $Hashes = Get-Content (Join-Path $Root 'source\generated-sha256.json') -Raw | ConvertFrom-Json
    foreach ($Entry in $Hashes.PSObject.Properties) {
        if ((Get-FileHash (Join-Path $Root $Entry.Name) -Algorithm SHA256).Hash -ne $Entry.Value) { throw "Source hash mismatch: $($Entry.Name)" }
    }
    # URL linked by Microsoft's official download page (id=102134).
    $Url = 'https://download.microsoft.com/download/6/f/5/6f5ce43a-e892-4fd1-b9a6-1a0cbb64e6e2/MSKLC.exe'
    $Download = Join-Path $Temp 'MSKLC.exe'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Response = Invoke-WebRequest -Uri $Url -OutFile $Download -PassThru -UseBasicParsing -MaximumRedirection 0
    if ((Get-Item $Download).Length -lt 1000000) { throw 'Unexpectedly small Microsoft download.' }
    $Signature = Get-AuthenticodeSignature -FilePath $Download
    $Digest = (Get-FileHash $Download -Algorithm SHA256).Hash
    [ordered]@{
        url=$Url; sha256=$Digest; bytes=(Get-Item $Download).Length
        signatureStatus=[string]$Signature.Status
        signer=if ($Signature.SignerCertificate) { $Signature.SignerCertificate.Subject } else { $null }
    } | ConvertTo-Json | Set-Content (Join-Path $Logs 'microsoft-download.json') -Encoding UTF8
    if ($Signature.Status -ne 'Valid' -or $Signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
        throw 'Microsoft Authenticode validation failed. No unverified tool will be executed.'
    }
    $Archive = Join-Path $Temp 'archive'
    $SevenZip = Join-Path ${env:ProgramFiles} '7-Zip\7z.exe'
    if (-not (Test-Path $SevenZip)) { throw 'Runner 7-Zip is missing.' }
    Run $SevenZip @('x','-y',"-o$Archive",$Download) 'extract-official-download'
    $Msis = @(Get-ChildItem $Archive -Recurse -Filter '*.msi')
    if ($Msis.Count -ne 1) { throw "Expected one MSKLC MSI in official archive, found $($Msis.Count). Inspect extraction log; do not use a mirror." }
    $ToolRoot = Join-Path $Temp 'msklc'
    $AdminLog = Join-Path $Logs 'msklc-admin-extraction.log'
    Run "$env:WINDIR\System32\msiexec.exe" @('/a',('"' + $Msis[0].FullName + '"'),'/qn',('TARGETDIR="' + $ToolRoot + '"'),'/l*v',('"' + $AdminLog + '"')) 'msklc-admin-extraction' @(0,3010)
    $Tools = @(Get-ChildItem $ToolRoot -Recurse -Filter 'kbdutool.exe' | Where-Object { $_.FullName -match '\\bin\\i386\\kbdutool.exe$' })
    if ($Tools.Count -ne 1) { throw "Expected one extracted bin/i386/kbdutool.exe; found $($Tools.Count)." }
    $Tool = $Tools[0].FullName
    Run $Tool @('-?') 'kbdutool-help' @(0,1)
    $Help = (Get-Content (Join-Path $Logs 'kbdutool-help.stdout.txt') -Raw) + (Get-Content (Join-Path $Logs 'kbdutool-help.stderr.txt') -Raw)
    if ($Help -notmatch 'AMD64' -or $Help -notmatch 'WOW64') { throw 'The actual compiler help does not confirm both required architectures.' }
    Get-ChildItem $ToolRoot -Recurse -File | Where-Object { $_.Extension -in '.txt','.rtf' -and $_.Name -match 'license|eula|redist' } | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $Logs ('msklc-' + $_.Name))
    }
    foreach ($Architecture in @(@('amd64','-m'), @('wow64','-o'))) {
        $Dir = Join-Path $Output $Architecture[0]
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
        # kbdutool 3.40 does not have a VK_TAB name in its editable key-name
        # table. The explicit 0f TAB row produces #ERROR# in generated C.
        # Omit that redundant row ONLY in the build copy; its standard tables
        # already handle Tab. Preserve the original source and all 94 mappings.
        $Text = [IO.File]::ReadAllText((Join-Path $Root 'source\bgmyuni.klc'), [Text.Encoding]::Unicode)
        $TabRow = "0f`tTAB`t0`t0009`t0009`t-1"
        if (($Text.Split(@($TabRow), [StringSplitOptions]::None)).Length -ne 2) { throw 'Expected exactly one explicit Tab row; review compiler-input conversion.' }
        $Text = $Text.Replace($TabRow, '// Tab uses the compiler standard keyboard tables.')
        [IO.File]::WriteAllText((Join-Path $Dir 'bgmyuni.klc'), $Text, [Text.Encoding]::Unicode)
        Copy-Item (Join-Path $Dir 'bgmyuni.klc') (Join-Path $Logs ('compiler-input-' + $Architecture[0] + '.klc'))
        Push-Location $Dir
        try { Run $Tool @('-u','-w',$Architecture[1],'bgmyuni.klc') ('compile-' + $Architecture[0]) }
        finally {
            Get-ChildItem $Dir -File | Where-Object { $_.Extension -in '.c','.h','.rc','.def' } | ForEach-Object {
                Copy-Item $_.FullName (Join-Path $Logs ($Architecture[0] + '-' + $_.Name))
            }
            Pop-Location
        }
        if (-not (Test-Path (Join-Path $Dir 'bgmyuni.dll'))) { throw "Compiler did not produce $($Architecture[0]) DLL." }
    }
    # WiX 3 is preinstalled on windows-2022; never fetch commercial WiX variants.
    $WixBin = if ($env:WIX) { Join-Path $env:WIX 'bin' } else { Join-Path ${env:ProgramFiles(x86)} 'WiX Toolset v3.14\bin' }
    $WixSdk = Join-Path (Split-Path $WixBin -Parent) 'SDK'
    foreach ($File in @((Join-Path $WixBin 'candle.exe'), (Join-Path $WixBin 'light.exe'), (Join-Path $WixSdk 'MakeSfxCA.exe'))) {
        if (-not (Test-Path $File)) { throw "Missing runner WiX 3 dependency: $File" }
    }
    $Csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    $Dtf = Join-Path $WixSdk 'Microsoft.Deployment.WindowsInstaller.dll'
    $Guard = Join-Path $Output 'CollisionGuard.dll'
    Copy-Item (Join-Path $Root 'installer\CustomAction.config') $Output
    Run $Csc @('/nologo','/target:library','/platform:x64',('/reference:"' + $Dtf + '"'),('/out:"' + $Guard + '"'),('"' + (Join-Path $Root 'installer\CollisionGuard.cs') + '"')) 'compile-msi-collision-guard'
    Run (Join-Path $WixSdk 'MakeSfxCA.exe') @(('"' + (Join-Path $Output 'CollisionGuard.CA.dll') + '"'),('"' + (Join-Path $WixSdk 'x64\SfxCA.dll') + '"'),('"' + $Guard + '"'),('"' + $Dtf + '"'),('"' + (Join-Path $Output 'CustomAction.config') + '"')) 'package-msi-collision-guard'
    $Release = Join-Path $Root 'release'
    New-Item -ItemType Directory -Force -Path $Release | Out-Null
    $Msi = Join-Path $Release 'Bagan-Myanmar-Native-x64.msi'
    $Obj = Join-Path $Output 'NativeKeyboard.wixobj'
    Run (Join-Path $WixBin 'candle.exe') @('-nologo','-arch','x64',('-dBuildRoot="' + $Output + '"'),('-dProjectRoot="' + $Root + '"'),'-out',('"' + $Obj + '"'),('"' + (Join-Path $Root 'installer\NativeKeyboard.wxs') + '"')) 'wix-candle'
    Run (Join-Path $WixBin 'light.exe') @('-nologo','-out',('"' + $Msi + '"'),('"' + $Obj + '"')) 'wix-light'
    Copy-Item (Join-Path $Root 'ci\START-HERE.txt') $Release
    Copy-Item (Join-Path $Root 'KEYMAP.md') $Release
    Copy-Item (Join-Path $Root 'ACCEPTANCE-WINDOWS.md') $Release
    Copy-Item (Join-Path $Root 'ci\CI-INSTALL.md') $Release
    # No third-party installers/compiler binaries leave RUNNER_TEMP.
    Write-Host "MSI generated (verification is the next job step): $Msi"
}
finally { Stop-Transcript }
