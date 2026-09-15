# 片段直接编辑、自动保存与页面对齐

2026-09-15，关联 [Issue #9](https://github.com/airsulG/cheatsheet/issues/9) 和 [PR #10](https://github.com/airsulG/cheatsheet/pull/10)。正式安装的实现为 `0f298265272307f33fb85de4de06eeba4a46b944`，保留上一轮标签性能修复。GitHub 合并和对外发布没有执行。

## 用户目标与结果

Karl 要求选中片段直接编辑，输入框失去焦点后自动保存并反馈；同时目视检查每个主要页面，修复元素对齐与排版。截图中的片段正文只作为界面内容，没有当作额外执行指令。

已实现正文和标题失焦保存、导航和关闭前保存、窗口失焦保存，保存结果显示在右上角；剪贴板原文仍只读。没有改动时不写入，空白新建不生成记录，失败保留输入并阻止导航。标签选择关闭和图片修改同步保存。搜索不清空，保存后仍在原片段；编辑使片段不再匹配当前筛选时，暂时保留到离开编辑页。

## 页面目视检查

全部截图来自本次启动的隔离 Debug 原生 App，使用内存演示数据和命名剪贴板；不包含正式数据库或用户录屏。检查覆盖下列主页面，保持现有三栏结构、磨砂外观和功能入口。

| 页面 | 观察到的问题与修正 | 当前截图 |
| --- | --- | --- |
| 资料柜图片片段 | 标题、标签、正文的左起点不同；正文额外缩进 5pt。统一为 24pt，并让图片随编辑区高度缩放 | [图片片段](auto-edit-images/after-main.png) |
| 文字片段 | 原有程序加载文字未正确应用行距；正文恢复 7pt 行距，保存状态固定在右上角 | [文字片段](auto-edit-images/after-editor.png) |
| 全部资料、常用与标签列表 | 标题和卡片文字差 3pt，列表与详情底栏高度不同。卡片改为外距 8pt + 内距 16pt，标题起点 24pt，底栏 64pt | [常用](auto-edit-images/after-favorites.png) |
| 剪贴板 | 阅读区与编辑区边距不同；改为同一 24pt。来源、正文仍上下排列，原文只读 | [剪贴板](auto-edit-images/after-history.png) |
| 最近删除 | 说明和列表标题起点统一，保留删除说明及恢复入口 | [最近删除](auto-edit-images/after-trash.png) |
| 资料柜设置 | 侧栏图标宽度和标签起点统一，外观控件按设置值的右侧列对齐；说明同步自动保存 | [资料柜设置](auto-edit-images/after-settings.png) |
| 剪贴板设置 | 手动操作按钮与其他设置页使用同一横向排列和间距 | [剪贴板设置](auto-edit-images/after-clipboard-settings.png) |
| 备份与恢复 | 复核标题、卡片、表单值和操作行；通过共用设置容器统一为 24pt 边距 | [备份](auto-edit-images/after-backup.png) |
| JSON 导入 | 示例框窄于输入区；示例改为填满内容列，内外边距和图标槽一致 | [导入](auto-edit-images/after-import.png) |

同状态的[修改前编辑页](auto-edit-images/before-editor.png)与[修改后图片编辑页](auto-edit-images/after-main.png)已并列目视比较；[修改前导入页](auto-edit-images/before-import.png)保留作对照。标签与“添加标签”按同一行的最高控件垂直居中，不再贴顶。

## 行为证据

真实隔离窗口完成单击即进入正文、中文和表情输入后切到搜索框显示已保存、标题失焦保存、切换标签后回读修改、打开设置后返回显示已保存、保存后撤销并再次保存。232 行、5,887 字符模拟正文的[末尾搜索与高亮定位](auto-edit-images/after-search-tail.png)可见，清空搜索后滚动条回到 0；[双击复制反馈](auto-edit-images/after-copy.png)可见。正式安装后选中原来的设计片段，正文直接获得输入焦点，原文内容未更改。

优化 Debug 与签名 Release 构建成功。`verify_core_behaviors.py --cabinet` 和 `verify_core_behaviors.py` 均通过，启用 Core Data 并发检查。新增覆盖直接编辑、自动保存与无变化不写入、筛选保留、旧会话隔离、空白新建、剪贴板只读、验证失败阻止导航、模拟磁盘写入失败后的字段恢复与重试，以及关闭数据库后回读自动保存内容。真实 CabinetEditableTextView 的输入法测试确认拼音组合不写入草稿，上屏中文后通过原生失焦回调保存。旧 SQLite、图片、多标签、备份和 JSON 导入检查继续通过。

初次检查暴露旧测试对阅读区顶部高度的固定阈值不适用于 24pt 边距，改为验证实际预留了元信息及间隔。后台合并检查原来只固定等待 150ms，在负载下偶发失败；改成等待可观察结果并在 2 秒超时报错。没有把未执行的 XCTest target 或独立审查计为通过。

命令（均设置 `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`）：

```sh
python3 scripts/verify_core_behaviors.py /tmp/cheatsheet-autosave-build --cabinet
python3 scripts/verify_core_behaviors.py /tmp/cheatsheet-autosave-build
python3 scripts/verify_cabinet_performance.py /tmp/cheatsheet-autosave-build
```

Debug 使用 `PRODUCT_BUNDLE_IDENTIFIER=zhouqiaaha.top.cheatsheet.cabinet-preview.autosave CODE_SIGNING_ALLOWED=NO SWIFT_OPTIMIZATION_LEVEL=-O ENABLE_TESTABILITY=YES`。Release 使用正式 bundle ID 和 `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=`，DerivedData 为 `/tmp/cheatsheet-autosave-release`。

## 最终构建的性能复测

沿用上一轮冻结只读副本中的相同正文，文本宽度为 480pt，预热两次后取六次中位数；不输出正文。编辑器测量包含 SwiftUI 包装与原生可编辑文本的完整布局，阅读区测量为独立原生文档布局，二者工作量不同。

| 正文规模 | 旧逐行阅读结构 | 当前只读原文区 | 当前可编辑文本控件 |
| --- | ---: | ---: | ---: |
| 1 行 / 8 字符 | 0.582 ms | 0.714 ms | 1.638 ms |
| 73 行 / 1,761 字符 | 26.781 ms | 3.309 ms | 10.160 ms |
| 233 行 / 3,143 字符 | 95.547 ms | 7.828 ms | 20.485 ms |
| 1,418 行 / 18,823 字符 | 1,551.593 ms | 41.902 ms | 59.723 ms |

200 次无界面导航中位数 0.017 ms，p95 0.043 ms。可编辑控件的固定成本高于只读控件，但长文仍避免了逐行视图重建。短文没有全场景提速承诺。测量脚本已修正为从共享边距反推相同文本宽度，避免布局边距调整影响比较。

## 正式安装与数据核对

安装前确认正式 App 没有未保存草稿，再退出进程。完整保留旧 App、SQLite 目录、外置附件和偏好；新包先复制到独立 staging 路径并验证签名，再通过 rename 安装到 `/Applications/cheatsheet.app`，没有覆盖旧备份。

本机备份：`~/Library/Application Support/cheatsheet-migration-backups/20260915-142539-autosave`。旧可执行文件 SHA-256 为 `f0ce6dddff315fa325946cb360b68526635cca4815a856db0a1b5a8cf3fbbc17`，新文件为 `bf865d1b681ca3fbd83eaca6706ab32ea759405ea3d0a8fad685e964ac227c44`。签名检查通过。

安装并启动后只读逐行比较：77 个片段、20 个标签、582 条历史、77 条标签关系和 0 个分组的全部字段一致；78 个外置文件 SHA-256 一致。`clipboard_retention_days=0` 仍为永久保留。恢复原先设计标签和选中片段，没有把模拟数据写入正式库。备份和正式数据只留本机。

## 验证边界

截图覆盖本次实际检查的主要页面，不代表所有窗口尺寸、所有内容长度或 VoiceOver 验收。原生布局测量不等于点击到首帧时间；没有精确帧率、GPU、远端 CI、独立 Agent Review 或回退演练的结论。保留分支和备份，等待 Karl 体验验收与合并决定。
