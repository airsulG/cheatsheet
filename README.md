# cheatsheet

一个本地 macOS 命令片段和剪贴板工具。底部横条可以浏览剪贴板历史、收藏与分类命令，点击卡片复制内容；分类命令支持 JSON 导入，统一设置窗口提供排序、剪贴板保留与备份功能。

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
```

使用自定义 `DEVELOPER_DIR` 构建时，验证命令也应使用同一路径。脚本链接本机架构的 Debug 应用对象，排除 App 启动入口，使用独立内存数据库，并打开 Core Data 并发检查。它验证拖动交换、标题排序、保存回读、标题与完整正文搜索、子 ViewModel 刷新、备份导入回读、面板文字输入和 JSON 示例导入。

脚本不启动剪贴板监控，不修改真实数据库或系统剪贴板。窗口输入检查会短暂显示一个测试输入框。它不能替代完整 SwiftUI 界面、中文输入法、拖拽手感和长时间运行的体验验收。`cheatsheetTests/` 保留已有 XCTest 文件，当前 Xcode 工程尚未配置测试 target；不能把构建成功视为这些 XCTest 已执行。

## 数据与项目资料

`product-lifecycle-prompts.cheatsheet-import.json` 是可复用的分类命令示例，使用 `name` 和 `prompt` 字段。运行时的 `cheatsheet-backup-*.json` 备份文件留在本机，不进入 Git。图标正式资源位于 `cheatsheet/Assets.xcassets/AppIcon.appiconset/`，源图说明见 [图标来源](generated/app-icon/README.md)。

长期产品、流程、架构与完整历史正文从 [项目索引](.project/00-index.md) 查找。任务目标、提交范围、验证与验收结果在 [GitHub Issues](https://github.com/airsulG/cheatsheet/issues) 和 [Pull Requests](https://github.com/airsulG/cheatsheet/pulls) 中维护。
