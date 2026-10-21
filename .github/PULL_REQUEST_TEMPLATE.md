## 这个 PR 做了什么

<!-- 一句话说明；标题请用 Conventional Commits：feat|fix|perf|refactor|docs|test|build|chore -->

## 关联

- Closes #

## 类型

- [ ] 缺陷修复
- [ ] 运行时 / WebGPU 实现
- [ ] 上游同步
- [ ] 演示应用
- [ ] 文档
- [ ] 其他：

## 验证（运行时 / 效果类改动必填）

- [ ] 已在真机运行，注明机型与系统版本：
- [ ] 受影响的效果已用 `scripts/test-fx.sh` 截图核对；涉及引擎或 WebGPU 实现时已跑 `scripts/sweep.sh`
- [ ] 无新增 `uncaptured` / `render error` 日志

## 溯源自检

- [ ] 未手改 `engine/bundle.js`、`components.ts`、`catalog.json` 等生成文件（改生成脚本并重新生成）
- [ ] 新引入的第三方代码已在 `THIRD_PARTY_NOTICES.md` 登记并保留原许可
- [ ] 项目名 / 包名 / 标识未使用上游品牌词（见 `docs/provenance-and-naming.md`）
