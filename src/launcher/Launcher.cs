using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;

static class ClassicPlayerLauncher {
    [STAThread]
    static void Main(string[] args) {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string mpvPath = Path.Combine(dir, "mpv.exe");
        if (!File.Exists(mpvPath)) {
            mpvPath = Path.Combine(dir, "bin", "mpv.exe");
        }
        if (!File.Exists(mpvPath)) {
            MessageBox.Show(
                "Could not find mpv.exe in: " + dir,
                "Classic Player Error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return;
        }

        StringBuilder sb = new StringBuilder();
        foreach (string arg in args) {
            sb.Append("\"").Append(arg.Replace("\"", "\\\"")).Append("\" ");
        }

        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = mpvPath;
        psi.Arguments = sb.ToString().Trim();
        psi.WorkingDirectory = dir;
        psi.UseShellExecute = false;

        try {
            Process.Start(psi);
        } catch (Exception ex) {
            MessageBox.Show(
                "Failed to start Classic Player:\n" + ex.Message,
                "Classic Player Error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }
}
