# Native MSI installation

This CI package uses **Bagan-Myanmar-Native-x64.msi**, authored with WiX 3.
It does not contain MSKLC's setup.exe. Follow START-HERE.txt for installation,
switching and removal. The older INSTALL-WINDOWS.md describes a different,
manual MSKLC GUI package and should not be used to identify this MSI's files.

The MSI installs its own `bgmyuni.dll` in System32 and the compiler's WOW64
build in SysWOW64, plus offline help under Program Files. It registers only
its own keyboard `a7b90409` / layout ID `0b79`, under English-US. A read-only
installer preflight rejects identifier, layout-ID and DLL-name conflicts with
other layouts. It does not replace a built-in Windows keyboard or change
your preferred input profile or Windows display language.

No code-signing certificate is provided. Installer security prompts must be
reviewed; do not turn off security protections. The MSI is self-contained,
including its cabinet payload and collision-check action. A successful CI
build should contain BUILD-VERIFICATION.json and SHA256SUMS.txt showing what
was actually checked. An artifact without those results is not a verified
handoff. Signing, manual Windows 11 acceptance and official Bagan equivalence
are not established by this package.

The artifact is private to repository-authorized users and expires according
to Actions retention settings. Keep the MSI for repair/uninstall. Never
distribute the downloaded Microsoft compiler or installer as part of it.
