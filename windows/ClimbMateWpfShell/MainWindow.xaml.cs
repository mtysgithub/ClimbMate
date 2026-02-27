using System.Diagnostics;
using System.Text;
using System.Windows;
using System.IO;

namespace ClimbMateWpfShell;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        RepoPathTextBox.Text = DetectRepoPath() ?? string.Empty;
        DataFileTextBox.Text = @"./data/videos.json";
        AppendLine("ClimbMate Windows GUI Shell ready.");
        AppendLine("Tip: click Init Sample first, then List / Filter.");
    }

    private async void OnInitSampleClick(object sender, RoutedEventArgs e)
    {
        await RunCli($"init-sample --file {Quote(DataFileTextBox.Text)}");
    }

    private async void OnListClick(object sender, RoutedEventArgs e)
    {
        await RunCli($"list --file {Quote(DataFileTextBox.Text)}");
    }

    private async void OnFilterRouteGradeClick(object sender, RoutedEventArgs e)
    {
        var route = (RouteComboBox.SelectedItem as System.Windows.Controls.ComboBoxItem)?.Content?.ToString();
        var grade = GradeTextBox.Text.Trim();

        var args = new StringBuilder($"filter --file {Quote(DataFileTextBox.Text)}");
        if (!string.IsNullOrWhiteSpace(route) && route != "(none)")
        {
            args.Append($" --route {route}");
        }

        if (!string.IsNullOrWhiteSpace(grade))
        {
            args.Append($" --grade {grade}");
        }

        await RunCli(args.ToString());
    }

    private async void OnFilterDateClick(object sender, RoutedEventArgs e)
    {
        var from = FromDateTextBox.Text.Trim();
        var to = ToDateTextBox.Text.Trim();

        var args = new StringBuilder($"filter --file {Quote(DataFileTextBox.Text)}");
        if (!string.IsNullOrWhiteSpace(from))
        {
            args.Append($" --from {from}");
        }

        if (!string.IsNullOrWhiteSpace(to))
        {
            args.Append($" --to {to}");
        }

        await RunCli(args.ToString());
    }

    private void OnClearOutputClick(object sender, RoutedEventArgs e)
    {
        OutputTextBox.Clear();
    }

    private void OnDetectRepoClick(object sender, RoutedEventArgs e)
    {
        RepoPathTextBox.Text = DetectRepoPath() ?? RepoPathTextBox.Text;
    }

    private async Task RunCli(string args)
    {
        var repoPath = RepoPathTextBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(repoPath) || !Directory.Exists(repoPath))
        {
            AppendLine("ERROR: Repo Path not found.");
            return;
        }

        var command = $"run ClimbMateWindowsCLI {args}";
        AppendLine($"> swift {command}");

        var startInfo = new ProcessStartInfo
        {
            FileName = "swift",
            Arguments = command,
            WorkingDirectory = repoPath,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        try
        {
            using var process = Process.Start(startInfo);
            if (process is null)
            {
                AppendLine("ERROR: Failed to start swift process.");
                return;
            }

            var stdout = await process.StandardOutput.ReadToEndAsync();
            var stderr = await process.StandardError.ReadToEndAsync();
            await process.WaitForExitAsync();

            if (!string.IsNullOrWhiteSpace(stdout))
            {
                AppendLine(stdout.TrimEnd());
            }

            if (!string.IsNullOrWhiteSpace(stderr))
            {
                AppendLine("[stderr]");
                AppendLine(stderr.TrimEnd());
            }

            AppendLine($"ExitCode: {process.ExitCode}");
            AppendLine("------------------------------------------------------------");
        }
        catch (Exception ex)
        {
            AppendLine($"ERROR: {ex.Message}");
        }
    }

    private static string Quote(string value)
    {
        return value.Contains(' ') ? $"\"{value}\"" : value;
    }

    private static string? DetectRepoPath()
    {
        var current = AppContext.BaseDirectory;
        var dir = new DirectoryInfo(current);

        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "Package.swift");
            if (File.Exists(candidate))
            {
                return dir.FullName;
            }

            dir = dir.Parent;
        }

        return null;
    }

    private void AppendLine(string line)
    {
        OutputTextBox.AppendText(line + Environment.NewLine);
        OutputTextBox.ScrollToEnd();
    }
}
