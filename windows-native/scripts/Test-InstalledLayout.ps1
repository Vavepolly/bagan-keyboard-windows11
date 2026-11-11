# Windows-only native API checks AFTER installing a locally built package.
# Reads the layout registration, loads its tables for this process, then uses
# ToUnicodeEx. Does not inject keystrokes, install, or write registry values.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Windows 11 x64 is required.' }
$Root = Split-Path $PSScriptRoot -Parent
$Mapping = Get-Content -LiteralPath (Join-Path $Root 'source\mapping.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$Registrations = @(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts' | Where-Object {
    (Get-ItemPropertyValue -LiteralPath $_.PSPath -Name 'Layout File' -ErrorAction SilentlyContinue) -ieq 'bgmyuni.dll'
})
if ($Registrations.Count -ne 1) { throw "Expected one installed bgmyuni.dll layout, found $($Registrations.Count). Install the native test package first." }
$Klid = $Registrations[0].PSChildName
if ($Klid -notmatch '^[0-9a-fA-F]{8}$') { throw 'Unexpected layout registration identifier.' }
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class BaganNativeTest {
  [DllImport("user32.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)]
  public static extern IntPtr LoadKeyboardLayoutW(string id, uint flags);
  [DllImport("user32.dll")]
  public static extern int GetKeyboardLayoutList(int count, [Out] IntPtr[] layouts);
  [DllImport("user32.dll")]
  public static extern bool UnloadKeyboardLayout(IntPtr layout);
  [DllImport("user32.dll", CharSet=CharSet.Unicode, ExactSpelling=true)]
  public static extern int ToUnicodeEx(uint vk, uint scan, byte[] state, StringBuilder text, int size, uint flags, IntPtr layout);
}
'@
$Count = [BaganNativeTest]::GetKeyboardLayoutList(0, $null)
$Before = New-Object IntPtr[] $Count
$null = [BaganNativeTest]::GetKeyboardLayoutList($Count, $Before)
# KLF_NOTELLSHELL, without KLF_ACTIVATE or KLF_REPLACELANG.
$Handle = [BaganNativeTest]::LoadKeyboardLayoutW($Klid, 0x80)
if ($Handle -eq [IntPtr]::Zero) { throw "LoadKeyboardLayout failed for $Klid." }
$VkNames = @{ OEM_MINUS=189; OEM_PLUS=187; OEM_4=219; OEM_6=221; OEM_1=186;
    OEM_7=222; OEM_3=192; OEM_5=220; OEM_COMMA=188; OEM_PERIOD=190; OEM_2=191 }
$Results = New-Object System.Collections.Generic.List[object]
function Check-Output([int]$Vk, [int]$Scan, [bool]$Shift, [bool]$Caps, [bool]$Ctrl, [string]$Expected, [string]$Label) {
    $State = New-Object byte[] 256
    if ($Shift) { $State[0x10] = 0x80; $State[0xa0] = 0x80 }
    if ($Caps) { $State[0x14] = 1 }
    if ($Ctrl) { $State[0x11] = 0x80; $State[0xa2] = 0x80 }
    $Text = New-Object System.Text.StringBuilder 16
    # Flag 4: do not change keyboard state (Windows 10 1607 and later).
    $Length = [BaganNativeTest]::ToUnicodeEx($Vk, $Scan, $State, $Text, 16, 4, $Handle)
    $Actual = $Text.ToString()
    $Passed = $Length -eq $Expected.Length -and $Actual -ceq $Expected
    $Results.Add([pscustomobject]@{ test=$Label; pass=$Passed; expected=$Expected; actual=$Actual; returnValue=$Length })
}
try {
    foreach ($Row in $Mapping.rows) {
        $Vk = if ($Row.virtualKey.Length -eq 1) { [int][char]$Row.virtualKey } else { $VkNames[$Row.virtualKey] }
        $Scan = [Convert]::ToInt32($Row.scanCode, 16)
        foreach ($Caps in @($false, $true)) {
            Check-Output $Vk $Scan $false $Caps $false $Row.normal "$($Row.keymanKey) normal Caps=$Caps"
            Check-Output $Vk $Scan $true $Caps $false $Row.shift "$($Row.keymanKey) Shift Caps=$Caps"
        }
        if ($Row.ctrl -ne '-1') {
            $Expected = [string][char][Convert]::ToInt32($Row.ctrl, 16)
            Check-Output $Vk $Scan $false $false $true $Expected "$($Row.keymanKey) Ctrl"
        }
    }
    Check-Output 0x20 0x39 $false $false $false ' ' 'Space'
    Check-Output 0x09 0x0f $false $false $false "`t" 'Tab'
    Check-Output 0x0d 0x1c $false $false $false "`r" 'Enter'
    Check-Output 0x08 0x0e $false $false $false ([string][char]8) 'Backspace'
    $Report = [ordered]@{
        klid=$Klid; windowsVersion=[Environment]::OSVersion.VersionString
        scope='ToUnicodeEx table checks only; application rendering/editing/switching acceptance still required'
        passed=@($Results | Where-Object { $_.pass }).Count
        failed=@($Results | Where-Object { -not $_.pass }).Count
        results=@($Results.ToArray())
    }
    $ReportPath = Join-Path $Root 'windows-native-api-results.json'
    $Report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
    Write-Host "Native table checks: $($Report.passed) passed, $($Report.failed) failed. Report: $ReportPath"
    if ($Report.failed -ne 0) { throw 'Installed layout differs from generated source. Do not release.' }
}
finally {
    if ($Before -notcontains $Handle) { $null = [BaganNativeTest]::UnloadKeyboardLayout($Handle) }
}
