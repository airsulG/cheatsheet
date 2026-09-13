# cheatsheet 项目索引

这里保存长期产品事实和历史材料入口。当前仓库整理与交付进度以 [Issue #5](https://github.com/airsulG/cheatsheet/issues/5) 及其关联 PR 为准；下面的任务记录保留此前的方案、执行证据和待验收项，不作为新任务队列。

<<<<<<<<<<<<<<<<<<<< 00 Project Fact Map <<<<<<<<<<<<<<<<<<<<

长期产品、流程与架构事实保存在下方对应目录。两代 agent-loop 文档保留完整历史；新任务在 GitHub Issue / PR 中记录目标、执行结果与验收。

| Layer | Path | Current Role | Status |
|---|---|---|---|
| Product | `.project/01-product/PRODUCT.md` | Stable product facts and long-lived rules | partial |
| Requirements | `.project/02-requirements/` | Candidate and approved requirements | empty |
| Feature Flow | `.project/03-feature-flow/` | User actions, feedback, and real object changes | partial |
| Interface Model | `.project/04-interface-model/` | Components, states, events, and data ownership | partial |
| Visual System | `.project/05-visual-system/` | Long-lived visual rules | empty |
| Architecture | `.project/06-architecture/` | Technical boundaries and implementation mapping | partial |
| Agent Loop | `.project/07-agent-loop/` | 历史方案、执行证据与待验收项 | archived_history |
| QA | `.project/08-qa/` | Manual QA and regression evidence | empty |
| Docs | `.project/09-docs/` | 旧 PRD 完整正文与来源说明 | archived_history |

<<<<<<<<<<<<<<<<<<<< 01 已实现、待体验验收的功能 <<<<<<<<<<<<<<<<<<<<

| Task | Authority | Goal | Status |
|---|---|---|---|
| Shelf command import | `.project/07-agent-loop/15-shelf-command-import.md` | Expose the existing JSON command import path inside the bottom Shelf panel | awaiting_user_acceptance |
| Shelf live command refresh | `.project/07-agent-loop/16-shelf-live-command-refresh.md` | Make Shelf update immediately after command create/edit/import without tab switching | awaiting_user_acceptance |
| App settings route | `.project/07-agent-loop/17-app-settings-route.md` | Merge backup and clipboard cleanup settings into one global settings window route | awaiting_user_acceptance |

<<<<<<<<<<<<<<<<<<<< 02 Legacy Sources <<<<<<<<<<<<<<<<<<<<

Legacy task history remains under `.project/agent-loop/`. Do not add new tasks there unless explicitly migrating legacy state. Runtime backup files named `cheatsheet-backup-*.json` are generated artifacts and should not be committed.

五份原 `PRD/` 文档的完整正文保存在 [旧 PRD 归档](09-docs/legacy-prd/README.md)，不以摘要替代。可重复使用的 [命令导入示例](../product-lifecycle-prompts.cheatsheet-import.json) 使用 `name` / `prompt` 字段，导入到你当前选中的分类；它不是运行时备份。
