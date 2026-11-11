# Audit and verification report

Date: 2026-11-10. Build host: macOS (Darwin). Native build status:
**NOT BUILT**. Windows installation/runtime status: **NOT TESTED**.

## Existing project audit

- Re-ran `npm test` without rebuilding or regenerating the Keyman project:
  **14 passed, 0 failed**. These inspect source, decoded KMX output and KMP
  contents; they do not execute Keyman on Windows.
- Current `bagan-full.kmn` declares keyboard version 0.3.0 and has **94 explicit
  rules**, not 93: 47 normal and 47 Shift. The historical additional mapping
  is the explicit normal apostrophe. The current backslash emits one U+005C.
- Every rule is context-free and emits exactly one BMP Unicode scalar. Normal
  A–Z coverage is complete. No current rule needs a Keyman composition engine.
- The Myanmar vowel/medial/mark outputs needed by the existing layout are
  present, including separate asat (103A) and virama (1039). They are copied
  without normalization or substitution. This is mapping coverage, not a
  claim that every Myanmar character is directly accessible.
- ASCII digits, Shift+7 = U+101B ရ, Myanmar punctuation on comma/period,
  rare letters and independent vowels are retained. No missing ampersand or
  Myanmar-digit shortcut has been invented. Switch to a normal keyboard for
  characters not available in this layout.
- `luna-reference.keylayout` remains a local macOS reference of unverified
  provenance. It is not evidence of official Bagan behavior. The native
  conversion uses the current shipping KMN, not a reinterpretation of Luna.
- All pre-existing project files outside node_modules/.git were hashed before
  native implementation. Preservation checks compare every recorded file,
  including sources, backups, reference binaries, Keyman package, source JSON,
  root scripts/tests, package manifests and documentation.

## Native source and policy

The generated source `source/bgmyuni.klc` uses a new short layout ID **bgmyuni**.
It maps PC/AT Set 1 scan positions to standard Windows US virtual-key codes,
then supplies normal, Shift and Ctrl character columns. There are no dead
keys, ligatures, AltGr assignments, DLL hooks or background processes.

All **94/94 source character mappings** are covered. Six additional table rows
explicitly specify Backspace, Tab, Return, Space, numpad decimal and an
unassigned ISO extra key. Num Lock navigation/function keys use the standard
native builder/Windows behavior and require Windows testing. Ctrl+A–Z and
Ctrl+[ / backslash / ] have explicit standard control-character values; app
shortcuts, Shift+Ctrl and Alt behavior still need acceptance testing.

Caps attributes are zero for every source key: Caps Lock does not select
the Myanmar Shift layer. This is an explicit native policy, not a claim of
Windows-tested parity with the Keyman runtime's Caps Lock behavior.

The profile locale is English-US (0409), chosen for the old MSKLC locale
support. It types Myanmar text but may be labeled ENG and treated as English
by spellchecking. This is documented for the user. It does not replace the
system English layout or use an existing system layout's DLL filename.

## Static validation results

Command from project root:

```sh
python3 -B windows-native/scripts/generate.py
python3 -B -m unittest discover -s windows-native/tests -v
```

**13 tests passed, 0 failed**, covering:

1. Pre-existing file preservation against captured SHA-256 hashes.
2. Complete generated mapping equality with KMN and existing Keyman map JSON.
3. UTF-16LE BOM/CRLF, metadata, table states and absence of dead-key rules.
4. Unique scan codes and independent PC/AT A–Z position fixtures.
5. OEM punctuation and digit scan/VK positions.
6. Valid BMP scalar outputs and explicit Caps Lock policy.
7. Ctrl control outputs and Windows editing-key rows.
8. Backslash/apostrophe, ASCII digits, Shift+7 and Myanmar punctuation.
9. Existing Myanmar combining-mark inventory.
10. Nine exact logical-order sequences read back from the generated KLC.
11. Rejection of contexts, unsupported modifiers, multi-output rules, invalid
    surrogate output and unknown source stores.
12. Source/generated file hash consistency.
13. Byte-identical regeneration of generated files.

The independent KLC reader validates the subset this generator emits; it is
not Microsoft's compiler. These results do not establish that MSKLC will
accept the file, that its compiler produces correct tables, or that Windows
will install/load/render them. Those are separate unrun checks.

## Build and installer result

- Available host compiler: Apple clang. No usable MSKLC, Windows runtime,
  MSBuild/.NET Windows build environment, Wine or MinGW cross-compiler was
  found in the inspected environment. No software was installed.
- Selected path: Windows MSKLC 1.4 GUI **Build DLL and Setup Package** with
  preparation and package-validation scripts. No undocumented command-line
  MSI builder is assumed. This is a reproducible source/procedure project,
  not an unattended installer pipeline or a bit-for-bit reproducibility claim.
- Required future builder dependencies: Windows x64, approved MSKLC 1.4 and
  the .NET Framework runtime it requires. Windows PowerShell 5.1 supplies the
  included inspection/check scripts. See BUILD.md for compatibility limits.
- **Installer output path: none.** No EXE, MSI or native DLL was built. Intended
  paths after a successful future Windows run are documented separately and
  are not presented as existing outputs.
- Windows PowerShell scripts, C# interop code, PE/MSI inspections and 221 native
  API checks have been authored but not executed. No native test results JSON
  has been fabricated.
- No registry changes, software installations or execution of Windows binaries
  took place on the Mac. No Windows system keyboards were replaced or modified.

## Static native layout limits

The present KMN's direct character output can be represented. Context-sensitive
Myanmar composition is a different capability: this static layout cannot
inspect surrounding document text and reorder previously typed medials/vowels,
convert Zawgyi, choose AA variants automatically or validate syllable spelling.
There is no prediction, candidate window, custom composition UI or
grapheme-aware deletion logic. A native layout can support fixed dead-key or
ligature sequences, but none are inferred from an unverified Bagan reference.

Users must type Unicode logical order, including consonant before E vowel
and NGA-ASAT-VIRAMA before the kinzi-bearing base. Rendering, caret movement,
deletion granularity and application shortcuts belong to Windows/apps/fonts.
The source emits individual characters, so isolated or wrongly ordered marks
remain possible; no hidden mark correction is claimed.

## Remaining Windows 11 acceptance

Run MSKLC validation/build, inspect the actual x64 package, install it, run the
221 native API checks, then complete ACCEPTANCE-WINDOWS.md: all key mappings,
Caps/Shift/Ctrl/Alt and repeats; logical Unicode sequences; Notepad/browser/Word
rendering; editing, selection and clipboard; ANSI/ISO and numpad behavior;
keyboard switching and persistence; uninstall and reinstall. Confirm absence
of conflicts with other installed layouts. Record actual failures and resolve
material issues before handing the installer to a beginner as verified.
