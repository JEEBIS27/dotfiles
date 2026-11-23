# Tide Island 项目优化审查报告

审查日期：2026-10-07（Asia/Bangkok）
审查版本：`e44fe2a`，CMake 项目版本 `1.0.41`
本地验证环境：Qt `6.11.2`，现有 Release 构建目录 `build-spotify-check`

后续更新（2026-10-09）：第 3.1、3.2 项已在源码中修复，实施与验证记录见第 9 节。下文审查结果和测量数据对应原审查版本。

后续更新（2026-10-16）：第 3.3、3.4 项也已完成，实施与验证记录见第 10 节。

## 1. 主要结论

项目已经具备按需卸载界面、共享 C++ 服务、事件订阅、缩略图缓存和请求去重等基础优化。最值得继续改进的是：**限制大图解码尺寸、减少界面线程上的同步调用、让全局数据只采集一次，以及避免反复计算和重建对象。**

建议先完成前四项；它们分别直接改善内存、响应速度、多屏数据准确性和配置正确性。

| 顺序 | 问题与建议 | 主要收益 | 修改量 | 证据 |
| --- | --- | --- | --- | --- |
| 1 | 给剪贴板大图预览设置稳定的 `sourceSize` | 明显降低大图预览内存 | 小 | 独立 Qt 实验 PSS 减少约 30.7 MiB |
| 2 | Wi-Fi 属性读取改为 `GetAll`，随后改为异步 | 减少界面卡顿与 D-Bus 往返 | 中 | 每个 AP 目前有 5 次同步属性读取 |
| 3 | CPU/RAM/存储采样集中到一个共享服务 | 减少后台工作，修正多屏 CPU 采样干扰 | 小至中 | 各屏定时器修改同一组采样状态 |
| 4 | 复用配置应用已有的注释解析器 | 消除配置内容被静默修改的问题 | 小 | 已复现 `/*literal*/` 被删除 |
| 5 | 应用搜索缓存标准化字段，每次查询只分词一次 | 降低输入时延和临时分配 | 小至中 | Qt JS 评分实验约快 3.35 倍 |
| 6 | 壁纸优先生成当前可见项的缩略图 | 大图库首屏更快，减少无用解码 | 中 | 当前会为全部缺失缩略图排队 |
| 7 | 多屏工作区总览共享 Hyprland 快照 | 减少重复进程、JSON 解析和数据副本 | 中 | 每屏有一个 `HyprlandData` |
| 8 | 歌词响应在下载阶段限制体积和并发 | 控制异常响应带来的内存峰值 | 中 | 现有上限在 `readAll()` 之后才应用 |
| 9 | 运行时停止子进程改为异步 | 避免收起界面时阻塞 | 小至中 | 两处同步等待最多约 450 ms |
| 10 | Wi-Fi 模型避免无变化重置，长列表改用 `ListView` | 减少对象销毁重建和打开面板的开销 | 小至中 | 全量 reset + `Repeater` |
| 11 | 按实际歌词展示需求订阅后端 | 无歌词需求时降低后台占用 | 中 | 目前只检查是否存在播放器 |
| 12 | 缓存清理、状态逻辑整理、构建测试开关 | 控制长期磁盘增长，降低维护成本 | 分项实施 | 静态检查 |

“证据”中的实验都是局部验证；除明确列出的实测数据外，收益判断来自代码分析。没有将这些收益相加，也没有推算整个项目能降低多少百分比的内存。

## 2. 审查范围和现有运行内存

审查覆盖主入口、核心 QML 组件、C++ 系统服务、Wi-Fi、歌词、配置解析、图片缓存、构建与测试流程。源码、测试和脚本统计约 116 个文件、40,558 行；重点检查高频执行路径和资源生命周期，并非逐行证明所有代码正确。

对正在运行的安装实例只做了读取 `/proc` 的采样，没有重启或切换用户界面。核对的 52 个主界面 QML/JS 文件与 `/usr/share/tide-island` 中的文件完全一致；未逐个核验安装的 C++ 二进制与当前编译输出是否相同。

2026-10-07 22:41:09 至 22:41:13，间隔约 2 秒的三次采样较接近。下表使用中间一次样本，单位 MiB：

| 进程 | RSS | PSS | Swap |
| --- | ---: | ---: | ---: |
| Quickshell 主进程，PID 3041 | 234.4 | 146.6 | 35.4 |
| 歌词后端，PID 91098 | 39.0 | 12.5 | 3.1 |
| 已观察到的其他子进程：`pactl`、两个 `dbus-monitor`、`pw-mon` | 22.4 | 1.4 | 1.5 |
| 上述进程合计 | 295.8 | 160.5 | 40.1 |

RSS 包含进程映射的共享库页面，直接相加会重复计算共享部分；PSS 按共享比例分摊，更适合比较这一组进程的常驻内存。Swap 另列，不包含在当前常驻 PSS 中。[Linux 内核 `/proc` 文档](https://docs.kernel.org/filesystems/proc.html)

这些数值是已有运行会话的瞬时参考，**不能当作冷启动、空闲状态的标准基线，也不能据此判断是否泄漏**。未统计完整 GPU 驱动/显存占用，也未把服务树外已有的剪贴板监听器计入合计。后续需要固定媒体状态、屏幕数量、界面状态和缓存条件做前后对比。

另外，几个常驻监控子进程合计 PSS 约 1.4 MiB。把它们全部改成原生接口，需要相当多工作，按这次样本看不是优先的内存优化方向。

## 3. 优先处理的问题

### 3.1 剪贴板大图预览加载了原始尺寸

位置：[ClipboardLayer.qml:716](../qml/island/ClipboardLayer.qml#L716)。

`fullPreviewImg` 设置了显示宽高、异步加载和 `cache: false`，但没有设置 `sourceSize`。显示区域较小仍会加载大图。`cache: false` 控制图片缓存，不限制当前图片的加载尺寸；`width`、`height` 控制绘制尺寸。Qt 明确提供 `sourceSize` 来限制加载图片的像素数量。[Qt Image 文档](https://doc.qt.io/qt-6/qml-qtquick-image.html#sourceSize-prop)

同文件的小缩略图已经使用 `sourceSize: Qt.size(96, 88)`，播放器封面和工作区图标也设置了尺寸。这是一个局部遗漏。

**验证：**独立 offscreen Qt 进程，加载同一张合成的 3840×2160 JPEG，显示区域固定为 352×276，不创建窗口或 GPU 纹理：

| 加载方式 | 实际加载尺寸 | RSS | PSS |
| --- | --- | ---: | ---: |
| 不设置 `sourceSize` | 3840×2160 | 81.4 MiB | 50.9 MiB |
| `sourceSize: Qt.size(640, 480)` | 640×360 | 50.8 MiB | 20.3 MiB |

这一次实验的 PSS 差为 **30.7 MiB**。单张 32 位像素缓冲的理论大小也会从约 31.6 MiB 降至约 0.88 MiB。实验说明这项修改有明显潜力；它不是实际 Quickshell 界面的完整峰值测量。JPEG 可在解码时缩小，其他图片格式仍可能产生完整解码的临时峰值。[Qt Image 文档](https://doc.qt.io/qt-6/qml-qtquick-image.html#sourceSize-prop)

**建议：**进入预览时按最终显示尺寸和屏幕 DPR 确定加载上限，保持它在动画期间稳定。实验中的 `640×480` 只是示例，不应直接作为所有屏幕的固定值。将 `sourceSize` 绑定到每帧变化的动画尺寸会导致重复加载；高 DPI 屏幕也需要相应提高上限。

### 3.2 Wi-Fi 刷新在界面线程上同步调用 D-Bus

位置：[WifiController.cpp:1241](../backend/WifiController.cpp#L1241)、[WifiController.cpp:1579](../backend/WifiController.cpp#L1579)。

NetworkManager 路径对每个 AP 分别读取 `Ssid`、`Strength`、`Flags`、`WpaFlags` 和 `RsnFlags`，最终调用 `systemBus().call(message)`。默认调用方式会阻塞等待响应。这些方法由 QML 和对象定时器直接调用，因而可能暂停界面线程。[Qt QDBusConnection 文档](https://doc.qt.io/qt-6/qdbusconnection.html#call)

假设附近有 50 个 AP，仅这一段就需要 250 次属性读取，不含设备状态和保存连接的读取。**这是调用次数推算，不是实测卡顿时长。**

**建议分两步做：**

1. 每个 AP 改成一次 `org.freedesktop.DBus.Properties.GetAll`，从返回的属性表取出五个值。这一段属性请求由 `5N` 降到 `N`，代码也更集中。
2. 使用 `asyncCall` 和 `QDBusPendingCallWatcher`，设置明确超时、有限并发和刷新代次；旧刷新结果不能覆盖新扫描结果。保持原有 SSID 合并和信号强度排序规则。[Qt 异步 D-Bus 文档](https://doc.qt.io/qt-6/qdbusconnection.html#asyncCall)

项目的 [LyricsMprisApp.cpp:226](../lyricsmpris/LyricsMprisApp.cpp#L226) 已有异步 `GetAll`、超时和请求合并的实现，可以沿用相同方式。

### 3.3 多屏统计重复采样，并干扰 CPU 计算

位置：[shell.qml:429](../shell.qml#L429)、[DynamicIslandWindow.qml:1156](../DynamicIslandWindow.qml#L1156)、[IslandSystemState.qml:362](../qml/island/IslandSystemState.qml#L362)、[SystemServices.cpp:882](../backend/SystemServices.cpp#L882)。

每个屏幕都会实例化一个 `IslandSystemState`。只要配置包含 CPU/RAM 模块，各实例就每 3 秒调用共享的 `SystemServices.requestSystemStats()`；存储模块还会每 10 秒各启动一次 `df`。目前条件只取决于模块是否配置，与模块是否正在展示无关。

CPU 占用计算使用服务中的 `m_lastCpuTotal` 和 `m_lastCpuIdle`。第二个屏幕紧接着调用时，会使用第一个屏幕刚更新的基准，采样窗口变得很短；如果 `/proc/stat` 总值尚未增加，代码会发出默认的 0。所有屏幕又都会接收这个结果。这个问题同时影响开销和数据准确性。

**建议：**由共享服务或 shell 根节点维护一套采样定时器、最近样本和订阅计数。每个窗口只消费结果；需要首次展示时请求一次刷新，多个请求合并。CPU 首次尚无差值样本时可表示为“等待采样”。

存储查询也集中一次，优先考虑 `QStorageInfo`，避免每屏反复启动 `df`。它自带缓存，更新时需要 `refresh()`；文件系统统计应在适当的工作线程中完成。替换时核对保留块和“当前用户可用空间”的计算口径，保证百分比符合原有展示。[Qt QStorageInfo 文档](https://doc.qt.io/qt-6/qstorageinfo.html)

收益随屏幕数量增加。单屏下 `/proc` 文件很小，减少这些读取主要改善后台唤醒和结构，不应宣称能节省几十 MiB。

### 3.4 两套配置注释解析器行为不一致，已经造成错误

位置：[UserConfigBackend.cpp:34](../backend/UserConfigBackend.cpp#L34)、[Tide-island-app/backend.cpp:438](../Tide-island-app/backend.cpp#L438)。

运行时先用正则删除 `/*…*/`，没有区分字符串和注释；处理 `//` 时也仅检查引号前一个字符，没有完整处理连续转义。配置应用则已有按字节扫描的状态机，能区分字符串、转义和两类注释。

**实际复现：**在临时配置目录写入合法 JSON，然后实例化当前编译的 `UserConfigBackend`：

```json
{"wallpaperCustomCommand": "printf '/*literal*/'"}
```

读出的命令为 `printf ''`，`configError` 仍为空。字符串被静默改写。

**建议：**把配置应用已有的状态机提取为两边共用的小工具，删除运行时的正则版本。增加字符串内注释符号、反斜杠、引号和换行等回归用例；保持空白和换行还可以让 JSON 错误位置更准确。这项改动的主要收益是正确性和减少重复维护。

## 4. 有明确收益的后续优化

### 4.1 应用搜索：把不变的工作移出循环

位置：[ApplicationSearch.js:76](../qml/common/ApplicationSearch.js#L76)、[ApplicationLauncherLayer.qml:289](../qml/island/ApplicationLauncherLayer.qml#L289)。

每个应用的 `applicationScore(entry, query)` 都重新对同一查询分词、标准化，并创建七个字段对象、标准化应用元数据。每次输入还会重新扫描和排序所有应用。收藏判断和排序比较器中使用的 `indexOf` 也会重复扫描收藏列表。

**建议：**应用列表变化时准备搜索字段；一次查询只准备一份 tokens 和标准化查询，再为各应用计算评分。收藏变化时准备 ID 到排序序号的映射。保留评分、收藏顺序和相同分数的排序规则。

**验证：**直接使用项目的评分源码，在 Qt `QJSEngine` 中比较原写法与字段/查询预处理写法。使用 800 个合成应用、7 个查询，每轮每查询执行 10 次，共 56,000 次评分；预热后进行 5 轮，交替测量顺序：

| 轮次 | 原写法 | 预处理写法 |
| --- | ---: | ---: |
| 1 | 1000 ms | 299 ms |
| 2 | 1007 ms | 311 ms |
| 3 | 1001 ms | 294 ms |
| 4 | 1000 ms | 311 ms |
| 5 | 1013 ms | 295 ms |
| 中位数 | **1001 ms** | **299 ms** |

评分部分约快 **3.35 倍**，耗时下降约 **70%**；5,600 个应用/查询组合的逐项评分相等，各轮总评分校验一致。一次建立字段索引约 10 ms。

这个实验没有模拟真实的 DesktopEntry QObject 访问、排序、布局和图标加载，因此不能说整个启动器快了 3.35 倍。预处理缓存会增加一些保留内存，换来较少的重复工作和临时分配。可以首次输入非空查询时再建索引，应用变化时失效，面板卸载时释放。

第一步只需要优化现有 JS，不必立即引入 C++ 搜索模型。未来真实应用规模和输入时延仍有压力时，再考虑模型迁移或短时间合并输入事件。

### 4.2 壁纸缩略图按可见顺序生成

位置：[WallpaperPickerLayer.qml:292](../qml/island/WallpaperPickerLayer.qml#L292)、[WallpaperPickerLayer.qml:352](../qml/island/WallpaperPickerLayer.qml#L352)、[WallpaperPickerLayer.qml:734](../qml/island/WallpaperPickerLayer.qml#L734)。

当前会为所有没有缓存的壁纸加入缩略图队列，而 `PathView` 只有最多 5 个路径项和 4 个缓存项。图库很大时，会处理大量尚未浏览的图片；当前选择的位置靠后时，其缩略图可能排在许多不需要的任务后面。两个 `ListModel` 和两组索引也保留了重复的元数据。

已有的串行执行、关闭时清空队列、卸载面板，以及 C++ 的缩小解码、元数据校验和原子写入都是合理设计，应继续保留。

**建议：**扫描元数据与生成图片分开。优先当前项和附近项，滚动后更新优先级；余下项在空闲时处理。大队列用读取游标替代不断 `shift()`。先避免无用解码，之后再评估是否需要用一个源模型加过滤索引替代双模型。

全局缩略图服务目前只去重相同请求，没有独立的并发上限；多屏、不同尺寸和快速切换壁纸可能同时提交不同任务。可用有限的全局工作队列和代次淘汰控制峰值。当前正在解码的一项可以允许完成，关闭界面时丢弃待执行任务。

这是大图库场景的优化，尚未测量实际首屏时长或内存差。

### 4.3 工作区总览共享数据采集，保留每屏自己的视图

位置：[WorkspaceOverviewScene.qml:21](../qml/workspace/WorkspaceOverviewScene.qml#L21)、[HyprlandData.qml:72](../qml/workspace/HyprlandData.qml#L72)、[HyprlandData.qml:158](../qml/workspace/HyprlandData.qml#L158)、[SystemServices.cpp:696](../backend/SystemServices.cpp#L696)。

打开多屏总览时，每屏的场景创建自己的 `HyprlandData`，分别请求 clients、monitors、workspaces、activeworkspace。三屏首次打开会提交 12 个快照命令，四类全局快照实际上可以各读取一次。

各实例使用相同的 requestId，并都接收服务广播的响应。一个实例的响应会清除其他实例的 running 标记并触发解析，可能在其他请求尚未完成时过早允许下一次刷新。C++ 还先解析 JSON，再序列化字符串交给 QML 重新解析。

**建议：**shell 维护一个按需求激活的共享 `HyprlandData`，各屏只进行输出筛选和布局。这样先消除重复采集与响应交叉，再评估传递结构化数据是否值得。也可以在 C++ 按 subject 合并请求，并明确请求归属。

总览现在已经会在关闭后卸载，改成共享以后仍需最后一个使用者退出时卸载，并保留已有的关闭动画宽限期。这项收益主要发生在多屏总览打开期间。

### 4.4 歌词响应上限应在下载过程中生效

位置：[LyricsMprisApp.cpp:79](../lyricsmpris/LyricsMprisApp.cpp#L79)、[LyricsMprisApp.cpp:697](../lyricsmpris/LyricsMprisApp.cpp#L697)。

`safeBody()` 先 `readAll()`，然后返回前 2 MiB。完整响应已经下载并可能占据缓冲区，截断返回内容不能约束下载期间的峰值。多个提供方和候选歌曲请求会并发执行；每家候选数上限也不等于全局并发上限。

**建议：**在 `readyRead` 中读取有限的剩余字节，对累计体积设上限，超过时中止并标记响应过大；读取到上限外一个字节即可判定，无需继续累计。结合有限的网络读缓冲和全局并发队列。仅设置 `setReadBufferSize` 会产生背压，不是严格的响应体上限，仍需要消费数据和累计检查。[Qt QNetworkReply 文档](https://doc.qt.io/qt-6/qnetworkreply.html#setReadBufferSize)

保留已有超时、切歌代次检查和中止旧请求的机制。体积超限应返回明确失败，避免把截断后的 JSON 当作完整响应解析。

主要收益是控制异常响应的内存峰值；正常歌词较小时可能看不出明显变化。本次未向真实歌词服务发送额外测试请求。

### 4.5 子进程停止使用异步收尾

位置：[SystemServices.cpp:345](../backend/SystemServices.cpp#L345)、[SysBackend.cpp:608](../backend/SysBackend.cpp#L608)。

两处停止逻辑都采用 `terminate()` 后等待 150 ms，失败后 `kill()` 再等待 300 ms。运行时取消最后一个 Cava/歌词订阅也会走这里，不仅在应用退出时使用。退出较慢的子进程因此可能阻塞界面最多约 450 ms。

**建议：**先解除其输出订阅并发出 terminate；收到 finished 后释放；用一次性定时器超时升级到 kill。停止中的对象单独持有，新实例不能被旧实例的退出回调清空。应用最终销毁与正常运行时收尾分别处理。

这里的 450 ms 是代码允许的等待上界，不是已测到的正常退出时间。重点收益是避免偶发卡顿。

### 4.6 Wi-Fi 列表减少整体重建，并按视口创建行

位置：[WifiNetworkModel.cpp:51](../backend/WifiNetworkModel.cpp#L51)、[ConnectivityDetailPanel.qml:634](../qml/connectivity/ConnectivityDetailPanel.qml#L634)。

`setNetworks()` 每次都 reset 整个模型，即使结果没有变化。详情面板使用 `Flickable + Column + Repeater`，会为所有网络创建行，隐藏行仍然有对象。这会放大频繁扫描更新造成的分配和重建成本。[Qt Repeater 文档](https://doc.qt.io/qt-6/qml-qtquick-repeater.html)

**建议按成本逐步实施：**先比较新旧条目，完全相同就返回；再只更新变化的角色；最后将可能很长的网络列表替换为具有固定视口的 `ListView`。表头、扫描状态和密码输入区域可作为外围元素或视图 header/footer。若启用 delegate 复用，需要重置交互状态。

小型、固定数量的控制按钮继续使用 `Repeater` 即可。此项主要改善 AP 较多时的打开速度、滚动和刷新，内存收益尚未量化。

### 4.7 歌词后端的启停条件可以表达真实需求

位置：[IslandMprisController.qml:75](../qml/island/IslandMprisController.qml#L75)、[DynamicIslandWindow.qml:1066](../DynamicIslandWindow.qml#L1066)。

目前 `setLyricsClientActive` 的条件为 `activePlayer !== null`，播放器存在但暂停、岛隐藏或正在显示其他页面时也可能保持后端。采样时歌词进程的 PSS 约 12.5 MiB，另有约 3.1 MiB Swap。

**建议：**增加明确的 `lyricsNeeded`，综合是否真的展示歌词、正在向歌词状态过渡、自动展开行为和预取策略。多屏需求继续通过已有 client 集合合并；最后一个需求消失后保留短暂宽限期，避免快速切换时反复启动和查询。

暂停时如果歌词仍在展示，应继续保留当前内容。也应检查普通胶囊和播放器中的歌词展示，不能仅依据面板是否展开判断。此建议需要产品行为回归，未验证能在当前使用状态节省多少内存。

## 5. 写法和维护成本

### 5.1 小范围提取状态规则，逐步拆分大组件

`DynamicIslandWindow.qml` 有 3,415 行，`ControlCenterLayer.qml` 有 2,550 行；尺寸计算、状态切换、定时器、交互和视觉定义混在一起。

最小且容易审查的起点是 [DynamicIslandWindow.qml:1008](../DynamicIslandWindow.qml#L1008) 附近重复的“当前是否处于基础胶囊状态”判断。可以提取一个派生属性，再用于文件中转、剪贴板、天气、日历等条件：

```qml
readonly property bool restingCapsuleState:
    islandState === "normal" || islandState === "lyrics" || islandState === "custom"
```

随后把计时器状态和控制逻辑、连接面板生命周期、胶囊尺寸规则逐项拆出。每次提取一个边界，保留动画阶段和键盘焦点语义。

仅拆文件或统一命名不会自然降低运行内存。要得到资源收益，需要减少重复实例、无用订阅和对象重建；这部分整理主要让后续改动更容易验证。

### 5.2 把嵌入 QML 的长 Python 脚本提取成文件

位置：[WallpaperPickerLayer.qml:105](../qml/island/WallpaperPickerLayer.qml#L105)。

壁纸扫描和应用脚本由大量字符串拼接组成，涉及 Python、QML 和命令行三层表达。可提取到 `scripts/`，用参数传入目录、尺寸和过渡配置，继续保留现有测试和安装路径规则。

这样可以直接进行语法检查、单独测试和复用，减少转义错误。它的主要价值是可维护性；没有实测依据证明单纯移动脚本会明显降低常驻内存。

### 5.3 缓存需要过期和容量策略

壁纸选择器缓存键包含路径、修改时间、大小、尺寸和质量，生成新缓存后旧文件没有自动清理流程。剪贴板图片缓存只在显式删除/清空时删除，底层历史自动淘汰的条目可能留下原图。[WallpaperPickerLayer.qml:112](../qml/island/WallpaperPickerLayer.qml#L112)、[cliphist-helper.sh:24](../scripts/cliphist-helper.sh#L24)

建议在后台清理不再被当前索引引用的缓存，设置可配置的磁盘预算，保留正在使用的文件和短暂宽限期。剪贴板缩略图与原始预览文件也可以分离：列表只准备小图，打开预览时再准备原始内容。

这项主要解决长期磁盘增长和图片准备 I/O，不能把磁盘缓存大小直接等同于进程内存。本次没有读取用户剪贴板内容或盘点其历史图片。

### 5.4 构建与低收益优化

| 项目 | 当前情况 | 建议及收益边界 |
| --- | --- | --- |
| 测试构建 | 根 CMake 和配置应用无条件依赖 Qt Test，测试可执行文件参与构建 | 用 `include(CTest)` 和 `if(BUILD_TESTING)` 包围测试依赖/目标，发行构建可关闭；降低构建成本，对运行内存影响很小。[CMake CTest 文档](https://cmake.org/cmake/help/latest/module/CTest.html) |
| Spotify 配置检查 | [SpotifyBridge.cpp:37](../backend/SpotifyBridge.cpp#L37) 每 3 秒读取并解析配置，即使未配置也继续 | 仿照 UserConfig 使用目录/文件监听与防抖，必要时保留低频恢复检查；主要减少唤醒和 I/O |
| JS 容错与类型 | 部分代码多次做字符串、数组与数值归一化 | 先明确入口类型并在边界归一化，删除确实冗余的内部转换；保留外部配置与 IPC 的必要校验 |

以上都排在大图、阻塞调用和重复采集之后。

## 6. 已有优化应继续保留

- 多数展开面板的 `Loader.active` 受页面状态控制，关闭后释放实例；总览也有预热和卸载宽限期。Qt 的 inactive Loader 会释放所加载的 item。[Qt Loader 文档](https://doc.qt.io/qt-6/qml-qtquick-loader.html#active-prop)
- 壁纸缩略图已在工作线程生成，使用 `QImageReader.setScaledSize()`、缓存元数据和原子写入，相同请求会去重。
- Cava 和歌词后端已经按 client 集合共享，没有每屏启动一份独立后端。优化启停条件时应保留这种合并机制。
- 电池、亮度、音量已经采用 udev、文件监听和音频事件驱动；时钟会对齐到分钟，播放器进度定时器仅展开时运行。
- 通知历史已限制为 50 条；剪贴板默认读取上限为 200 条。部分列表已使用 `ListView` / `GridView`。
- Spotify 本地桥接已有连接数、消息大小、认证超时和请求代次处理。

这些边界说明：继续优化应针对具体遗漏和高成本路径，避免将现有事件驱动机制改成更频繁的轮询。

## 7. 验证结果与后续验收

本次完成了：

1. `cmake --build build-spotify-check --parallel 2`，成功。
2. 在临时 XDG 配置/数据/缓存目录中运行 `ctest --test-dir build-spotify-check --output-on-failure`，**11/11 通过**，约 17.8 秒。
3. `bash tests/installer_tests.sh`，通过。
4. Qt JS 搜索局部对比、offscreen 图片加载对比和配置解析错误复现。

现有测试通过不代表上述性能路径已经得到覆盖。当前仓库缺少 CMake 条件引用的 `tests/user_config_backend_tests.cpp` 和 `tests/lyricsmpris_core_tests.cpp`；也未见针对多屏统计和 Wi-Fi 同步调用的回归测试。配置应用的 `--validate-qml` 验证不能代替完整的 Quickshell 交互验证。

实施改动时，最有价值的新增回归检查是：

| 改动 | 验收方式 |
| --- | --- |
| 配置解析共享 | 两个消费者对字符串内注释符号、转义和真实注释输出一致 |
| 共享统计 | 模拟多个订阅者，确认采样次数不随屏数增加、CPU 差值窗口一致 |
| Wi-Fi 异步 | 模拟延迟和失败的 D-Bus，界面可交互，旧刷新结果被丢弃 |
| 搜索预处理 | 保留现有排序/评分用例，比较优化前后分数与收藏顺序 |
| 网络体积上限 | 本地响应服务发送超限和分块数据，确认中止、清理和切歌代次行为 |
| 图片与列表 | 在实际 Wayland 界面中比较内存峰值、清晰度、滚动和关闭后残留 |

后续性能对比建议固定单屏/多屏、媒体暂停/播放、DPR、壁纸数量和热/冷缓存，分别测量：启动稳定后的空闲；打开/切换/关闭大图预览；100/1000 张壁纸图库；多屏总览；AP 较多的网络列表；连续打开关闭面板后的趋势。

内存记录 PSS、匿名 PSS、SwapPss 和峰值；交互记录首次可用时间与卡顿，而不只看平均 CPU。连续场景测试应观察重复操作后是否继续增长，关闭后留足异步任务收尾时间，并用堆分析区分仍存活对象与分配器/Qt 可复用缓存。不能仅依据 RSS 没有立即下降判断泄漏。

## 8. 推荐实施顺序与本地证据

先做 **大图尺寸限制、配置解析共享、Wi-Fi `GetAll`、共享统计、搜索预处理**。这些改动边界相对清楚，其中两项已有局部定量收益，一项已复现正确性问题。

第二批做 **Wi-Fi 异步、可见壁纸优先、总览数据共享、网络响应上限**，分别处理复杂 I/O、图片任务和多屏场景。最后按实际 profiling 结果推进列表增量更新、歌词需求订阅与结构整理。

2026-10-07 的审查轮次只新增报告，未修改业务实现。实验源代码保留在被 Git 忽略的 `build-review/` 中，可在当前工作区复查；它们不是正式功能或完整测试套件：

- `build-review/review-probes.cpp`：Qt JS 执行器和配置读取探针。
- `build-review/application-search-benchmark.js`：原评分函数、预处理变体、合成数据、评分一致性检查与五轮计时。
- `build-review/image-probe.cpp`：生成独立 JPEG 测试文件并比较加载尺寸；不使用用户图片。

搜索实验可用 `build-review/review-probes build-review/application-search-benchmark.js` 重跑。图片实验程序通过 `fixture`、`original`、`bounded` 三种模式运行，需设置 `QT_QPA_PLATFORM=offscreen`；机器负载和共享库驻留状态会影响具体内存与时间数值。

## 9. 已实施的修复（2026-10-09）

**剪贴板大图预览：**提取 [ClipboardPreviewImage.qml](../qml/island/ClipboardPreviewImage.qml)，以 `520×400×屏幕 DPR` 限制加载尺寸。预览打开时加载、退出时清空图片来源；加载尺寸不跟随胶囊动画变化。显示层单独计算等比适配，避免 `PreserveAspectFit` 对加载尺寸的额外调整。Qt 对这类加载尺寸调整的说明见 [Image.sourceSize 文档](https://doc.qt.io/qt-6/qml-qtquick-image.html#sourceSize-prop)。此限制控制保留的图片尺寸；PNG 等格式的解码过程仍可能存在原图大小的临时内存。

**Wi-Fi 刷新：**通过 `QtConcurrent` 在线程池中采集设备、网络、保存的连接和扫描状态，再在界面线程应用纯数据快照。NetworkManager 每个热点的五次属性读取合并为一次 `GetAll`，活动热点数据直接复用；iwd 复用 `GetManagedObjects` 快照。每个控制器只运行一个采集任务，重复刷新合并排队，状态变化或后端切换会取消旧任务并丢弃旧结果。单次调用超时为 1.5 秒，完整快照预算为 12 秒；刷新失败保留上一次列表。网络服务重启后重新加载保存连接，iwd 的类型注册和新增热点信号处理也已补齐。连接、断开和电源控制操作保留原有实现。

新增正式回归测试：[clipboard_preview_tests.cpp](../tests/clipboard_preview_tests.cpp) 覆盖 4K 横图、竖图、JPEG/PNG、1×/1.5×/2× DPR、动画期间不重新加载和退出释放；[wifi_controller_tests.cpp](../tests/wifi_controller_tests.cpp) 使用隔离 D-Bus 与独立模拟服务进程，覆盖慢响应期间事件循环可用、属性合并、刷新合并、旧结果丢弃、错误/超时、iwd、新增热点、后端切换、服务重启及控制器销毁。验证环境更新为 Qt `6.12.0`。

Release 构建、全部 13 组 CTest 和新增 QML 组件的 `qmllint` 检查通过。尚未对实际无线设备或安装实例做性能对比，原报告的局部内存实验数据未作为本次修改的实测收益。

## 10. 共享统计与配置解析修复（2026-10-16）

**3.3 共享统计：**新增 [SystemStats](../backend/SystemStats.h) 单例，由它维护全屏共享的 CPU/RAM 采样、根分区采样、缓存及订阅者集合。CPU/RAM 采样间隔为 3 秒，存储为 10 秒。各屏仅在自定义信息区域可见且配置包含对应模块时订阅，自动隐藏后取消订阅，最后一个订阅退出后停止相应定时器。窗口销毁也会释放订阅。

`/proc` 与文件系统信息统一在后台线程读取，每次最多一个采样任务，多个窗口的首次请求和刷新请求会合并，窗口间共享同一个 CPU 差值基准。首个 CPU 样本只建立基准并显示 `--%`，没有新增 tick 时保留上次值；离开后再以过期缓存恢复时重新建立基准。CPU 总时间同时避免重复计入 guest/guest_nice。读取失败时保留有效值，订阅失效后的旧结果会被丢弃。

删除各屏的 `df` 进程和轮询定时器，改用后台新建的 `QStorageInfo` 获取根分区快照，避免复用过期缓存。[Qt QStorageInfo 文档](https://doc.qt.io/qt-6/qstorageinfo.html) 区分 `bytesFree` 与当前用户的 `bytesAvailable`；百分比使用 `ceil(100 × used / (used + available))`，保留原 `df` 展示中的保留块口径及向上取整规则。测试包括合成保留块场景和真实根分区与 `df` 的对照。

**3.4 共享注释解析：**把配置应用的按字节状态机提取到 [JsonComments.h](../common/JsonComments.h)，运行时和配置应用统一调用。字符串内的注释符号、网址、转义引号、连续反斜杠及 UTF-8 内容保持原样。真正的注释替换成等长空白并保留换行；两端读取均保留 CRLF 原始字节，因此 JSON 错误位置对应原文件偏移，也不会把注释两侧的数字拼接成另一个合法值。

新增 [system_stats_tests.cpp](../tests/system_stats_tests.cpp) 与 [user_config_backend_tests.cpp](../tests/user_config_backend_tests.cpp)。前者覆盖三屏共用采样及基准、停止订阅、后台慢读取、旧结果丢弃、失败恢复、存储百分比、销毁安全，并直接加载真实 `IslandSystemState.qml` 验证多实例、隐藏和配置变更。后者覆盖两个实际配置消费者的读取、保存后重载及一致的错误偏移。测试使用临时配置和合成 `/proc` 文件，QML 测试中的音频、电池等服务使用替身。

验证结果：Release 完整构建成功；在临时 XDG 配置、数据和缓存目录中运行全部 **15/15 组 CTest，通过，约 25.35 秒**；`bash tests/installer_tests.sh` 通过。未对正在运行的安装实例做真实多屏交互或前后内存对比，因此没有给出整个进程的内存节省量。
