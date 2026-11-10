namespace ProjectKnight.Launcher;

internal static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();

        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        AppDomain.CurrentDomain.UnhandledException += (s, e) =>
        {
            var ex = e.ExceptionObject as Exception;
            MessageBox.Show(
                $"처리되지 않은 오류가 발생했습니다:\n{ex?.Message}\n\n{ex?.StackTrace}",
                "시스템 오류",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        };

        Application.Run(new MainForm());
    }
}
