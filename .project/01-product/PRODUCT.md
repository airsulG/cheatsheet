# PRODUCT

## 当前方向：原生资料柜（Issue #7，已在本机接替旧版并通过用户验收）

Karl 已授权将资料柜原型应用到正式 macOS App，技术路线保持 SwiftUI + AppKit + CoreData。资料柜成为主窗口，剪贴板与全部资料并列，常用是资料筛选；三栏分别承担导航、结果和全文阅读/编辑。快速复制并收起继续保留。专业冷静的深浅磨砂外观、较小的导航字号、上下排列的图片和说明是当前视觉基准。

资料组织改为多标签，标签可置顶、分组及恢复删除；删除标签或分组不删除片段。新建只要求正文或图片，默认用正文首个非空行显示标题，可保留自定义标题，不要求选择类型。具体标签内新建预选该标签，其他主入口不强制附标签。剪贴板保留原文，保存的片段可独立编辑；复制、复制并收起、未保存保护和返回原位置使用明确文案。

2026-09-14 体验反馈已落实：标签与分组行移除重复的更多按钮，使用右键管理，顶部加号继续负责新建。片段卡片增加独立的单击复制按钮，保持窗口打开；正文点击仍负责阅读。恢复 macOS 原生红绿灯，关闭前保护未保存正文，最小化后快捷键可恢复窗口。资料柜设置、剪贴板设置和备份恢复使用同一深浅外观、分区、字号和按钮样式。

同日后续澄清替代上述点击规则：Karl 的“单击复制”指整张卡片，包括正文和内部留白；独立“查看”按钮只打开全文。复制后保持窗口打开，回车或“复制并收起”仍负责收起。卡片通过轻底色、1pt 边框、9pt 间距区分对象，选中时加强描边，深浅模式均保留清晰边界。

同日最新视觉反馈继续替代卡片查看入口：移除右下角“查看”按钮及其占位，保留整卡单击复制、右侧全文/编辑和键盘选择。正文阅读与编辑底色统一为中性灰，去除偏蓝黑；按钮和选中状态使用来自 App icon 气质的低饱和灰绿色。主窗口与设置左上角使用真实 App icon，不再使用复制符号。设置说明与全局 AccentColor 同步更新。

同日最新交互澄清覆盖前述单击复制规则，Karl 原话为：“单击我建议是展示内容 双击我建议是复制 而且给复制提供一个清晰的反馈”。当前整卡单击只在右侧展示全文，双击复制，顶部出现两秒“已复制到剪贴板”提示，窗口保持打开；右侧复制按钮及复制并收起仍保留。鼠标选择不触发结果列居中或滚动，方向键选择仍能将目标滚入可见范围。中列数量与标题合为一行，例如“全部资料（9）”，降低顶部占高；左侧标签文字从 11pt 调到 13pt，分组标题从 11pt 调到 12pt。移除标签区查找框，顶部搜索继续匹配内容与标签。针对光标出现但拼音落在窗口左下角的反馈，搜索改为原生 NSTextField，组合输入未提交时不覆盖输入框或刷新结果，提交中文后再搜索。

同日窗口与材质反馈已落实：资料柜取消始终置顶，点击其他 App 可正常切换；窗口在后台时快捷键唤回前台，已在前台时才收起。剪贴板历史在来源名称旁显示 22pt App 图标，优先使用复制时保存的图标，缺失或损坏时按 bundle ID 查找本机 App，仍不可用则显示通用 App 符号；列表与右侧原文均显示来源，未知来源不凭名称猜测。右侧阅读、编辑及空态移除不透明纯色背景，与左侧共享原生磨砂，正文可读性和系统降低透明度偏好继续保留。标签标题旁加号直接新建标签，没有下拉箭头；分组是次要操作，继续通过标签“添加到分组 / 新建分组并加入”、分组右键管理及全局菜单处理，不删除分组能力。

同日侧栏对齐修订：主导航、分组、标签及最近删除共用固定图标槽与文字起点；“标签”“置顶”“未分组”对齐文字列，加号与数量共用右侧槽，分隔线统一边距。保留字号、分组折叠、右键管理和加号直接新建，不改变功能。

同日 Karl 确认视觉基本无问题，要求迁移旧数据，并明确选择“直接用新版接替旧版，保留旧版和迁移前备份以便回退”。因旧偏好未指定期限、默认 7 天会影响 114 条旧历史，Karl 另行选择永久保留。已退出旧版保存完整数据库目录、外置附件、偏好和旧 App；在副本迁移并逐字段比较后，安装 Release 新版到原 /Applications/cheatsheet.app，沿用原 bundle ID、原沙盒存储与 ⌘⇧C。70 个片段、19 个分类转标签、524 条历史及 79 张可解码图片完整保留，正式库只读核对和实际退出重启通过。数据不通过 JSON 重复导入，不与旧版并行双写；模拟入口仍保留但验收进程已退出。私人备份只留在本机，回退必须同时处理 App 与数据库，并保护迁移后的新增内容。

实施及验收以 [Issue #7](https://github.com/airsulG/cheatsheet/issues/7) 为准；完整原型演变保存在 [原型原始记录](../04-artifacts/inputs/7/prototype-history.md)，其中被后续反馈替代的旧方向仅作历史证据。首轮原生实现及后续增量均在 codex/native-cabinet，App 实现为 5e17493，迁移检查工具为 e6cb3ab，详见 [正式数据迁移记录](../04-artifacts/verification/7/production-migration.md)。本机安装和旧数据迁移已完成；Karl 已确认“目前修改已经完成，可以合并”，代码合并结果以 [PR #8](https://github.com/airsulG/cheatsheet/pull/8) 为准，对外发布未执行。

2026-09-15 标签切换性能修订（[Issue #9](https://github.com/airsulG/cheatsheet/issues/9)）：阅读正文改为一个连续的原生文本控件，支持跨行选取，保留完整原文、搜索高亮与首个匹配定位；图片和说明仍上下排列。更换片段时从顶部或当前搜索的首个匹配开始，清空搜索回到顶部，同一片段的其他刷新保留选区和阅读位置。点击已选标签继续留在当前编辑状态。标签切换、搜索与排序使用已加载资料，资料发生变化后再更新数量和归属。具体性能、回归与本机更新证据见 [验证记录](../04-artifacts/verification/9/README.md)。

2026-09-15 后续编辑与排版反馈覆盖此前手动进入编辑的规则：选中片段直接显示可编辑正文，单击卡片将输入焦点移到正文；搜索时继续保留搜索焦点。正文或自定义标题失焦、切换片段/标签/搜索、关闭或离开窗口时保存修改，右上角显示“待保存 / 已保存 / 保存失败”；标签选择结束和图片修改也保存。没有变化不重复写入，空白新建不生成记录；失败保留输入并阻止依赖保存的导航。剪贴板原文保持只读，保存为片段后独立编辑。自动保存不清空搜索，修改后不再匹配筛选的当前片段暂时保留到离开编辑页，避免光标和内容突然消失。保存后仍可撤销，切换片段则清除旧片段撤销记录；双击复制和复制并收起保留。

同轮检查了资料柜、图片/文字片段、剪贴板、常用、最近删除、资料柜设置、剪贴板设置、备份恢复和 JSON 导入。详情、列表标题与卡片文字使用统一的 24pt 起点；卡片为 8pt 外距加 16pt 内距；三栏底部使用 64pt 操作区，标签和添加按钮按行居中。正文取消额外 5pt 左内距并正确应用 7pt 行距；图片根据编辑区高度缩放。设置侧栏固定图标槽，设置页使用同一边距和操作排列，导入示例与输入区同宽。实现、截图、失败恢复与本机更新见 [直接编辑与排版验收](../04-artifacts/verification/9/auto-edit.md)。

2026-09-15 最新布局要求覆盖上述常驻三栏：默认只有左侧导航和自适应片段网格，右侧编辑区不占空间。单击卡片立即从右侧展开编辑面板，双击仍复制并显示成功反馈。面板覆盖网格右侧，打开时卡片位置不重排；面板关闭按钮或 Esc 自动保存后收起，保存失败则保留面板和草稿。切换标签或搜索回到网格，新建直接打开编辑面板。双击从关闭状态开始时复制后回到网格；从已打开状态开始则保留面板。键盘操作直接响应，鼠标打开使用短暂滑入，减少动态效果时使用淡入。此次实现及安装见 [网格与按需编辑验收](../04-artifacts/verification/9/grid.md)。

同日网格密度与收起交互补充：卡片从 232pt 缩为 200pt，内边距 14pt，正文预览最多六行，保留等高行及底部标签对齐。再次单击当前卡片保存后收起，点击其他卡片切换编辑；点击卡片间及网格底部空白也保存后收起。当前卡片双击时首击收起、次击仍复制并反馈；保存失败继续保留面板和草稿。图片预览槽同步缩小但保持原比例。

同日保存反馈补充：保存成功在窗口顶部显示与复制同样样式的“已保存”，两秒后消失，收起编辑面板仍可看到。连续操作只显示最新结果；没有修改或空白新建不触发成功提示，保存失败清除旧成功提示并保留草稿。编辑面板左边界使用明确的竖向细线，消除误绘在正文中间的横线。

同日微动效与声音实现（df94eca，已安装到日常版本）：感官方向为“磨砂卡片轻轻落位”。卡片悬停只改变边框与浅底色，按下立即缩放到 0.99，松开 100ms 恢复；保留 200ms 右侧面板过渡及立即输入，不改变卡片尺寸、间距或网格位置。顶部保存/复制共用同一提示，140ms 淡入并移动 5pt、100ms 退出，保留两秒展示与最新结果替换；常用星标只在持久化成功后呈现小幅回弹。减少动态效果时取消空间位移与缩放。

复制成功默认播放原创本地短音；自动保存音默认关闭。现有资料柜设置增加总开关、独立音量（默认 35%）、自动保存音开关及两种试听，偏好持久化。输入、搜索、悬停、滚动和后台采集静音。声音仅由真实保存或剪贴板写入成功触发；保存紧接复制时优先复制，连续操作不叠加声音，限频不限制实际操作。失败保留草稿与错误信息，无修改和空白新建不反馈。实现、性能对照、真实窗口截图、数据保留及尚未完成的听感/录像验收见 [微动效与音效记录](../04-artifacts/verification/9/motion-sound.md)。本机安装与数据核对完成，不把构建、播放器调用或静态截图等同于听感和动态体验通过。

2026-09-15 资料组织增强（[Issue #11](https://github.com/airsulG/cheatsheet/issues/11)）：侧栏边界可左右拖动，默认 188pt、最小 160pt、最大 320pt，同时不超过窗口内容宽度的 30%。松手保存宽度，窄窗口只临时限制，放大和重启恢复个人偏好。卡片高度和网格间距保持不变。

片段右键菜单在具体标签下提供“在此标签置顶 / 取消此标签内置顶”，置顶卡片带小图钉。同一片段在不同标签中独立置顶，不影响全部资料、常用或标签自身置顶。置顶区与普通区内部沿用当前排序，搜索先筛选再排列。主动移除标签关联会清除该标签内置顶，重新加入不恢复；软删除标签或片段保留关系，恢复后继续生效。旧数据自动迁移，备份格式升级为 v3，继续读取 v1/v2。实现和隔离验证见 [侧栏与置顶记录](../04-artifacts/verification/11/README.md)；本轮尚未合并或替换日常 App。

同日 Karl 明确回复“验收通过”，确认 Issue #11 的本轮体验结果，补齐此前拖动观感确认。实现与验证交付在 [PR #12](https://github.com/airsulG/cheatsheet/pull/12)，尚待合并决定；这次验收不等于已经替换日常 App。

下文完整保留改版前的产品事实和问题背景；其中底部横条、单分类及旧设置分区描述已被上方资料柜方向替代，不作为新主界面的要求。

<<<<<<<<<<<<<<<<<<<< 00 Product Identity <<<<<<<<<<<<<<<<<<<<

`cheatsheet` is a local macOS command and clipboard utility. Its main user-visible experience is the bottom Shelf panel: a fast launcher for clipboard history, favorite commands, and categorized command snippets. The app stores durable user data through Core Data entities: `Category`, `Command`, and `ClipboardItem`.

<<<<<<<<<<<<<<<<<<<< 01 Core Objects <<<<<<<<<<<<<<<<<<<<

| Object | Meaning | Long-Term Owner |
|---|---|---|
| Category | User-created command group shown as a Shelf tab | Core Data `Category` |
| Command | Reusable snippet with a title and content copied to clipboard on click | Core Data `Command` |
| ClipboardItem | Captured system clipboard history item | Core Data `ClipboardItem` |

<<<<<<<<<<<<<<<<<<<< 02 Product Rules <<<<<<<<<<<<<<<<<<<<

1. The bottom Shelf panel is a primary operating surface, not a secondary debug view. Capabilities needed for daily command management should be reachable from Shelf when they are safe and compact enough.
2. Command import writes real `Command` objects into a selected `Category`. It must not write directly to the Core Data backing SQLite store.
3. External data should enter the app through an import contract such as JSON text or backup archives, then be persisted by the app through Core Data contexts.
4. Clipboard history and command snippets are separate product objects. Importing command prompts must not create `ClipboardItem` records.
5. Backup files named `cheatsheet-backup-*.json` are runtime artifacts and should not be treated as source-controlled product facts.
6. Shelf command lists must reflect command create, edit, delete, move, favorite, and import results without requiring the user to switch tabs or reopen the panel.
7. Backup, restore, clipboard retention, storage statistics, and destructive cleanup are global app maintenance capabilities. They should live behind one Settings route instead of separate Shelf toolbar windows.

<<<<<<<<<<<<<<<<<<<< 03 当前实现与历史问题 <<<<<<<<<<<<<<<<<<<<

横条已经接入分类命令 JSON 导入、子 ViewModel 更新通知和统一设置窗口。设置包含“横条”“剪贴板”“备份与恢复”三个区块；排序入口位于“横条”设置，默认按标题排序，切换为手动排序后可拖动交换卡片位置。

分类与收藏的搜索按标题或完整正文匹配。无标题栏面板通过 `ShelfPanel.canBecomeKey` 接收键盘输入，搜索字段出现时再请求窗口和字段焦点。剪贴板搜索仍按已加载预览中的类型、文本预览和来源 App 名称过滤，不能把它描述成全库全文搜索。

这些路径的实现已存在，完整交互验收状态见 [Issue #5](https://github.com/airsulG/cheatsheet/issues/5) 和关联 PR。下面保留的是这些实现解决的原始问题背景，并非当前缺失功能清单。

The app already has a JSON command import panel in older main-window surfaces, but the active bottom Shelf panel does not expose it. This makes the app appear to lack bulk import even though the underlying import UI and command creation path exist.

After command creation or editing from Shelf, saved data can exist in Core Data while the visible Shelf card lane stays stale until the user switches tabs. This is a UI state propagation bug: the active Shelf surface should update from the same command state changes that already save successfully.

Backup and clipboard cleanup currently open as two separate utility windows from the Shelf toolbar. That split exposes implementation history instead of user intent: both surfaces are app-level maintenance tasks, and the Shelf should route to one Settings window with clear sections.
