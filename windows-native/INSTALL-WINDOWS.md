# Install Bagan Style Myanmar Native on Windows 11

These steps are for a real installer ZIP made by the builder. The current
source project has not yet produced that ZIP or been tested on Windows 11.
The keyboard is unofficial; it is not proven to match Bagan Keyboard exactly.

## Install once

1. Make sure your computer uses **x64**, not ARM64. To check, open **Start →
   Settings → System → About** and look at **System type**. This package is
   intended for an x64-based processor.
2. Save the `Bagan-Myanmar-Native-x64.zip` supplied by the builder. Right-click
   it and choose **Extract All**, then **Extract**.
3. Open the extracted folder. Double-click **setup.exe**. Keep all the files
   beside it; do not move setup.exe out of that folder.
4. Check that the installer is for **Bagan Style Myanmar Native (unofficial)**.
   If Windows asks to allow the installer to make changes, review the source
   and package name and approve it if this is the package you intended to
   install. Administrator approval may be needed. Wait for completion.
5. Restart if asked. Open Notepad to try typing.

This installs an additional keyboard. You do not need Keyman, MSKLC or a
background keyboard app to use the installed native layout. It does not
replace the built-in Windows English or Myanmar keyboards. The builder tools
are only needed by the person producing the installer.

## Find and switch to the keyboard

1. Hold the **Windows logo key** and tap **Space** to see your keyboards.
   Choose **Bagan Style Myanmar Native (unofficial)**. You can also click the
   language/input indicator near the clock and choose it there.
2. If it is missing, open **Settings → Time & language → Language & region**.
   Next to **English (United States)** choose **… → Language options**.
   Under **Keyboards**, choose **Add a keyboard**, then select the full
   **Bagan Style Myanmar Native (unofficial)** name.
3. The keyboard is registered under English (United States) for this legacy
   build method, even though it types Myanmar. If that language is not listed,
   add English (United States) under Preferred languages first. Keep your
   existing Windows display language; do not choose to change it for this task.
4. To type English again, hold **Windows** and tap **Space**, then select
   **US** or your usual English keyboard. Keep that ordinary keyboard installed.

The indicator may show **ENG** for both layouts. Read the full keyboard name
in the list. Switching and typing behavior still needs confirmation on a
Windows 11 machine before this installer can be described as verified.

## Try it in Notepad

Choose a Myanmar Unicode font such as **Myanmar Text** if available. Press
**U**, then **A**. The expected text is **ကေ**. The vowel appears to the left,
but you type the consonant first. Press **U**, then hold **Shift** and press
**F**, release Shift, then press **U** again: expected **က္က**.

Type in logical Unicode order. F is asat; Shift+F is virama for stacks.
Caps Lock does not choose the Shift symbols: use the Shift key. Digits are
ordinary 0–9; Shift+7 types ရ. The extra ISO key is unassigned. There is no
automatic word correction, reordering or Zawgyi conversion. KEYMAP.md lists
every key and ACCEPTANCE-WINDOWS.md contains more examples.

If boxes or misplaced marks appear, confirm the active keyboard and font,
then record the failing example for the builder. Do not download replacement
system keyboard files or edit the registry to fix it.

## Uninstall

1. Switch back to your usual English keyboard with **Windows + Space**.
   Save your work and close apps where you used the Myanmar keyboard.
2. Go to **Settings → Time & language → Language & region → English (United
   States) → … → Language options**. Under Keyboards, find this exact native
   layout, choose **… → Remove** if available. Keep the ordinary US keyboard.
3. Go to **Settings → Apps → Installed apps**. Find **Bagan Style Myanmar
   Native (unofficial)** (or the builder's `bgmyuni` entry), select **… → Uninstall**,
   and follow its instructions. If it is not listed there, open **Control Panel →
   Programs → Programs and Features**, find the same entry, and choose Uninstall.
   The original setup.exe may also offer Remove when run again.
4. Restart if prompted. Confirm this native layout no longer appears in
   **Windows + Space**. Text you have already typed will remain in your documents.

Removing the layout from the keyboard list alone does not uninstall its
package. Never manually delete DLLs from Windows folders. If uninstall fails,
keep the exact error message and ask the builder for help.
