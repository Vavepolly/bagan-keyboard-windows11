# Bagan Style Myanmar Native — unofficial

This separate project converts the current `../bagan-full.kmn` into an
MSKLC-compatible Windows keyboard layout. An installed native keyboard DLL is
loaded by Windows; Keyman, a tray utility, and a background keyboard app are
not needed for typing. The installer has **not been built or tested here**.
No EXE, MSI or DLL is being supplied as a finished product.

The current source has **94 mappings: 47 normal and 47 Shift**, rather than
the historical 93. The extra rule makes the normal apostrophe explicit.
All 94 are reproduced without changing the Keyman sources or packages.
`source/bgmyuni.klc` is the generated UTF-16LE source, not an installer.

Start here:

- Builder: [BUILD.md](BUILD.md). Build the DLL and setup package on Windows,
  then validate and package the complete setup folder for the beginner.
- End user: [INSTALL-WINDOWS.md](INSTALL-WINDOWS.md). These steps apply once
  the builder has provided the actual installer ZIP.
- Tester: [ACCEPTANCE-WINDOWS.md](ACCEPTANCE-WINDOWS.md).
- Audit and verification limits: [AUDIT.md](AUDIT.md).
- Every physical mapping: [KEYMAP.md](KEYMAP.md).

Regenerate on a machine with Python 3.9 or later (no third-party Python packages):

```sh
python3 windows-native/scripts/generate.py
python3 -B -m unittest discover -s windows-native/tests -v
```

Run from the project root. These commands write only inside `windows-native`.
To rerun the existing 14 Keyman checks without rebuilding any old artifacts,
run `npm test` at the project root. Do not run `npm run verify` if you want
existing Keyman artifacts left byte-for-byte untouched.

Native policy: physical US ANSI positions, Shift selects the Shift column,
Caps Lock ignored, ASCII number row retained, no AltGr or dead keys. Windows
control and editing rows are provided separately. The ISO extra key has no
character assignment. This is a logical-order Myanmar layout, not a visual-order
input engine, and is not claimed to match official Bagan Keyboard.

The source is associated with **English (United States)** (`0409`) as a
legacy-MSKLC build compatibility choice. This does not change the emitted
Myanmar text. Windows may show ENG for the profile; choose it by the full
keyboard name. Language-specific spellchecking may follow English. No
existing English or Myanmar system layout is replaced.

Build method sources:

- [Microsoft MSKLC download and capabilities](https://www.microsoft.com/en-us/download/details.aspx?id=102134).
  Microsoft documents KLC editing and packaging; its listed supported systems
  do not establish Windows 11 support. Windows 11 build/runtime testing remains
  required. The legacy builder may need a Windows environment it supports.
- [Microsoft keyboard layout sample design](https://github.com/microsoft/Windows-driver-samples/tree/main/input/layout).
  Used to understand native scan/VK/character tables. Its old replacement-based
  installation advice is not used: this project adds its own `bgmyuni` layout.
- [Windows language and keyboard settings](https://support.microsoft.com/en-gb/windows/hardware/input-devices/manage-the-language-and-keyboard-input-layout-settings-in-windows).
- [Unicode Myanmar FAQ](https://www.unicode.org/faq/myanmar.html) and
  [Unicode 17 Myanmar encoding](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-16/).

No software was installed for this task. Windows dependencies are described
for an approved future builder setup; scripts never download or install them.
