# Verification report — 2026-11-10

Release: 0.3.0. Shipping package: `dist/bagan_full.kmp`.

`npm run verify` passed: both Keyman kmc 18.0.255 builds succeeded with
compiler warnings treated as errors; all 14 automated tests passed.
Node emitted a localStorage ExperimentalWarning from the compiler tooling;
there were no Keyman compiler warnings in the final build.

Verified on the macOS build host:

- 47 normal and 47 Shift rules; no duplicate keys or invalid scalar outputs.
- Every original assignment retained except the double-backslash correction;
  the normal apostrophe, formerly implicit, is now explicit.
- Decoded KMX rules match all source mappings and version 0.3.0.
- Nine representative logical-order sequences have the expected code points,
  including medials, vowels, asat, virama stacks and kinzi. These checks read
  compiled rules; they do not execute the Keyman runtime or validate spelling.
- KMP manifest identifies keyboard `bagan_full`, language `my`, version 0.3.0;
  its embedded keyboard bytes match the tested KMX. Help and key map included.
- Retained reference files and existing backup/binaries match the preservation
  hashes in `tests/preserved-sha256.json`.

Not verified: official Bagan equivalence, reference provenance, or execution
on any Keyman runtime. No macOS typing test or Windows 11 runtime test was run.

Windows 11 acceptance work remains: installation and uninstall/reinstall,
activation and switching, Caps Lock/modifier behavior, rendering with Myanmar
Unicode fonts, code-point checks in Notepad/Word/browser fields, editing and
shortcuts, non-US layouts, and persistence after restart. See README.md for
specific sequences and expected results. The package is built for installation
with Keyman, but successful Windows installation is not yet demonstrated.

Intentional limits: logical-order direct input only; no visual-order correction,
Zawgyi conversion, automatic mark sorting, Myanmar-digit shortcuts, or inferred
Bagan-specific behavior. Digits remain ASCII and Shift+7 remains ရ.
