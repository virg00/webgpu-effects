# 签名与真机测试

## 签名

仓库里的 `app/build-profile.json5` **不含签名配置**，`scripts/build.sh` 默认构建未签名的 `default` 产品。

在真机上运行需要签名。推荐用 DevEco Studio 的 **File → Project Structure → Signing Configs → Automatically generate signature**
（登录华为账号后自动申请调试证书）。如果不想改动仓库里的 `build-profile.json5`，可以把签名放到本地文件
`app/signing.local.json`（已在 `.gitignore` 中），`PRODUCT=<名字> scripts/build.sh` 会在构建时临时合并进来：

```json
{
  "products": [
    { "name": "devtest", "signingConfig": "devtest", "bundleName": "<与调试证书匹配的包名>",
      "targetSdkVersion": "6.1.1(24)", "compatibleSdkVersion": "6.1.1(24)", "runtimeOS": "HarmonyOS", "buildOption": { "strictMode": { "useNormalizedOHMUrl": true } } }
  ],
  "signingConfigs": [
    { "name": "devtest", "type": "HarmonyOS", "material": {
        "certpath": "…/xxx.cer", "keyAlias": "debugKey", "keyPassword": "…", "profile": "…/xxx.p7b",
        "signAlg": "SHA256withECDSA", "storeFile": "…/xxx.p12", "storePassword": "…" } }
  ]
}
```

> 证书、私钥与口令**不要提交**。

## 测试脚本

所有脚本读取 `HDC_TARGET`（`hdc list targets` 中的设备号）与 `PRODUCT`：

```bash
PRODUCT=devtest scripts/build.sh                                       # 构建签名 HAP
PRODUCT=devtest HDC_TARGET=<设备> scripts/run.sh                        # 安装并启动演示应用
PRODUCT=devtest HDC_TARGET=<设备> scripts/test-fx.sh Glass              # 单个效果：截图 + 日志 → build/fx
PRODUCT=devtest HDC_TARGET=<设备> scripts/sweep.sh build/sweep          # 全部效果逐个截图（锁屏时自动等待）
PRODUCT=devtest HDC_TARGET=<设备> scripts/compare-bench.sh build/compare # 与 shaderport 的性能对比
python3 -I scripts/build-compare-report.py build/compare               # 生成演示应用的对比报告
scripts/crash.sh                                                       # 最近一次原生崩溃，符号化 libwebgpu_effects.so 帧
scripts/logs.sh                                                        # 最近的引擎 / GPU 日志
```

测试期间请保持设备解锁；演示应用会保持屏幕常亮。
