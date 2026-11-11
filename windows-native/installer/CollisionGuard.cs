// Read-only MSI launch guard. Never allocates/replaces a system keyboard ID.
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32;
using Microsoft.Deployment.WindowsInstaller;

public class CollisionGuard
{
    [DllImport("kernel32.dll")]
    private static extern void GetNativeSystemInfo(IntPtr info);

    [CustomAction]
    public static ActionResult CheckNativeTarget(Session session)
    {
        try
        {
            if (!String.IsNullOrEmpty(session["Installed"])) return ActionResult.Success;
            IntPtr info = Marshal.AllocHGlobal(64);
            try {
                GetNativeSystemInfo(info);
                if (Marshal.ReadInt16(info) != 9) throw new Exception("An AMD64/x64 Windows computer is required; ARM64 is not supported.");
            } finally { Marshal.FreeHGlobal(info); }

            using (RegistryKey machine = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64))
            using (RegistryKey layouts = machine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\Keyboard Layouts"))
            using (RegistryKey ownerKey = machine.OpenSubKey(@"SOFTWARE\BaganNativeProject"))
            {
                bool owns = ownerKey != null && String.Equals(Convert.ToString(ownerKey.GetValue("Owner")), "E43C9D49-7D44-43D0-ADE6-719AE98458DC", StringComparison.OrdinalIgnoreCase);
                foreach (string name in layouts.GetSubKeyNames())
                using (RegistryKey key = layouts.OpenSubKey(name)) {
                    string file = Convert.ToString(key.GetValue("Layout File"));
                    string id = Convert.ToString(key.GetValue("Layout Id"));
                    bool collision = String.Equals(name, "a7b90409", StringComparison.OrdinalIgnoreCase)
                        || String.Equals(id, "0b79", StringComparison.OrdinalIgnoreCase)
                        || String.Equals(Path.GetFileName(file), "bgmyuni.dll", StringComparison.OrdinalIgnoreCase);
                    if (collision && !(owns && String.Equals(name, "a7b90409", StringComparison.OrdinalIgnoreCase)
                        && String.Equals(file, "bgmyuni.dll", StringComparison.OrdinalIgnoreCase)))
                        throw new Exception("A keyboard identifier or DLL name is already in use. No existing keyboard will be replaced.");
                }
                string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
                foreach (string folder in new string[] { "System32", "SysWOW64" })
                    if (!owns && File.Exists(Path.Combine(windows, folder, "bgmyuni.dll")))
                        throw new Exception("bgmyuni.dll already exists and is not owned by this installer. Installation stopped.");
            }
            return ActionResult.Success;
        }
        catch (Exception error)
        {
            session.Log("Bagan native preflight: " + error.ToString());
            using (Record message = new Record(1)) {
                message[0] = error.Message;
                session.Message(InstallMessage.Error, message);
            }
            return ActionResult.Failure;
        }
    }
}
