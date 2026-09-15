# 原生资料柜

## 当前补充：侧栏宽度与标签内置顶（Issue #11）

CabinetSplitView 单独持有侧栏宽度和拖动状态，AppKit 分隔控件直接处理 mouseDown / mouseDragged / mouseUp，不使用拖动循环、延迟或布局动画。8pt 命中区覆盖现有边界，不占额外布局宽度；保留正文焦点。默认 188pt，范围 160pt 至 min(320pt, 窗口宽度 × 30%)，AppStorage 仅在松手或辅助功能增减操作后写偏好。窗口临时缩小不修改偏好；无变化的点击也不修改。拖动闭包不调用 ViewModel、Core Data 查询或保存。卡片仍为 200pt 高、12pt 间距。

当前 Core Data 版本为 cheatsheetV3，保留 v1/v2，新增 Command.pinnedTags 与 Category.pinnedCommands 的可选多对多反向关系，删除规则 Nullify。它与 Category.isPinned、Command.isFavorite 分开。CabinetPins 负责成员资格检查、持久化与失败恢复，不修改片段时间和全局手动顺序。当前标签筛选后分成置顶和普通两部分，各自沿用原排序，最后用对象 ID 打破同值；其他位置不采用置顶。手动上移/下移不越过两个部分的边界。

CabinetStore.save 移除活动标签关联时同步清除对应置顶；软删除标签暂时不在选择器中显示，编辑正文仍保留隐藏关系，供恢复使用。保存失败仅恢复本次涉及的字段。备份格式 v3 使用可选 pinnedTagIDs，导入时按新建标签映射并与实际成员关系取交集；旧 v1/v2 缺少该字段即未置顶。真实旧 SQLite 升级、磁盘重开、备份映射和失败注入见 [验证记录](../04-artifacts/verification/11/README.md)。下文保留以前各轮实现及当时版本，当前模型版本以上述 v3 为准。

关联 [Issue #7](https://github.com/airsulG/cheatsheet/issues/7)。基线 main 0e4cfff，实施分支 codex/native-cabinet。主界面使用 SwiftUI，AppKit 管理窗口、磨砂、焦点及文本输入；继续复用剪贴板监控、快捷键、导入与设置。

## 数据兼容的决定

保留旧 CoreData 模型版本，以新增模型实现多标签。Category 的存储名称保留以兼容旧数据，产品中称为标签；新增 Command.tags 多对多关联、标签分组、删除恢复状态、片段图片与剪贴板来源。原有 category 关联保留供旧导入与兼容读取，新增片段以 tags 为准。旧 category 首次补入 tags，补入状态随片段持久化，避免取消标签后又被旧关联自动加回。

删除标签只标记为已删除，不调用旧级联删除路径；删除组保留恢复依据。新备份覆盖无标签片段、多标签、图片、分组和恢复状态，并可导入旧版本。验证使用隔离数据库和命名测试剪贴板，禁止将真实用户数据当测试夹具。

## 原生与网页的差异

模型版本名为 cheatsheetV2.xcdatamodel。当前 Xcode 同步文件夹会重新选择按名称排在末尾的模型，因此新版本按此命名，同时显式登记 XCVersionGroup 和 .xccurrentversion。Apple DTS 已确认此类问题并认可命名办法：https://developer.apple.com/forums/thread/779939?page=2 。构建后与迁移检查一起验证实际当前模型，不只看配置文字。

网页颜色、空间关系和交互是参考；原生材质使用 NSVisualEffectView，窗口可调整大小，实际快捷键仍由 macOS 响应者处理。不照搬网页模拟桌面或蓝灰/暖灰对照控件。验收需原生构建、存储行为检查及实际窗口截图，不能用网页截图替代。

## 已实现的职责与验证

实现代码固定在 f097cd3f55fa2dd13e900102bf9383f66c68aa1a。CabinetStore 负责迁移、标签、分组和恢复；CabinetViewModel 负责查询、选择、草稿保护与复制；CabinetWindowController 负责激活窗口、键盘响应、窗口大小与返回之前的 App。CabinetView 和 CabinetEditor 分别呈现三栏资料柜与连续正文，长文输入使用 NSTextView。原有 ClipboardMonitor、设置与导入继续使用，BackupService 增加 v2 格式并兼容 v1。

数据保存通知只安排主线程刷新，不在后台通知线程读取 viewContext。后台自动合并后的刷新对象也纳入观察，避免新记录要重开窗口才能出现。普通 App 使用系统剪贴板；隔离 Debug 验收标识使用内存数据和命名剪贴板，不启动真实监控和自动备份。

窗口使用可激活的 NSPanel，使跨 App 唤出后能接收键盘。显式设定初始尺寸并让 NSHostingController 只提供最小尺寸，避免阅读和编辑切换时窗口自行缩小。隐藏前保护未保存草稿，隐藏后激活先前的 App。恢复导航保存查询和选中项，并将选中项滚入视野；不承诺恢复每一像素的滚动偏移。

体验反馈修订恢复了 titled / closable / miniaturizable 原生窗口控制，保留 fullSizeContentView 和透明标题栏；不再对整个 SwiftUI 根视图另加圆角裁切，交给原生窗口裁切。NSHostingController.safeAreaRegions 设为空，视图内为红绿灯保留 28pt，磨砂覆盖标题栏。设置窗口使用同一办法，并复用 CabinetSettingsPage / CabinetSettingsSection 组织三个设置页。最小化后 show() 先 deminiaturize，避免快捷键 toggle 错走关闭分支。

构建、旧 SQLite 升级、新旧备份、删除恢复冲突、独立剪贴板格式及重启回读已通过；实际窗口完成新建、编辑、保存、多标签、分组、深浅切换和跨 App 快捷键路径。完整证据和验证限制见 [验证记录](../04-artifacts/verification/7/README.md)。正式数据库升级、合并与安装尚未执行。

2026-09-14 输入与选择修订（77230fd）：CabinetSearchField 使用 NSTextField 自己的 field editor 保持焦点与组合输入。代理在 hasMarkedText 为真时不提交搜索，也不截获方向键和回车；SwiftUI 更新时不覆盖 marked text。⌘K 显式使窗口和输入框接收键盘，不再切换 SwiftUI FocusState。真实键入 sheji 后空格上屏“设计”已验证。列表滚动改为监听独立 selectionScrollRequest：鼠标 select 只改变选中对象，方向键与导航恢复才请求滚入视野，且不再使用 center 锚点。卡片单击查看、双击复制；仅复制成功后设置 copiedItemID，取消上一轮反馈计时并在两秒后清除成功提示，复制失败仍走错误提示。

同日窗口与材质修订（4f0ec4d）：CabinetPanel 保留可激活、跨空间唤出和原生控制按钮，层级改为 normal，isFloatingPanel=false；toggle 仅在 App 活跃且资料柜为 key window 时收起，其余情况执行 show。右侧不再覆盖 palette.reader，透出根视图的 CabinetMaterial（NSVisualEffectView.sidebar / behindWindow）；NSTextView 与 NSScrollView 本身继续不画背景。CabinetClipboardSource 统一列表和原文区的来源信息，CabinetSourceIcon 缓存历史图标解码及本机 bundle 图标回退，不修改数据库或采集逻辑。

正式迁移已于同日完成：先停止旧进程并保留整份 SQLite 目录与外置附件，在副本迁移验证；同 bundle ID Release 版本安装到原路径，NSPersistentContainer 接续原沙盒，migrateLegacyTags 补入多标签关系。校验工具对旧模型全部属性和关系建立快照，二进制字段按 SHA-256 核对；默认只迁移到不存在的副本目录，--compare-current 只读核对正式库保留所有旧记录，允许监控新增记录。用户已将本机历史保留设置改为永久，避免启动清理旧历史。正式运行与模拟预览仍由原有 CabinetRuntime.isPreview 分流，未新增第二套数据源或云同步。

## 标签切换与长文阅读的性能边界

[Issue #9](https://github.com/airsulG/cheatsheet/issues/9) 将阅读区改为 CabinetReader：NSScrollView 内的元信息与图片由 NSHostingView 呈现，正文由一个只读、可选择的 NSTextView 呈现。切换片段复用控件，保留全文与跨行选择；正文或宽度变化时才重新计算文字高度。字体只在正文变化时判断一次。搜索匹配使用正确的 UTF-16 范围高亮，并通过原生滚动定位到首个匹配；更换片段时从顶部或当前搜索的首个匹配开始，清空搜索回到顶部，同一片段的其他刷新保留选区和阅读位置。

CabinetViewModel.reload 在初始化、数据变更和窗口重新显示时重建片段与标签归属，并一次性发布统计。普通导航、搜索和排序调用 refreshItems；标签通过缓存的对象 ID 索引找到片段，不重复查询和统计全库。缓存仍属于主线程 context，未跨队列传递托管对象。剪贴板数据更新仍通过自动合并后的通知刷新；数据刷新同时清除最多 256 项的卡片短文本缓存。标题提取遇到首条非空行就返回，不再预处理全文。

`scripts/verify_core_behaviors.py --cabinet` 验证内容原样复制、末尾搜索定位、宽度变化、选区保留、标签与数据缓存更新，以及旧数据兼容。`scripts/verify_cabinet_performance.py` 比较相同正文的修复前逐行结构与当前原生阅读区，默认使用模拟数据，也可显式指定只读 SQLite 副本；只输出数量、长度和耗时。分项布局耗时不等于点击到屏幕更新的延迟，实际窗口行为需要另外验证。

## 直接编辑与失焦保存

2026-09-15 的补充需求在同一 Issue #9 / PR #10 交付。片段默认使用 CabinetEditor 中的连续 NSTextView，CabinetReader 继续承担剪贴板只读原文。选中后同步草稿；后台刷新不会覆盖脏草稿。editorSession 绑定一轮编辑，SwiftUI Binding 和失焦保存都核对 session，阻止已离开的控件写入新草稿。editorFocusRequest 只在单击片段、新建或明确编辑时请求焦点，搜索更新不抢焦点。

CabinetEditableTextView.resignFirstResponder 和 textDidEndEditing 提交已上屏文字；hasMarkedText 时不把拼音组合写入草稿。标题焦点、标签选择结束、图片修改以及窗口失焦接入同一个 autosave。导航、关闭、复制和移到最近删除先调用 allowLeaving，自动保存失败则停留。save 保留草稿并更新 originalDraft，既保留撤销栈也避免无变化重复写；查询不被清空，pinnedDraftID 暂时保留刚保存但不再匹配筛选的编辑对象，到下一次导航/搜索/选择时解除。CabinetStore.save 失败只恢复本次修改的字段，避免其他操作误存失败内容，不调用整个 context.rollback。

CabinetGrid 统一 24pt 内容边距、52pt 标题区和 64pt 底部操作区。NSTextView 的 lineFragmentPadding 为 0，程序加载的正文也应用 7pt 行距；搜索使用临时高亮属性，不把样式写入片段。切换编辑会话重置撤销和选区；查询匹配定位后将插入点放在匹配开头，清空查询回到顶部。详见 [行为与页面验收](../04-artifacts/verification/9/auto-edit.md)。

## 网格与按需编辑面板

同日最新布局以 188pt 导航栏加自适应 LazyVGrid 替代常驻三栏。卡片最小宽度 210pt、间距 12pt、等高 232pt，标题、摘要和标签分层排列；图片在固定预览槽内按比例缩放。isDetailPresented 独立于 selection，默认不创建编辑面板；打开后以 340–460pt 宽度覆盖右侧，网格不重排。搜索、导航和关闭窗口收起面板，收起前复用 allowLeaving 保存并保留失败草稿。方向键上下按实际网格列数移动，搜索中的左右键保留文字光标行为。

CabinetCardInteraction 保存首击对象 ID、窗口坐标、时间及导航上下文。窗口内第二次原生鼠标按下满足系统双击时间和位置边界时，仍复制首击对象，即使面板已覆盖该位置；消费对应 mouseUp，防止事件落入编辑器。它不通过等待双击计时器延迟首次展开。鼠标展开采用 200ms ease-out 位移，键盘不加动画，系统减少动态效果时改为透明度过渡。验收与安装证据见 [网格记录](../04-artifacts/verification/9/grid.md)。

后续密度与收起修订（b672393）将卡片改为 200pt、14pt 内边距、最多六行文字及 64pt 图片预览。CabinetViewModel.toggleDetail 区分当前卡片和其他卡片，前者保存后收起，后者打开/切换。ScrollView 的网格内容至少覆盖可见高度，其背景命中区域接收卡片间和底部空白点击；卡片 Button 优先处理自身点击，不用父层手势抢走卡片操作。收起统一复用 closeDetail 的保存失败保护。双击继续由窗口鼠标事件处理，当前卡片首击关闭后仍能复制。

保存提示与边线修订（5058dca）：面板 overlay 内的 Divider 没有竖向布局约束，会在中间画横线，替换为 leading 对齐、宽 1pt 的 Rectangle。toastMessage 和一个可取消任务统一管理保存/复制成功提示，最新操作替换旧提示并重新计时，两秒后清空。save 真实落盘成功后发布“已保存”，copy 成功后发布“已复制到剪贴板”；无变化和空白草稿直接返回，不重启计时；失败清除旧成功提示并保留原有错误与草稿保护。提示位于 CabinetView 根部，不依赖编辑面板是否仍存在。

## 微动效与成功音效

2026-09-15，4e3c3a7 / df94eca 延续原有交互。CabinetMotion 集中曲线，CabinetCardStyle 只在视觉层响应悬停和按下；外层 contentShape 保持点击区域。标签的 animation 仅放在选中背景，面板沿用原 transition，不增加等待或逐项入场。CabinetToast 常驻根部，透明退出时保留上一条文字；非空提示替换不重新触发入场，显示时长仍由 ViewModel 的原有可取消任务管理。系统 Reduce Motion 分别控制卡片缩放、提示位移/勾选缩放、星标缩放和面板方向过渡，不控制声音。

CabinetViewModel.toggleFavorite 先完成现有草稿保存，再保存星标状态；失败恢复该对象原有星标及 updatedAt，不回滚整个 context。CabinetFavoriteButton 的局部动画不向网格传播，快速操作最终服从持久化状态。

CabinetSoundPlayer 是主线程单例，App 初始化时将两段 PCM WAV 读入内存并 prepareToPlay。播放路径不读取资源文件；中断使用 pause 保留准备状态，自然结束的 AVAudioPlayerDelegate 回调重新准备下一次。音频采用项目原创程序合成，不需要联网或第三方素材。没有循环播放或常驻轮询；唯一延迟任务是启用保存音后的 80ms 合并窗口，复制立即取消它。复制限频 120ms；保存与最近声音相隔不足 300ms 时静音。这些判断均在成功操作之后，只减少声音，不丢弃保存或复制。

WindowController 将 ViewModel 的 successFeedback / cancelPendingFeedback 接到播放器；模型测试默认不发声。保存与复制失败取消待播保存音；总开关关闭或音量为零停止当前声音，关闭保存音取消待播保存音。设置通过 AppStorage 与播放器共用偏好键；默认总开关开、保存音关、音量 0.35，试听仍服从总开关和音量。播放器不可用时显示“音效暂不可用”，文字提示独立工作。

Apple 的 [pause](https://developer.apple.com/documentation/avfaudio/avaudioplayer/pause()) 与 [prepareToPlay](https://developer.apple.com/documentation/avfaudio/avaudioplayer/preparetoplay()) 描述准备和暂停语义；实际构建使用本机 SDK 中的 AVAudioPlayerDelegate 主线程约束。真实播放器调用、行为测试与尚未通过的体验验证分别记录在 [微动效与音效验收](../04-artifacts/verification/9/motion-sound.md)，不把 prepareToPlay 或 play 返回成功解释为主观听感合格。
