# 网格与按需编辑面板验收

## 最新补充：卡片密度和点击收起

同日用户指出卡片留白较多，并要求点击网格空白或再次点击当前卡片收起。实现 `b672393027dba55811638a31f0dc29fbcb8662b0`：卡片高度 232→200pt，内边距 16→14pt，正文最多四→六行，图片预览 88→64pt；保留等高卡片、底部标签对齐和图片原比例。当前卡片单击切换面板，其他卡片打开/切换；背景手势只接受卡片间和底部空白，所有收起路径复用自动保存与失败保护。

隔离原生窗口实际验证：单击打开、再次点击保存并关闭，重新打开读回中文及表情；点击卡片间隙、网格底部空白关闭；最右卡片双击复制、当前卡片已打开时双击也复制且收起。窄窗口两列与宽窗口六列检查通过。Debug / Release 构建、签名检查及完整 `--cabinet` 行为检查通过，新增断言覆盖重复点击、保存失败留存、其他卡片切换及关闭后的双击复制。此次未修改基础排序/导入路径，不重复运行前轮基础检查。正式安装后也目视核对了设计标签四列布局；正式截图不上传。

| 当前场景 | 隔离模拟截图 |
| --- | --- |
| 窄窗口紧凑卡片 | ![紧凑网格](grid-images/density-grid.png) |
| 宽窗口更多正文预览 | ![宽窗口](grid-images/density-wide.png) |
| 点击底部空白后收起 | ![空白收起](grid-images/density-dismiss.png) |
| 已打开的当前卡片双击复制并收起 | ![双击当前卡片](grid-images/density-double-current.png) |

最新 Release 安装至 `/Applications/cheatsheet.app`，备份为 `~/Library/Application Support/cheatsheet-migration-backups/20260915-153234-grid`。正常退出旧版后保存完整数据、附件、偏好与旧 App；新版启动后只读逐行核对 78 个片段、20 个标签、590 条历史、78 条标签关系、1 个分组一致，全部 80 个外置文件 SHA-256 一致，永久保留偏好仍为 0。旧版可执行文件 SHA-256 为 `f58e4e0e5eaa2b15dbde3a0a8974cac2955f2a10027fe93e94afa001dc794682`，新版为 `ef0c017d5320d51a5991fae53ce97721133a5194bac6f91c4aeeca465c8879f6`。以下保留首轮网格记录，版本及数量为当时证据。

## 首轮网格记录

2026-09-15，Issue #9 / Draft PR #10，实现 checkpoint `f17b2d101874a222f922e36eea2788b91a53c71d`。Karl 的最新要求为默认平铺片段网格、单击从右侧打开编辑面板、双击仍复制。此次替代常驻三栏，保留之前的自动保存及性能修复。

## 实际窗口

使用独立 bundle ID `zhouqiaaha.top.cheatsheet.cabinet-preview.grid`、内存模拟数据及命名剪贴板。以下图片只有模拟内容，不含正式库内容。实际窗口验证了默认四列、通过系统 Move & Resize 缩窄后两列、右侧单击编辑、左右两侧双击复制、搜索收起、Esc 保存后重新打开读回中文与表情、图片比例及窄窗口底部按钮。

| 场景 | 证据 |
| --- | --- |
| 默认网格，没有常驻编辑区 | ![默认网格](grid-images/grid-default.png) |
| 单击直接编辑，卡片不重排 | ![编辑面板](grid-images/grid-editor.png) |
| 双击最右卡片，复制后回到网格 | ![复制反馈](grid-images/grid-double-right.png) |
| 缩窄后两列 | ![窄窗口网格](grid-images/grid-compact.png) |
| 窄窗口图片与编辑按钮 | ![窄窗口编辑](grid-images/grid-compact-editor.png) |

## 构建与行为检查

Xcode 27 beta，macOS，arm64。Debug 和 Release 构建成功，Release ad-hoc 签名通过 `codesign --verify --deep --strict`。通过 `scripts/verify_core_behaviors.py /tmp/cheatsheet-grid-build --cabinet` 链接真实应用对象执行检查，并开启 Core Data 并发检查；不带 `--cabinet` 的基础排序、搜索、导入与窗口输入检查也全部通过。这是项目自带的 Swift 行为检查程序，不是 XCTest target。

新增检查覆盖默认面板关闭、单击立即展开、收起保存、无效正文不能收起、搜索/导航收起、双击复制原始对象、鼠标位置与时间边界、已打开面板中的双击及空白新建取消。原有 Unicode、IME 组合输入、失焦回调、保存失败重试、后台刷新、只读原文、多标签/图片与磁盘重启检查也全部通过。本次没有重新声称点击到首帧的耗时；前轮文字布局性能数据继续保留在历史记录。

## 本机安装与数据核对

Release 已安装至 `/Applications/cheatsheet.app`。安装前正常退出旧应用，保存整份数据库目录、外置附件、偏好及旧 App 到本机备份 `~/Library/Application Support/cheatsheet-migration-backups/20260915-150021-grid`。未用早期诊断副本覆盖现有数据。

新版启动后只读逐行比较：78 个片段、20 个标签、585 条历史、78 条标签关系、1 个标签分组全部一致；78 个外置文件的 SHA-256 一致。永久保留历史的偏好仍为 0。真实窗口已显示网格且没有常驻编辑器。

旧 App 可执行文件 SHA-256：`bf865d1b681ca3fbd83eaca6706ab32ea759405ea3d0a8fad685e964ac227c44`；新 App：`f58e4e0e5eaa2b15dbde3a0a8974cac2955f2a10027fe93e94afa001dc794682`。回退前必须保护安装后新增内容；本次没有执行回退或删除备份。PR 保持 Draft，尚未合并。
