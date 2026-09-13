# 应用图标来源

`cheatsheet-icon-production-master-v1.png` 是当前图标源图，保留在版本控制中。应用实际使用的各尺寸 PNG 位于 `cheatsheet/Assets.xcassets/AppIcon.appiconset/`，以该目录的 `Contents.json` 为尺寸与倍率清单。

本目录的 `AppIcon.appiconset/`、`AppIcon.iconset/`、`AppIcon.icns` 和尺寸预览图是已有派生产物，保留在本机并由 `.gitignore` 精确排除。修改正式图标时，需要同时核对源图和应用资源；不能只修改这里的派生文件。
