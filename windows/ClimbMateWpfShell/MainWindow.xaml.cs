using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;

namespace ClimbMateWpfShell;

public partial class MainWindow : Window
{
    private readonly JsonSerializerOptions _jsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    private readonly DispatcherTimer _timer;
    private bool _isSeeking;

    private List<VideoRecordModel> _videos = new();
    private VideoRecordModel? _selectedVideo;

    public MainWindow()
    {
        InitializeComponent();

        RepoPathTextBox.Text = DetectRepoPath() ?? string.Empty;
        DataFileTextBox.Text = @"./data/videos.json";
        MarkerTextTextBox.Text = "动作笔记";
        CurrentTimeTextBlock.Text = "00:00";

        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(300) };
        _timer.Tick += (_, _) =>
        {
            if (_isSeeking) return;
            if (Player.NaturalDuration.HasTimeSpan)
            {
                TimelineSlider.Maximum = Player.NaturalDuration.TimeSpan.TotalSeconds;
            }

            TimelineSlider.Value = Player.Position.TotalSeconds;
            CurrentTimeTextBlock.Text = FormatSecond((int)Player.Position.TotalSeconds);
        };

        AppendLine("ClimbMate WPF GUI ready.");
        AppendLine("流程：Load -> 新增视频 -> 选择视频播放 -> 拖拽时间轴 -> 当前时间打点。");
    }

    private void OnDetectRepoClick(object sender, RoutedEventArgs e)
    {
        RepoPathTextBox.Text = DetectRepoPath() ?? RepoPathTextBox.Text;
    }

    private async void OnLoadClick(object sender, RoutedEventArgs e)
    {
        try
        {
            _videos = await LoadRecords();
            RefreshVideoList();
            AppendLine($"Loaded {_videos.Count} videos.");
        }
        catch (Exception ex)
        {
            AppendLine($"ERROR(load): {ex.Message}");
        }
    }

    private async void OnAddVideoClick(object sender, RoutedEventArgs e)
    {
        try
        {
            var id = VideoIdTextBox.Text.Trim();
            var sourcePath = VideoPathTextBox.Text.Trim();
            var route = ((ComboBoxItem)RouteComboBox.SelectedItem).Content.ToString() ?? "sport";
            var grade = GradeTextBox.Text.Trim();
            var format = ((ComboBoxItem)FormatComboBox.SelectedItem).Content.ToString() ?? "mp4";

            if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(sourcePath) || string.IsNullOrWhiteSpace(grade))
            {
                AppendLine("ERROR(add): id/path/grade 不能为空。");
                return;
            }

            if (_videos.Any(v => v.Id == id))
            {
                AppendLine($"ERROR(add): video id 已存在: {id}");
                return;
            }

            _videos.Add(new VideoRecordModel
            {
                Id = id,
                CreatedAt = DateTime.UtcNow,
                ContainerFormat = format,
                RouteType = route,
                Grade = grade,
                SourcePath = sourcePath,
                Markers = new List<MarkerModel>()
            });

            await SaveRecords(_videos);
            RefreshVideoList();
            AppendLine($"Added video: {id}");
        }
        catch (Exception ex)
        {
            AppendLine($"ERROR(add): {ex.Message}");
        }
    }

    private async void OnRefreshVideosClick(object sender, RoutedEventArgs e)
    {
        _videos = await LoadRecords();
        RefreshVideoList();
        AppendLine("Video list refreshed.");
    }

    private void OnVideoSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (VideoListBox.SelectedItem is not VideoRecordModel video)
        {
            return;
        }

        _selectedVideo = video;
        SelectedVideoTextBlock.Text = $"Selected: {video.Id} ({video.RouteType} {video.Grade})";

        LoadPlayer(video.SourcePath);
        RefreshMarkerList(video);
    }

    private void OnMediaOpened(object sender, RoutedEventArgs e)
    {
        if (Player.NaturalDuration.HasTimeSpan)
        {
            TimelineSlider.Maximum = Math.Max(1, Player.NaturalDuration.TimeSpan.TotalSeconds);
        }
    }

    private void OnPlayClick(object sender, RoutedEventArgs e)
    {
        if (_selectedVideo == null) return;
        Player.Play();
        _timer.Start();
    }

    private void OnPauseClick(object sender, RoutedEventArgs e)
    {
        Player.Pause();
    }

    private void OnStopClick(object sender, RoutedEventArgs e)
    {
        Player.Stop();
        _timer.Stop();
        CurrentTimeTextBlock.Text = "00:00";
    }

    private void OnTimelineValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_selectedVideo == null) return;
        if (Math.Abs(Player.Position.TotalSeconds - TimelineSlider.Value) < 1.0) return;

        _isSeeking = true;
        Player.Position = TimeSpan.FromSeconds(TimelineSlider.Value);
        CurrentTimeTextBlock.Text = FormatSecond((int)TimelineSlider.Value);
        _isSeeking = false;
    }

    private async void OnAddMarkerAtCurrentClick(object sender, RoutedEventArgs e)
    {
        if (_selectedVideo == null)
        {
            AppendLine("ERROR(marker): 请先选择一个视频。");
            return;
        }

        var text = MarkerTextTextBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(text))
        {
            AppendLine("ERROR(marker): 打点文本不能为空。");
            return;
        }

        var second = (int)Player.Position.TotalSeconds;
        var marker = new MarkerModel
        {
            Id = Guid.NewGuid().ToString(),
            AtSecond = second,
            Text = text,
            ImagePath = null
        };

        _selectedVideo.Markers.Add(marker);
        _selectedVideo.Markers = _selectedVideo.Markers.OrderBy(m => m.AtSecond).ToList();

        await SaveRecords(_videos);
        RefreshMarkerList(_selectedVideo);

        AppendLine($"Marker added: video={_selectedVideo.Id}, second={second}, text={text}");
    }

    private void OnJumpToMarkerClick(object sender, RoutedEventArgs e)
    {
        if (MarkerListBox.SelectedItem is not MarkerModel marker) return;

        Player.Position = TimeSpan.FromSeconds(Math.Max(0, marker.AtSecond));
        TimelineSlider.Value = marker.AtSecond;
        CurrentTimeTextBlock.Text = FormatSecond(marker.AtSecond);
    }

    private async Task<List<VideoRecordModel>> LoadRecords()
    {
        var path = ResolveDataFilePath();
        if (!File.Exists(path))
        {
            return new List<VideoRecordModel>();
        }

        var json = await File.ReadAllTextAsync(path);
        return JsonSerializer.Deserialize<List<VideoRecordModel>>(json, _jsonOptions) ?? new List<VideoRecordModel>();
    }

    private async Task SaveRecords(List<VideoRecordModel> records)
    {
        var path = ResolveDataFilePath();
        var folder = Path.GetDirectoryName(path);
        if (!string.IsNullOrWhiteSpace(folder))
        {
            Directory.CreateDirectory(folder);
        }

        var json = JsonSerializer.Serialize(records, _jsonOptions);
        await File.WriteAllTextAsync(path, json);
    }

    private string ResolveDataFilePath()
    {
        var repoPath = RepoPathTextBox.Text.Trim();
        var file = DataFileTextBox.Text.Trim();

        if (Path.IsPathRooted(file)) return file;
        return Path.GetFullPath(Path.Combine(repoPath, file));
    }

    private void RefreshVideoList()
    {
        VideoListBox.ItemsSource = null;
        VideoListBox.ItemsSource = _videos;
        VideoListBox.DisplayMemberPath = nameof(VideoRecordModel.DisplayName);
    }

    private void RefreshMarkerList(VideoRecordModel video)
    {
        MarkerListBox.ItemsSource = null;
        MarkerListBox.ItemsSource = video.Markers.OrderBy(m => m.AtSecond).ToList();
        MarkerListBox.DisplayMemberPath = nameof(MarkerModel.DisplayName);
    }

    private void LoadPlayer(string sourcePath)
    {
        if (string.IsNullOrWhiteSpace(sourcePath))
        {
            AppendLine("WARN: 视频路径为空，无法播放。");
            return;
        }

        try
        {
            var absolute = Path.IsPathRooted(sourcePath)
                ? sourcePath
                : Path.GetFullPath(Path.Combine(RepoPathTextBox.Text.Trim(), sourcePath));

            if (!File.Exists(absolute))
            {
                AppendLine($"WARN: 视频文件不存在: {absolute}");
                return;
            }

            Player.Source = new Uri(absolute);
            Player.Stop();
            TimelineSlider.Value = 0;
            CurrentTimeTextBlock.Text = "00:00";
            AppendLine($"Loaded media: {absolute}");
        }
        catch (Exception ex)
        {
            AppendLine($"ERROR(load media): {ex.Message}");
        }
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
        OutputTextBox.AppendText($"[{DateTime.Now:HH:mm:ss}] {line}{Environment.NewLine}");
        OutputTextBox.ScrollToEnd();
    }

    private static string FormatSecond(int total)
    {
        var time = TimeSpan.FromSeconds(Math.Max(0, total));
        return time.ToString(@"mm\:ss", CultureInfo.InvariantCulture);
    }
}

public class VideoRecordModel
{
    public string Id { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public string ContainerFormat { get; set; } = "mp4";
    public string RouteType { get; set; } = "sport";
    public string Grade { get; set; } = string.Empty;
    public string? SourcePath { get; set; }
    public List<MarkerModel> Markers { get; set; } = new();

    public string DisplayName => $"{Id} | {ContainerFormat} | {RouteType} {Grade} | markers:{Markers.Count}";
}

public class MarkerModel
{
    public string Id { get; set; } = string.Empty;
    public int AtSecond { get; set; }
    public string Text { get; set; } = string.Empty;
    public string? ImagePath { get; set; }

    public string DisplayName => $"{AtSecond}s - {Text}";
}
