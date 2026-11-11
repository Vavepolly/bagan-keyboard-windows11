# Bagan Style Myanmar Windows — unofficial, version 0.3.0

Install `dist/bagan_full.kmp` with Keyman for Windows. This is a reference-derived
Myanmar Unicode layout, not a verified reproduction of Bagan Keyboard. The local
`luna-reference.keylayout` is a macOS reference of unverified provenance.

## Windows 11 installation

1. Install Keyman for Windows from https://keyman.com/windows and start it.
2. Copy `dist/bagan_full.kmp` to Windows, double-click it, and review the package
   name “Bagan Style Myanmar Windows (unofficial)” before choosing Install.
3. Open Notepad. Select “Bagan Style Myanmar Windows” from the Keyman tray menu.
   Use a Myanmar Unicode font such as Myanmar Text for the smoke tests below.
4. Use the Keyman tray menu to switch keyboards. Windows+Space can switch the
   registered Windows input profiles; confirm the active profile before typing.
   Select your English input profile to return to English.

The package needs Keyman; it is not a standalone Windows keyboard DLL or EXE.
It contains no bundled Keyman runtime or fonts. No paid service is needed.

## Typing

See KEYMAP.md for every physical US key position, output and code point.
There are 47 normal and 47 Shift assignments. Digits are ASCII, as in the
existing source. Shift+7 is ရ, not an ampersand. This is intentional retention
of the existing mapping. Other physical keyboard layouts need testing.

Type in logical Unicode order: base consonant, medials, vowels, finals/tones
in their appropriate syllable order. The keyboard emits characters directly;
it does not reorder, normalize, validate syllables, convert Zawgyi, or insert
dotted circles. A leading mark can therefore produce malformed text. In
particular, type the consonant BEFORE A (U+1031 ေ), although the vowel renders
to its left. Do not type in visual left-to-right order.

F emits asat U+103A; Shift+F emits virama U+1039. They are not interchangeable.
For stacking, enter consonant, Shift+F, consonant. For kinzi, enter I, F,
Shift+F, then the base consonant. Medials S/J/Shift+G/Shift+S emit
U+103B/U+103C/U+103D/U+103E. Select the correct AA vowel yourself:
G = U+102B, M = U+102C. Unicode normalization alone does not repair arbitrary
Myanmar input order.

## Windows smoke tests — required before calling this Windows-verified

Use these physical keys in Notepad, then repeat in Word (if available) and a
browser text field. Compare saved text code points as well as its appearance.
S- means hold Shift for that key only.

| Keys | Expected code points | Text |
| --- | --- | --- |
| U A | 1000 1031 | ကေ |
| U S S-G S-S A M | 1000 103B 103D 103E 1031 102C | ကျွှော |
| U D K | 1000 102D 102F | ကို |
| U S-F U | 1000 1039 1000 | က္က |
| I F S-F U | 1004 103A 1039 1000 | င်္က |
| O I F S-F B A M | 101E 1004 103A 1039 1018 1031 102C | သင်္ဘော |
| U H F | 1000 1037 103A | က့် |
| Backslash | 005C (once) | backslash |
| Quote | 0027 (once) | apostrophe |

The artificial all-medials sequence tests encoding, not natural-word spelling.
Also test Shift release, Caps Lock, held/repeated keys, spaces, Enter, Tab,
Backspace across combining marks and stacks, Delete, cursor insertion,
selection replacement, copy/paste, Ctrl+C/V/Z, Alt shortcuts, switching to
English and back, restart/sign-in persistence, and uninstall/reinstall.
Editing and shortcut behavior is delegated to Keyman and the host application.
No runtime results for these checks have been obtained on Windows 11 here.

## Uninstall

Switch to English. Open Keyman Configuration from its tray icon, locate this
keyboard/package under installed keyboards, choose Uninstall/Remove and confirm
the package name. Close and reopen affected applications if it remains listed.
To remove Keyman itself, use Windows Settings → Apps → Installed apps → Keyman
→ Uninstall; this can affect your other Keyman keyboards. Removing the keyboard
does not convert or remove text already typed.

## Rebuild and verification

With Node.js 20 or later, run `npm ci`, then `npm run verify`.
The pinned compiler is Keyman kmc 18.0.255. This generates the key map/JSON,
compiles the KMX and KMP with warnings treated as errors, tests source rules,
decodes the compiled KMX to verify outputs and logical-order sequences, and
checks the package's manifest and embedded keyboard bytes. These are binary
and source checks, not execution of the Windows Keyman engine.

Only `bagan-full.kmn` is the shipping source; `bagan.kmn`, the Luna files,
their old compiled binaries, and `bagan-full.backup.kmn` are retained references.
The root `bagan-full.kmx` is an older build; use only artifacts in `dist/`.
The package includes offline installation help and the key map. No license
grant is asserted for reference material whose provenance is unknown.

## Audit and limitations

- Fixed the real double-backslash output: Keyman quoted strings do not use
  JavaScript-style backslash escaping. Output is now explicit U+005C.
- Made the previously implicit normal apostrophe explicit as U+0027. The other
  original assignments are retained; no official Bagan mapping was inferred.
- Replaced the empty, outdated JSON with a generated map; added a versioned
  Burmese-language package, reproducible build, regression tests and help.
- No Unicode code-point defect was found in the existing Myanmar single-key
  mappings. The source had no contextual rules, so visual-order typing was
  never supported. Logical-order input is the explicit supported contract.
- Official Bagan equivalence, macOS reference provenance, Windows installation,
  input behavior, font rendering, editing, Caps Lock and non-US host layouts
  remain unverified. Compilation on macOS proves none of those runtime claims.

Sources: [Unicode Myanmar FAQ](https://www.unicode.org/faq/myanmar.html),
[Unicode 17 chapter 16](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-16/),
[Keyman Windows help](https://help.keyman.com/products/windows/current-version/basic/).
