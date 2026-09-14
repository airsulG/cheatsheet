# cheatsheet

一个本地 macOS 片段和剪贴板工具。资料柜以三栏组织剪贴板、全部资料、常用和标签，右侧直接阅读或编辑正文。一个片段可以有多个标签，标签可以置顶、分组与恢复删除。无需填写标题或选择类型，正文首个非空行会成为默认标题。

单击整张卡片在右侧查看全文，双击复制并显示“已复制到剪贴板”，窗口保持打开；标签与分组通过右键管理。卡片以轻底色、细边框和间距明确对象范围，选中项使用灰绿色描边。鼠标选择不滚动列表，方向键选择才请求将目标滚入可见范围。结果数量紧跟标题显示为“全部资料（9）”；标签区不再设置查找框，顶部搜索仍匹配内容与标签。窗口保留原生红绿灯和真实 App icon，正文、设置与备份使用统一的中性灰底色与绿色强调色，支持深浅模式。

继续使用 SwiftUI + AppKit + CoreData；深浅外观通过原生磨砂融入桌面。“复制并收起”返回之前的 App。⌘⇧C 唤出，⌘K 搜索，方向键选择，回车复制收起；编辑时 ⌘S 保存、⌘↵ 保存并复制收起。搜索使用原生文本输入框，拼音组合阶段保留输入状态，中文上屏后更新结果。原有 JSON 导入、剪贴板保留设置、备份与恢复继续可用。旧分类升级为标签，备份 v2 包含多标签、分组、无标签片段及图片，并可导入 v1。

本次实现对应 [Issue #7](https://github.com/airsulG/cheatsheet/issues/7)，原生运行证据见 [验收记录](.project/04-artifacts/verification/7/README.md)。合并、正式安装与真实数据升级仍需按交付决定进行。

窗口使用普通层级，点击其他 App 可正常切换；在后台时快捷键唤回，已在前台时收起。剪贴板来源以 App 图标和名称共同识别，右侧阅读与编辑共享侧栏的原生磨砂。标签旁加号直接新建标签；分组的创建、编辑和删除保留在管理菜单中。

## 构建

使用完整 Xcode，在仓库根目录执行：

```sh
xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/cheatsheet-build build
```

如果系统默认选择的是 Command Line Tools，可在当前命令前指定 `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`，或替换为你实际安装的 Xcode 路径，无须改变系统全局设置。

## 验证关键行为

```sh
python3 scripts/verify_core_behaviors.py /tmp/cheatsheet-build
python3 scripts/verify_core_behaviors.py /tmp/cheatsheet-build --cabinet
```

使用自定义 `DEVELOPER_DIR` 构建时，验证命令也应使用同一路径。脚本链接本机架构的 Debug 应用对象，排除 App 启动入口，使用独立内存数据库，并打开 Core Data 并发检查。它验证拖动交换、标题排序、保存回读、标题与完整正文搜索、子 ViewModel 刷新、备份导入回读、面板文字输入和 JSON 示例导入。

脚本不启动剪贴板监控，不修改真实数据库或系统剪贴板。窗口输入检查会短暂显示一个测试输入框。它不能替代完整 SwiftUI 界面、中文输入法、拖拽手感和长时间运行的体验验收。`cheatsheetTests/` 保留已有 XCTest 文件，当前 Xcode 工程尚未配置测试 target；不能把构建成功视为这些 XCTest 已执行。

## 运行隔离验收版

```sh
xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/cheatsheet-cabinet-acceptance \
  PRODUCT_BUNDLE_IDENTIFIER=zhouqiaaha.top.cheatsheet.cabinet-preview.acceptance \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

打开构建目录中的 `Build/Products/Debug/cheatsheet.app`。这个独立标识的 Debug 构建只使用模拟数据和命名剪贴板，关闭进程后模拟修改会重置；不启动真实剪贴板监控或自动备份。验收快捷键为 **⌘⇧⌥C**，不会占用正式 App 的 ⌘⇧C。一次只运行一个验收副本，避免快捷键互相占用。普通构建仍使用真实持久化与监控，不要用它替代隔离测试。

## 数据与项目资料

资料柜检查还会创建独立的旧版 SQLite 夹具，验证升级、删除恢复、图片与多标签备份、新旧备份格式、后台剪贴板合并以及关闭后重开。复制检查使用命名测试剪贴板。测试目录路径会输出，便于回查；不清理或修改真实用户文件。

`product-lifecycle-prompts.cheatsheet-import.json` 是可复用的分类命令示例，使用 `name` 和 `prompt` 字段。运行时的 `cheatsheet-backup-*.json` 备份文件留在本机，不进入 Git。图标正式资源位于 `cheatsheet/Assets.xcassets/AppIcon.appiconset/`，源图说明见 [图标来源](generated/app-icon/README.md)。

长期产品、流程、架构与完整历史正文从 [项目索引](.project/00-index.md) 查找。任务目标、提交范围、验证与验收结果在 [GitHub Issues](https://github.com/airsulG/cheatsheet/issues) 和 [Pull Requests](https://github.com/airsulG/cheatsheet/pulls) 中维护。
