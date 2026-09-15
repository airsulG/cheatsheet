# 标签切换与长文阅读性能

本页保留首轮性能修复证据。同日后续的默认编辑、失焦自动保存和主要页面对齐检查见[直接编辑与排版验收](auto-edit.md)；网格及按需编辑见[网格验收](grid.md)，横线修复、保存提示与已安装版本见[保存反馈验收](save-feedback.md)。最新代码的交互细节、声音、性能对照和未完成的体验验收见[微动效与音效记录](motion-sound.md)。

2026-09-15，[Issue #9](https://github.com/airsulG/cheatsheet/issues/9)。Karl 先要求分析录屏中的轻微切换延迟，在诊断后明确回复“好，开始修复”。基线为 main aac7625；App 最终实测实现为 25e6f31。三个可以独立撤销的实现提交分别为 63a7723（连续阅读区）、c0ed97a（标题和短文本缓存）、25e6f31（标签筛选与统计分离）。后续提交只补充可重复测量工具和记录。

## 实现与判断

每行一个 SwiftUI Text 的全文布局是这次长文切换的主要成本。现在通过一个 NSTextView 阅读全文，元信息和图片仍与正文在同一滚动区域。切换保留控件，内容或宽度变化时才重算文字布局。字体判断从每行一次变成每篇一次；结果卡片缓存标题、摘要和字体选择；首行标题找到第一条非空行即停止扫描。

CabinetViewModel 在数据刷新时建立标签对应的片段列表和数量；导航、搜索和排序不再查询并统计全部片段。数据保存或后台合并仍会清除短文本缓存并重建资料索引，避免显示旧标题、旧归属或旧数量。

## 性能测量

同一份冻结的只读数据副本含 76 个片段、20 个标签、574 条历史。该副本在分析阶段生成，未写入真实存储。修复期间用户继续使用 App，安装前的最新数据已经增至 77 个片段和 579 条历史；安装使用最新正式库，不使用诊断副本覆盖。

Xcode 27 beta，macOS 27，原生 arm64；Debug 对象开启 `SWIFT_OPTIMIZATION_LEVEL=-O ENABLE_TESTABILITY=YES`。导航测量不创建界面，200 次循环；正文测量用 480pt 文本宽度，新建阅读视图，预热两轮后取六轮。旧结构在测量程序中保留为对照，两种结构使用同一段原文。下面是中位数：

| 测量对象 | 旧实现 | 修复后 |
| --- | ---: | ---: |
| 无界面标签导航 | 2.165 ms | 0.009 ms |
| 73 行 / 1761 字符的正文布局 | 26.785 ms | 3.426 ms |
| 233 行 / 3143 字符的正文布局 | 96.330 ms | 8.044 ms |
| 1418 行 / 18823 字符的正文布局 | 1584.501 ms | 42.555 ms |

233 行样本布局耗时减少约 92%，1418 行样本减少约 97%。一行短文对照为 0.735 ms / 0.828 ms，新控件的固定成本并非对所有输入都更小。导航每次发出的状态通知从约 89.1 次降为 6.1 次；通知次数不等于实际重绘次数。标题提取的 233 行样本从每次约 0.788 ms 降至约 0.005 ms，属于独立分项实验。

这些分项不可相加后冒充鼠标点击延迟。未测量精确的点击到首帧时间、帧率或 GPU 成本。六次布局样本的 p95 实际等于最大值，不作为稳定尾延迟承诺。原视频为 25fps，不能据此给出毫秒级的真实点击延迟。正式进程的诊断采样支持布局和文字处理是重点，但自动化读取辅助功能树也会产生额外成本，不将整个采样占比解释为用户日常性能。

可重复命令：

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/cheatsheet-tag-fix \
  CODE_SIGNING_ALLOWED=NO SWIFT_OPTIMIZATION_LEVEL=-O ENABLE_TESTABILITY=YES \
  PRODUCT_BUNDLE_IDENTIFIER=zhouqiaaha.top.cheatsheet.cabinet-preview.tag-fix build

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
python3 scripts/verify_core_behaviors.py /tmp/cheatsheet-tag-fix --cabinet

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
python3 scripts/verify_cabinet_performance.py /tmp/cheatsheet-tag-fix

# 显式提供本机数据副本时，仅只读访问，不输出用户标题或正文。
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
python3 scripts/verify_cabinet_performance.py /tmp/cheatsheet-tag-fix "$READ_ONLY_STORE_COPY"
```

默认模拟数据与只读副本两条测量路径都退出 0。原始本机日志位于 `/tmp/cheatsheet-tag-analysis/`：`benchmark-run2.log` 是修复前导航分项，`performance-reproducible.log` 是上表同文布局对照，`performance-synthetic.log` 是独立模拟样本结果。这些本机日志没有自动上传到 GitHub，用户数据库和录屏没有提交。

## 行为与窗口验证

优化 Debug 构建和签名 Release 构建均成功。`navigation-checks-2.log` 的检查全部通过，Core Data 并发断言开启：保留旧 SQLite 字段与关系、备份 v1/v2、图片与多标签回读、原始剪贴板格式、中文组合输入、跨行 Unicode / CRLF 原文复制、末尾匹配高亮与滚入可见范围、变窄后换行、同片段刷新保留选区、换片段重置位置，以及改名、换标签、删除、恢复和后台新增后的列表与数量更新。原 `cheatsheetTests` 没有配置 XCTest target，本次没有把它们声称为已运行；没有独立 Agent Review 或远端 CI。

隔离 App 使用内存数据和独立剪贴板。实际窗口验证了图片与说明上下排列，约 233 行模拟中文的保存、长短标签往返切换、末尾搜索的高亮与定位，以及未保存编辑切换时出现保护提示，选择“保存并继续”后能重新搜索到新增内容。关闭隔离进程后再更新日常版本。首次窗口检查发现标题、图片与正文重叠，已修复 NSHostingView 高度计算，并增加保留标题高度的断言。早期跨行复制检查误用了原生 NSTextView 未声明的 pasteboard type，改为其实际支持的类型后通过；这不是通过弱化原文相等断言跳过失败。

## 本机更新与数据保留

签名 Release 构建参数为 `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=`，目录 `/tmp/cheatsheet-tag-fix-release`。在日常窗口没有未保存编辑时正常退出，保留完整 SQLite 目录、外置附件、偏好和旧 App，然后从已通过签名检查的临时安装包移至 `/Applications/cheatsheet.app`。保留策略读回为永久保留，没有改动设置。

新 App 启动显示 77 个片段、20 个标签和 579 条历史。只读逐行比较 `ZCOMMAND`、`ZCATEGORY`、`ZCLIPBOARDITEM`、`ZTAGGROUP`、`Z_1TAGGEDCOMMANDS`，原有行、全部属性和标签关系全部保留；旧记录无改写，数量相同。正式窗口完成提示词、命令行、设计标签往返切换，恢复更新前正在查看的标签和片段。`codesign --verify --deep --strict` 通过，新运行进程来自正式安装路径。

旧执行文件 SHA-256：`7c58d8c2358916499cf9447959bf2cab9542bea4d36f0c81ad225d43ea6f7e49`。
新执行文件 SHA-256：`f0ce6dddff315fa325946cb360b68526635cca4815a856db0a1b5a8cf3fbbc17`。

本机备份位于用户 `Library/Application Support/cheatsheet-migration-backups/20260915-135410-tag-latency`，内含旧 App、完整 store、偏好和 `installation.json`。本次不改数据模型，回退 App 时应先退出当前进程并保护最新数据；不要用旧快照覆盖之后新增的内容。未执行回退演练。备份保留，不自动删除。

修复已安装到本机；GitHub 仍通过独立分支和 Draft PR 等待审查及合并决定，未对外发布。
