# GitHub Actions native MSI build

This automation supplements the preserved manual MSKLC GUI scripts. It uses
the exact existing KLC; it does not modify existing Keyman artifacts, reference
files or backups. The source has 94 explicit normal/Shift mappings.

Pipeline: `.github/workflows/windows-build.yml`, manually dispatched on
`windows-2022`, with read-only repository token permissions and a 20-minute
job limit. No automatic repeated builds or public release are configured.

1. Checkout with LF text bytes; run 13 native source checks. Ignored local
   backups are absent on GitHub, so preservation checks cover the tracked
   originals and any local originals present. Regeneration runs in a temporary
   copy, comparing exact KLC bytes and normalized text. No source is rewritten.
2. Download MSKLC 1.4 only from the HTTPS download URL linked by Microsoft's
   official page. Record size, SHA-256, Authenticode status and certificate
   subject. Require a valid Microsoft signature before extracting or running it.
   Stop on verification failure; do not substitute third-party mirrors.
3. Extract the signed archive with the runner's 7-Zip, then use Windows
   Installer's documented `/a` administrative image operation in RUNNER_TEMP.
   Do not install MSKLC on the Mac, register its GUI or commit its binaries.
   Preserve available EULA/redistribution notices in diagnostics. Those terms
   govern tool use; this project does not provide a legal opinion or relicense
   the Microsoft tools. Review them if organizational approval is needed.
4. Capture the actual `kbdutool -?` help; require both AMD64 and WOW64 support.
   Invoke `-u -w -m` and `-u -w -o` in separate build directories. No guessed
   setup.exe output is assumed. If the compiler is incompatible, stop with
   diagnostics rather than patching its binaries or using undocumented hooks.
5. Build a new, embedded-cabinet **x64 MSI using the runner's WiX 3**. Its only
   runtime payloads are the two generated keyboard DLLs and offline help. Its
   read-only DTF launch guard checks native CPU architecture, registration ID,
   layout ID and DLL-name conflicts. MSI owns and removes its own files/values.
   No built-in keyboard is replaced. No preferred-user layout is silently set.
6. Read MSI tables, verify restricted registry scope and payload names, inspect
   x64/WOW64 PE architectures, administratively extract our MSI and compare
   embedded DLL hashes to compiled DLLs.
7. Install the MSI on the disposable **Windows Server 2022 runner**, run the
   existing native API tests under x64 and 32-bit PowerShell (221 checks each),
   uninstall, and verify pre-existing layout-file registrations are unchanged.
   A `finally` block attempts cleanup after a failing test. This is not a
   Windows 11 desktop installation/rendering/editing acceptance result.
8. Only after all steps pass, upload artifact **Bagan-Myanmar-Native-x64** with
   the MSI, instructions, verification JSON and SHA256SUMS. Upload diagnostic
   logs separately even after failure. Never upload the Microsoft compiler,
   its downloaded installer, or an unverified installer as the successful artifact.

Actual intended installer path on a successful runner:

```text
windows-native/release/Bagan-Myanmar-Native-x64.msi
```

Artifact location: the workflow run's **Artifacts → Bagan-Myanmar-Native-x64**.
This is an Actions artifact, not a GitHub Release. Its default retention is 14
days. The artifact should include BUILD-VERIFICATION.json with the run URL,
commit, actual MSI hash, runner API results and explicit Windows 11 limitation.
No successful build is asserted just because these scripts exist.

Manual push/run if this session cannot reach GitHub (run from project root):

```sh
git add .github/workflows/windows-build.yml windows-native/ci windows-native/installer
git commit -m "Build native Myanmar MSI with verified MSKLC and WiX in Actions"
git push origin main
gh workflow run windows-build.yml --repo Vavepolly/bagan-keyboard-windows11 --ref main
gh run list --repo Vavepolly/bagan-keyboard-windows11 --workflow windows-build.yml --limit 1
```

Use the run ID printed by the last command:

```sh
gh run watch RUN_ID --repo Vavepolly/bagan-keyboard-windows11 --exit-status
gh run view RUN_ID --repo Vavepolly/bagan-keyboard-windows11 --log-failed
gh run download RUN_ID --repo Vavepolly/bagan-keyboard-windows11 --name Bagan-Myanmar-Native-x64 --dir windows-native/release
```

Alternatively use GitHub's Actions tab → Windows Native Keyboard Build →
Run workflow. Do not rerun a failed workflow unchanged. Download diagnostics,
identify a concrete cause, commit a specific fix, then dispatch once.

Potential blockers deliberately stop the build: official download unavailable,
invalid certificate trust, changed archive structure, tool license restriction,
missing runner WiX SDK, compiler errors, MSI validation errors or native API
output mismatch. The modern alternative would be Microsoft's keyboard layout
WDK samples built with Visual Studio/WDK plus this MSI packaging model; it
requires an explicit reviewed source port rather than an untested fallback.

References: [Microsoft MSKLC](https://www.microsoft.com/en-us/download/details.aspx?id=102134),
[Microsoft administrative installation](https://learn.microsoft.com/en-us/windows/win32/msi/administrative-installation),
[runner tool inventory](https://github.com/actions/runner-images/blob/main/images/windows/Windows2022-Readme.md),
[WiX 3 registry authoring](https://docs.firegiant.com/wix3/xsd/wix/registrykey/).
