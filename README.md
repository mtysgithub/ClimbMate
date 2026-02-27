# ClimbMate

攀岩素材管理核心逻辑（Swift Package），支持未来 iOS 与 Windows 双端。

## 模块结构

- `ClimbMateCore`：跨平台业务核心（标签、过滤、打点、播放规则 + CoreVideoManager 应用服务）
- `ClimbMateCoreiOS`：iOS 平台默认配置封装
- `ClimbMateCoreWindows`：Windows 平台能力与数据存储封装
- `ClimbMateWindowsCLI`：可直接运行的 Windows 命令行/交互模式版本（用于本地验证）
- `windows/ClimbMateWpfShell`：Windows 桌面 GUI（C# WPF 壳，支持新增视频、播放、打点、拖拽时间轴）

## Windows 可运行版本（你可以直接拉取后验证）

### A) Windows 桌面 GUI（WPF）

> 这个 GUI 壳用于桌面交互操作（按钮方式），可直接管理数据文件并进行播放/打点/时间轴拖拽。

在 Windows（PowerShell）中执行：

```powershell
cd windows/ClimbMateWpfShell
dotnet restore
dotnet run
```

打开窗口后（核心流程）：

- `Repo Path` 填仓库根目录（包含 `Package.swift`）
- `Data File` 默认 `./data/videos.json`
- 点击 `Load` 加载数据
- 在左侧填写 `Video ID` + `视频文件路径` + `route/grade/format`，点击 **新增视频**
- 左侧列表选中某个视频后，右侧可：
  - `Play/Pause/Stop` 播放
  - 拖动时间轴（Slider）进行 seek
  - 在当前时间输入文本并点击 **当前时间打点**
  - 选中一个打点并点击 **跳转到选中打点**

### 1) 构建

```bash
swift build -c release --product ClimbMateWindowsCLI
```

### 2) 初始化示例数据

```bash
swift run ClimbMateWindowsCLI init-sample --file ./data/videos.json
```

### 2.1) 交互模式（推荐）

```bash
swift run ClimbMateWindowsCLI interactive --file ./data/videos.json
```

进入菜单后可以直接选：

- 初始化示例数据
- 查看视频
- 路线+难度过滤
- 日期范围过滤
- 给视频添加打点

### 3) 列出全部视频

```bash
swift run ClimbMateWindowsCLI list --file ./data/videos.json
```

### 4) 按路线/难度过滤

```bash
swift run ClimbMateWindowsCLI filter --file ./data/videos.json --route sport --grade 5.10a
```

### 5) 按日期范围过滤

```bash
swift run ClimbMateWindowsCLI filter --file ./data/videos.json --from 2026-01-01 --to 2026-12-31
```

## 已实现能力

- 标签体系
  - `sport` / `bouldering`
  - 路线类型驱动难度可选值
- 视频过滤
  - 标签过滤
  - 日期过滤
  - 平台支持格式过滤
- 单视频笔记
  - 打点排序、前后跳转
- 播放逻辑
  - 线性播放
  - 遇打点暂停 + 手动恢复
  - seek 拖拽
- Windows 数据能力
  - JSON 存储（`WindowsVideoStore`）
  - 记录到核心模型转换（`WindowsVideoRecord -> VideoAsset`）
  - 可组合过滤服务（`WindowsVideoService`）
- 跨端复用核心应用服务
  - `CoreVideoManager`：UI/平台层统一调用（iOS 与 Windows 共用一套核心编排）

## 测试

```bash
swift test
```

覆盖核心模块测试 + Windows 模块测试。
