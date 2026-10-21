# 贡献指南

感谢参与。最有价值的贡献依次是：**设备兼容性反馈 → 缺陷修复 → 性能 → 文档**。

## 开始之前

- **缺陷**：开 issue 并附：
  - 效果名与参数（或最小的 `layers` 代码）；
  - 设备型号 / HarmonyOS 版本；
  - 现象（截图或录屏）与 `scripts/logs.sh` 的输出；崩溃请附 `scripts/crash.sh` 的输出。
- **设备兼容性**：在新设备上跑一遍 `scripts/sweep.sh`，把 `summary.tsv` 贴到 issue，我们会补进 [设备矩阵](docs/device-matrix.md)。
- **新功能 / 行为变更**：先开 issue 讨论。
- 小修（错别字、注释、明显的一行错误）可直接提 PR。

## 生成文件不要手改

以下文件由脚本生成，改动请修改生成脚本后重新生成：

| 文件 | 生成方式 |
|---|---|
| `app/webgpu-effects/src/main/ets/engine/bundle.js` | `scripts/sync-upstream.sh`（`patch-bundle.mjs`） |
| `app/webgpu-effects/src/main/ets/components/components.ts`、演示应用 `catalog.json` | `scripts/gen-components.mjs` |
| `docs/effects.md` | `scripts/gen-effects-doc.py` |
| 演示应用 `compare-report.json` | `scripts/build-compare-report.py` |
| `THIRD_PARTY_NOTICES.md` | `scripts/gen-notices.py`（升级上游或 wgpu 后必须重跑） |

## 验证

运行时（`runtime.js`、`webgpu.js`、`gpu.cpp`）或引擎补丁的改动，需在真机上跑 `scripts/sweep.sh` 确认没有新增失败；
只影响个别效果的改动，用 `scripts/test-fx.sh <效果名>` 截图核对即可。模拟器结果不作为依据。

## 提交规范

采用 [Conventional Commits](https://www.conventionalcommits.org/)：

```
fix(webgpu): keep surface texture alive until present
feat(runtime): support VideoTexture from file:// urls
docs: add Mate 70 to device matrix
```

## 许可

提交即表示同意你的贡献按 [MIT](LICENSE) 授权。引入第三方代码需保留其许可，并重新生成 `THIRD_PARTY_NOTICES.md`。
