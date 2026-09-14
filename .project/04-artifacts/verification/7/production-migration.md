# 正式数据迁移与安装

2026-09-14，Issue #7 / PR #8。Karl 明确授权新版接替旧版，保留旧 App 和迁移前备份，并选择剪贴板“永久保留”。没有获得 GitHub 合并或对外发布授权。App 源码为 5e17493（构建时 HEAD ebb534e，后者仅文档），本轮新增验证工具最终为 e6cb3ab；没有为这次迁移改写产品数据模型或创建第二套运行数据库。

## 实际执行

旧 App 界面连接多次超时，因此向确认的旧进程发送 TERM，确认进程退出后才复制完整数据库目录。最初观察 523 条历史，停止时新增至 524 条，最终以停止后的快照为准。备份包含 SQLite、WAL/SHM、.cheatsheet_SUPPORT 外置附件、旧偏好、旧 App，设在本机私有备份目录；不提交真实正文、截图、图片或数据库到 GitHub。

副本由工具复制到一个必须不存在的新目录，再通过 Core Data 轻量迁移及真实 CabinetStore.migrateLegacyTags 升级。逐项对比旧实体全部属性、关系、ID、正文、时间、排序、常用与来源字段；二进制内容使用 SHA-256，实际解码所有历史图片。副本关闭重开后再次对比。

迁移前核对旧保留偏好未设置，新版默认 7 天会清理 114 条更早历史。经 Karl 单独确认，将原沙盒偏好设为 0（永久保留），正式设置窗口验证显示“永久保留”，清理过期按钮禁用。

将旧 /Applications/cheatsheet.app 移至备份目录，再把新 Release 构建放到原路径，保留旧 App 可恢复。签名检查通过；新版沿用原 bundle ID 及原沙盒数据库。启动后显示 70 个片段、19 个标签、524 条历史；完全退出，确认正式进程消失，对正式数据库执行只读比较，再重新启动仍显示相同数量。最后从计算器按正式快捷键 ⌘⇧C 成功唤回资料柜。模拟验收进程已退出，不与正式版混用。

## 命令与结果

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Release \
  -destination 'platform=macOS' -derivedDataPath /tmp/cheatsheet-cabinet-production \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build

codesign --verify --deep --strict /Applications/cheatsheet.app

# 以下路径为本机私有目录参数，不应复制用户数据到仓库。
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
python3 scripts/verify_store_migration.py /tmp/cheatsheet-cabinet-sidebar \
  "$OLD_STORE_SNAPSHOT" "$NEW_VERIFICATION_COPY"

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
python3 scripts/verify_store_migration.py /tmp/cheatsheet-cabinet-sidebar \
  "$OLD_STORE_SNAPSHOT" "$LIVE_STORE_DIRECTORY" --compare-current
```

Release BUILD SUCCEEDED；签名、迁移副本及正式库只读检查均退出 0。

```text
PASS: every legacy attribute and relationship unchanged; counts Category=19, Command=70, ClipboardItem=524
PASS: all legacy category links available as tags; image records 79, decodable 79
PASS: migrated disk store closes and reopens without changing original values
PASS: current store read-only comparison preserves all original records; current counts Category=19, Command=70, ClipboardItem=524
```

安装执行文件 SHA-256：`7c58d8c2358916499cf9447959bf2cab9542bea4d36f0c81ad225d43ea6f7e49`。本机日志为 `/tmp/cheatsheet-cabinet-production.log`、`/tmp/cheatsheet-real-migration.log`、`/tmp/cheatsheet-live-data-check.log`。原始备份的主库、WAL、外置附件与旧 App 哈希未变；只读 SQLite 打开会改变 SHM 共享内存索引，不计为业务数据变化，初始哈希与说明仍保留。

## 回退与限制

备份位于用户 Library/Application Support/cheatsheet-migration-backups/20260914-215254，内含 README.md 与文件哈希清单。不要直接启动备份里的旧 App，它会访问已经升级的同一沙盒。回退要先保存新版新增内容，再同时恢复旧 App、原始数据库与偏好；这会回到迁移快照，不能无提示覆盖迁移后数据。本次没有执行回退。

真实数据已读回并重启恢复，没有写入额外测试片段，也没有为验证复制而改写用户系统剪贴板。没有进行完整回退演练、独立 Review、远端 CI 或大量数据性能测量；既有模拟能力仍保留，底层回归检查沿用 4f0ec4d，本轮增加的是实际旧库副本及正式库比较。PR 仍未合并。
