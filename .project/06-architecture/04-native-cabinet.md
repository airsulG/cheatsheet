# 原生资料柜

关联 [Issue #7](https://github.com/airsulG/cheatsheet/issues/7)。基线 main 0e4cfff，实施分支 codex/native-cabinet。主界面使用 SwiftUI，AppKit 管理窗口、磨砂、焦点及文本输入；继续复用剪贴板监控、快捷键、导入与设置。

## 数据兼容的决定

保留旧 CoreData 模型版本，以新增模型实现多标签。Category 的存储名称保留以兼容旧数据，产品中称为标签；新增 Command.tags 多对多关联、标签分组、删除恢复状态、片段图片与剪贴板来源。原有 category 关联保留供旧导入与兼容读取，新增片段以 tags 为准。旧 category 首次补入 tags，补入状态随片段持久化，避免取消标签后又被旧关联自动加回。

删除标签只标记为已删除，不调用旧级联删除路径；删除组保留恢复依据。新备份覆盖无标签片段、多标签、图片、分组和恢复状态，并可导入旧版本。验证使用隔离数据库和命名测试剪贴板，禁止将真实用户数据当测试夹具。

## 原生与网页的差异

模型版本名为 cheatsheetV2.xcdatamodel。当前 Xcode 同步文件夹会重新选择按名称排在末尾的模型，因此新版本按此命名，同时显式登记 XCVersionGroup 和 .xccurrentversion。Apple DTS 已确认此类问题并认可命名办法：https://developer.apple.com/forums/thread/779939?page=2 。构建后与迁移检查一起验证实际当前模型，不只看配置文字。

网页颜色、空间关系和交互是参考；原生材质使用 NSVisualEffectView，窗口可调整大小，实际快捷键仍由 macOS 响应者处理。不照搬网页模拟桌面或蓝灰/暖灰对照控件。验收需原生构建、存储行为检查及实际窗口截图，不能用网页截图替代。
