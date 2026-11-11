# Build on Windows — for the person preparing the installer

Current status: source project ready; native compilation and Windows scripts
have not been executed. No Windows installer exists yet.

## Dependencies

- A Windows x64 machine or VM; use a Windows 11 test machine for final acceptance.
  macOS Apple clang alone cannot run this selected build and packaging method.
- Microsoft Keyboard Layout Creator **1.4**, from the
  [official Microsoft download](https://www.microsoft.com/en-us/download/details.aspx?id=102134).
  This includes its keyboard compiler and setup-package generator. A separate
  Visual Studio/WDK installation is not required for the selected MSKLC workflow.
- The .NET Framework runtime required by that installed MSKLC build. If
  Windows asks for an older .NET component, review and approve that installation
  separately; these scripts do not enable it or install anything.
- Windows PowerShell 5.1, included with Windows, for preparation, package
  inspection and acceptance checks. No Node.js, Python, Keyman or paid tool is
  required on the builder if using the already generated KLC.

Installing MSKLC or a runtime is a separate approved setup action. Nothing in
this project downloads either. MSKLC's official page does not list Windows 11
as supported. Try the builder on your Windows machine and retain its logs;
if it fails, build on a supported Windows host and test the resulting package
on Windows 11 x64. Do not treat tool availability as a completed build.

## Reproducible source preparation

1. Copy the entire `windows-native` folder to Windows. The checked-in KLC is
   ready to build. Only regeneration requires the parent Keyman source/Python.
2. Use an empty, short ASCII workspace with no spaces, for example
   `C:\BaganNativeBuild`. Keep a new empty workspace for every build.
3. Open Windows PowerShell in `windows-native`. Follow your machine's script
   execution policy; these scripts do not change it or bypass it. Run:

   ```powershell
   .\scripts\Build-Windows.ps1 -WorkDirectory C:\BaganNativeBuild
   ```

   If MSKLC is installed elsewhere, also pass `-MsklcPath 'full path to MSKLC.exe'`.
   The script verifies generated-file SHA-256 hashes, refuses a nonempty
   workspace, copies the KLC there and opens the existing MSKLC executable.
   It does not invoke an installer, alter the registry or modify system DLLs.

## Compile using MSKLC's GUI

The MSKLC GUI is an explicit step; no undocumented unattended MSI-generation
switch is assumed by these scripts.

1. In MSKLC choose **File → Load Source File**. Select
   `C:\BaganNativeBuild\bgmyuni.klc`.
2. In **Project → Properties**, retain the short name **bgmyuni**, description
   **Bagan Style Myanmar Native (unofficial)**, and language **English (United
   States)**. Set the working/output directory inside the new workspace if
   the tool offers that field. Do not load or replace an existing system layout.
3. Choose **Project → Validate Layout**. Save its log. Unicode characters absent
   from the legacy English code page may generate warnings; that is distinct
   from errors that prevent a Unicode keyboard from compiling. Missing states,
   invalid characters, duplicate scan/VK assignments or dropped characters
   must be investigated. Never suppress all diagnostics and assume success.
4. Choose **Project → Build DLL and Setup Package**. Save the build log. Require
   a successful build and confirm the generated package folder contains
   `setup.exe`, its MSI files and architecture folders with `bgmyuni.dll`.
   Do not distribute the `.klc` or a lone DLL as an installer.
5. Record the actual output folder shown by MSKLC. It normally has a `bgmyuni`
   name; its location is determined by the builder. The scripts do not invent
   a success result or assume that folder exists.

## Check and assemble the beginner handoff

Pass the actual MSKLC-generated package directory, for example:

```powershell
.\scripts\Package-Windows.ps1 -PackageDirectory C:\BaganNativeBuild\bgmyuni
```

The example path is a placeholder until the GUI actually builds that folder.
The script reads PE headers and MSI metadata without executing generated
binaries. It requires:

- A real PE `setup.exe` and only `bgmyuni.dll` layout DLL names.
- An AMD64 DLL and an x86 DLL for 32-bit applications on x64 Windows.
- Exactly one x64 MSI beside setup.exe whose File table lists `bgmyuni.dll`.

It copies the complete setup tree, offline user instructions, key map, acceptance
checklist, KLC and mapping metadata into a new release folder. It refuses to
overwrite an existing release. Default intended outputs, **only after a successful
Windows build and packaging run**, are:

```text
windows-native\release\Bagan-Myanmar-Native-x64.zip
windows-native\release\Bagan-Myanmar-Native-x64\setup.exe
```

These outputs do not exist in the current macOS result. Do not rename a text
file to EXE/MSI. MSKLC's bootstrapper may be an x86 executable; the selected
x64 MSI and AMD64 keyboard DLL are what make this an x64 installation.
Keep sibling files and architecture folders together. Do not redistribute
MSKLC, its compiler, runtimes, or the Keyman package as part of this native setup.

The package checks establish structure and architecture, not executable
trust, DLL-to-source equivalence or successful installation. They have not
been run on this Mac. Record any signing/installer prompts during testing;
no code-signing certificate is provided or purchased by this project.

## Acceptance before release

Install on a Windows 11 x64 test machine using INSTALL-WINDOWS.md. Then run:

```powershell
.\scripts\Test-InstalledLayout.ps1
```

This reads only the registration for `bgmyuni.dll`, loads its native layout
tables for the test process without activating/replacing other layouts, and
calls `ToUnicodeEx`. It checks all 94 outputs with Caps Lock off/on, 29 Ctrl
outputs and four editing keys: **221 API checks expected**. It writes
`windows-native-api-results.json` with actual results; no such runtime result
is supplied here. It does not send keys to applications or verify rendering.

Complete ACCEPTANCE-WINDOWS.md in Notepad, a browser field and Word if
available. Record OS version, architecture, tool versions, logs and failures.
Archive the source hashes, build log, generated package and acceptance results
together. MSKLC/MSI metadata may include timestamps/GUIDs; this is reproducible
source and procedure, not a claim of byte-identical installers.

If an installation already using `bgmyuni.dll` belongs to another project,
stop and choose a new unique layout ID in this project before building. Do
not overwrite that installation or any Windows system keyboard.
