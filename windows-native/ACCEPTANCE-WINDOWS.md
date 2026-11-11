# Windows 11 x64 acceptance record

Status: **NOT RUN**. Source validation on macOS is not Windows acceptance.
Complete every result below as PASS / FAIL / NOT TESTED, with notes. Do not
infer success from an installer exit code or from a font displaying sample text.

Record tester/date, Windows edition/build (run `winver`), processor architecture,
physical keyboard type (ANSI/ISO and legends), installed fonts, MSKLC version,
source/installer SHA-256, app versions and installer log or exact messages.

## Installation and removal

| Check | Expected | Result |
| --- | --- | --- |
| Extract ZIP and double-click setup.exe | Installs own layout without Keyman or builder tools on target | NOT RUN |
| Administrator and signing prompts | Record exact prompts and outcome | NOT RUN |
| Existing US/Myanmar layouts | Names and behavior unchanged | NOT RUN |
| Language options | New layout visible under English (United States) | NOT RUN |
| 64-bit and 32-bit apps | Both can type using their appropriate layout DLL | NOT RUN |
| Restart and sign back in | Layout remains selectable, normal English still works | NOT RUN |
| Remove input profile, uninstall package, restart | Own layout disappears; existing keyboards and documents remain | NOT RUN |
| Reinstall same package | No duplicate entries or stale DLL failure | NOT RUN |

## Native API checks

After installation run `scripts\Test-InstalledLayout.ps1` from Windows
PowerShell according to the machine's existing execution policy. Expect
221 passing table checks and no failures; retain the resulting
`windows-native-api-results.json`. It checks both Caps Lock states and
native `ToUnicodeEx` outputs. A passing result does not verify GUI typing.

## Typing and Unicode

For each sequence, select the native layout and type actual keys in **Notepad**,
a **browser text field**, and **Word if available**. S- means Shift held for
that key only. Compare appearance with a Unicode Myanmar font, then save or
copy the text and compare code points. Marks shown alone can display with a
dotted circle supplied by the font; that circle must not be inserted into text.

| Physical keys | Expected code points | Text | Result |
| --- | --- | --- | --- |
| U A | 1000 1031 | ကေ | NOT RUN |
| U D K | 1000 102D 102F | ကို | NOT RUN |
| U S S-G S-S A M | 1000 103B 103D 103E 1031 102C | ကျွှော | NOT RUN |
| U J A M | 1000 103C 1031 102C | ကြော | NOT RUN |
| U S-F U | 1000 1039 1000 | က္က | NOT RUN |
| I F S-F U | 1004 103A 1039 1000 | င်္က | NOT RUN |
| O I F S-F B A M | 101E 1004 103A 1039 1018 1031 102C | သင်္ဘော | NOT RUN |
| U H F | 1000 1037 103A | က့် | NOT RUN |
| C G | 1001 102B | ခါ | NOT RUN |
| U S-H Semicolon | 1000 1036 1038 | ကံး | NOT RUN |
| Backslash, Quote | 005C, 0027 each once | backslash, apostrophe | NOT RUN |
| Comma, Period | 104A, 104B | ၊ ။ | NOT RUN |
| 0–9, S-7 | 0030–0039, 101B | ASCII digits, ရ | NOT RUN |

Some rows are artificial encoding checks, not natural-word spelling. Also
test **every row of KEYMAP.md**, including rare letters and independent vowels.
With Caps Lock on, normal outputs must stay normal and Shift must still
produce Shift outputs. Check key repeats and Shift release for stuck modifiers.

To inspect a UTF-8 Notepad file without changing its contents, switch to English
and run this in PowerShell, changing the path:

```powershell
$text = [IO.File]::ReadAllText('C:\path\sample.txt', [Text.Encoding]::UTF8)
($text.ToCharArray() | ForEach-Object { 'U+{0:X4}' -f [int]$_ }) -join ' '
```

This layout emits BMP characters, so this simple code-unit display is sufficient.
Account for spaces/newlines you intentionally typed. Do not normalize the file
before comparison; that would hide the actual emitted sequence.

## Editing, controls and switching

| Check | Expected / observation to record | Result |
| --- | --- | --- |
| Space, Tab, Enter, Shift+Tab | Normal application navigation/text behavior; no Myanmar mark inserted | NOT RUN |
| Backspace/Delete around base, medials, vowel, kinzi and stack | Record code-point/cluster deletion in each app; no stuck composition | NOT RUN |
| Arrow/Home/End navigation and insertion | Cursor movement, insertion and app behavior recorded | NOT RUN |
| Selection replacement and undo/redo | Correct text replaced/restored | NOT RUN |
| Ctrl+A/C/V/X/Z/Y | Select/copy/paste/cut/undo/redo work; no unwanted Myanmar characters | NOT RUN |
| Ctrl+[ / Ctrl+backslash / Ctrl+] | Standard control outputs where the app uses them | NOT RUN |
| Alt menus, Alt+Tab, Windows shortcuts | No unwanted Myanmar output; expected app/system action | NOT RUN |
| Right Alt / Ctrl+Alt | No Myanmar AltGr layer; record shortcut and no-input behavior | NOT RUN |
| Windows+Space and taskbar selector | Native ↔ usual English switching; subsequent keys match selected layout | NOT RUN |
| Switch apps/windows, then back | Active keyboard policy matches Windows settings | NOT RUN |
| Numpad with Num Lock on/off, Shift, decimal | Standard Windows/app behavior; ASCII numeric input and period decimal | NOT RUN |
| ISO extra key | No assigned text; remaining US-position mappings match | NOT RUN |
| Copy/paste between apps and reopen UTF-8 file | Code points preserved, no Zawgyi conversion | NOT RUN |
| Font comparison | Same code points; legibility recorded for Myanmar Text and another Unicode font if available | NOT RUN |

This static layout does not implement grapheme-aware Backspace, automatic
mark sorting, visual-order typing, prediction or custom composition UI.
Deletion granularity and shaping belong to Windows and each application.
If an app fails, record the exact keys, actual code points, expected code points
and screenshot/font. Do not describe the layout as Windows-verified until the
required checks are completed and material failures resolved.
