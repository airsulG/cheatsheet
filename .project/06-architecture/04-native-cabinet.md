# 原生资料柜

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
