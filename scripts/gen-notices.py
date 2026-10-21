#!/usr/bin/env python3
"""Regenerate THIRD_PARTY_NOTICES.md from what actually ships in the HAR.

- JavaScript: the upstream `shaders` npm package and every package its bundle inlines (installed into a temp dir).
- Native: every Rust crate linked into libwebgpu_effects.so (cargo metadata of native/wgpu-native for
  aarch64-unknown-linux-ohos, normal dependencies only, proc-macro crates and their build-time deps skipped),
  plus the WebGPU headers and the NDK's libc++.

Each component's own license file is embedded (with its copyright line); for dual/multi-licensed crates the
first of MIT, BSD-2-Clause, Zlib, ISC, BSD-3-Clause, Apache-2.0 that the crate offers is used.

Usage: python3 -I scripts/gen-notices.py      (needs cargo + the native/wgpu-native checkout, and npm)
"""
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NPM_BUNDLED = ['shaders', 'typegpu', 'tinyest', 'typed-binary', 'tsover-runtime']
PREFERENCE = ['MIT', 'BSD-2-Clause', 'Zlib', 'ISC', 'BSD-3-Clause', 'Apache-2.0', 'CC0-1.0']
FILE_HINT = {'MIT': 'MIT', 'BSD-2-Clause': 'BSD', 'Zlib': 'ZLIB', 'ISC': 'LICENSE', 'BSD-3-Clause': 'LICENSE',
             'Apache-2.0': 'APACHE', 'CC0-1.0': 'LICENSE', 'Unicode-3.0': 'UNICODE'}

MIT_TEMPLATE = """Copyright (c) {holders}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."""


def read(path):
    with open(path, encoding='utf-8', errors='replace') as f:
        return f.read().strip('\n')


def license_files(d):
    return sorted(f for f in glob.glob(os.path.join(d, '*'))
                  if os.path.isfile(f) and re.search(r'LICEN[CS]E|COPYING|COPYRIGHT|NOTICE', os.path.basename(f), re.I))


def choose(expr):
    """SPDX expression → list of licenses to comply with (one per AND term)."""
    expr = expr.replace('/', ' OR ')
    terms = [t.strip(' ()') for t in re.split(r'\)\s*AND\s*\(|\s+AND\s+', expr)]
    out = []
    for t in terms:
        opts = [o.strip(' ()') for o in t.split(' OR ')]
        out.append(next((p for p in PREFERENCE if p in opts), opts[0]))
    return out


def pick_file(files, lic):
    hint = FILE_HINT.get(lic, 'LICENSE')
    named = [f for f in files if hint in os.path.basename(f).upper() and 'NOTICE' not in os.path.basename(f).upper()]
    if named:
        return named[0]
    plain = [f for f in files if re.fullmatch(r'(LICEN[CS]E|COPYING)(\.(txt|md))?', os.path.basename(f), re.I)]
    return plain[0] if len(files) <= 2 and plain else None


def cargo_crates():
    meta = json.loads(subprocess.check_output(
        ['cargo', 'metadata', '--format-version', '1', '--offline', '--filter-platform', 'aarch64-unknown-linux-ohos'],
        cwd=os.path.join(ROOT, 'native', 'wgpu-native'), stderr=subprocess.DEVNULL))
    pk = {p['id']: p for p in meta['packages']}
    nodes = {n['id']: n for n in meta['resolve']['nodes']}
    seen, stack = set(), [meta['resolve']['root']]
    while stack:
        i = stack.pop()
        if i in seen:
            continue
        seen.add(i)
        for d in nodes[i]['deps']:
            dep = pk[d['pkg']]
            if any(k['kind'] is None for k in d['dep_kinds']) and \
                    not any('proc-macro' in t['kind'] for t in dep['targets']):
                stack.append(d['pkg'])
    out = []
    for i in seen:
        p = pk[i]
        if p['name'] in ('wgpu-native',):
            continue
        out.append(p)
    return sorted(out, key=lambda p: (p['name'], p['version']))


def npm_packages():
    tmp = tempfile.mkdtemp()
    version = read(os.path.join(ROOT, 'upstream', 'VERSION'))
    subprocess.check_call(['npm', 'init', '-y'], cwd=tmp, stdout=subprocess.DEVNULL)
    subprocess.check_call(['npm', 'install', '--ignore-scripts', '--no-audit', '--no-fund',
                           '--registry=https://registry.npmjs.org', f'shaders@{version}'],
                          cwd=tmp, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    out = []
    for name in NPM_BUNDLED:
        d = os.path.join(tmp, 'node_modules', name)
        j = json.load(open(os.path.join(d, 'package.json')))
        repo = j.get('repository')
        repo = repo.get('url') if isinstance(repo, dict) else repo
        out.append({'name': name, 'version': j['version'], 'license': j['license'], 'dir': d,
                    'repo': (repo or '').replace('git+', '').removesuffix('.git')})
    return out


def main():
    npm = npm_packages()
    crates = cargo_crates()
    texts = {}  # text → [component, ...]
    apache_users = []
    rows = []

    def add(label, lic, files, authors):
        if lic == 'Apache-2.0':
            apache_users.append(label)
            for f in files:
                if 'NOTICE' in os.path.basename(f).upper():
                    texts.setdefault(read(f), []).append(label + ' (NOTICE)')
            return
        if lic == 'CC0-1.0':
            return
        f = pick_file(files, lic)
        if f:
            text = read(f)
        elif lic == 'MIT':
            text = MIT_TEMPLATE.format(holders=', '.join(authors) or f'the {label} authors')
        else:
            raise SystemExit(f'no {lic} license text for {label}')
        texts.setdefault(text, []).append(label)

    for p in npm:
        label = f"{p['name']}@{p['version']}"
        rows.append(('js', p['name'], p['version'], p['license'], p['license'], p['repo']))
        for lic in choose(p['license']):
            add(label, lic, license_files(p['dir']), [])
    for c in crates:
        label = f"{c['name']} {c['version']}"
        chosen = choose(c['license'])
        rows.append(('rs', c['name'], c['version'], c['license'], ' AND '.join(chosen), c.get('repository') or ''))
        for lic in chosen:
            add(label, lic, license_files(os.path.dirname(c['manifest_path'])),
                [re.sub(r'\s*<[^>]*>', '', a) for a in c.get('authors') or []])
    headers = os.path.join(ROOT, 'native', 'wgpu-native', 'ffi', 'webgpu-headers', 'LICENSE')
    texts.setdefault(read(headers), []).append('webgpu-headers (webgpu.h)')
    apache = read(os.path.join(ROOT, 'native', 'wgpu-native', 'LICENSE.APACHE'))

    L = [
        '# Third-party notices',
        '',
        '<!-- GENERATED by scripts/gen-notices.py — do not edit by hand. -->',
        '',
        '`@virg00/webgpu-effects` 本身按 MIT 授权（见 `LICENSE`）。发布的 HAR 中包含下列第三方组件，'
        '各自保留原许可；本文件随包分发（并入包内 `LICENSE`），满足各许可"随副本保留版权与许可声明"的要求。',
        '',
        '`webgpu-effects` is an independent project. It is not affiliated with, endorsed by, or sponsored by '
        'Shader Effects Inc. or the `shader-effects-inc/shaders` project.',
        '',
        '## 1. JavaScript：上游引擎及其内联依赖',
        '',
        '上游 `shaders` npm 包的 `dist/js/bundle.js` 以修改后的形式（见下文"修改说明"）作为 '
        '`src/main/ets/engine/bundle.js` 打包进 HAR；该 bundle 内联了下表中的依赖。'
        '`components.ts` 中的效果名、参数与默认值由上游效果注册表生成。',
        '',
        '| 包 | 版本 | 许可 | 源码 |',
        '|---|---|---|---|',
    ]
    L += [f'| {n} | {v} | {lic} | {r} |' for k, n, v, lic, _, r in rows if k == 'js']
    L += [
        '',
        '## 2. 原生库：`libwebgpu_effects.so`',
        '',
        '由本项目的 `gpu.cpp` 与 [wgpu-native](https://github.com/gfx-rs/wgpu-native) 静态链接而成。'
        '下表是链接进该库的全部 Rust crate（构建期专用的过程宏 crate 不在其中）。多许可的 crate 选用"采用"列中的许可。',
        '',
        '| crate | 版本 | 许可 | 采用 |',
        '|---|---|---|---|',
        '| wgpu-native | 589e6ca（含本项目补丁） | MIT OR Apache-2.0 | MIT |',
    ]
    L += [f'| {n} | {v} | {lic} | {ch} |' for k, n, v, lic, ch, _ in rows if k == 'rs']
    L += [
        '',
        '另含 [webgpu-headers](https://github.com/webgpu-native/webgpu-headers)（`webgpu.h`，BSD-3-Clause）。',
        '',
        'HAR 中的 `libc++_shared.so` 来自 HarmonyOS NDK（LLVM libc++，Apache-2.0 WITH LLVM-exception；'
        '该例外豁免了以二进制形式再分发时的署名要求）。',
        '',
        '## 3. 修改说明',
        '',
        '- `bundle.js`：由 `scripts/patch-bundle.mjs` 生成。(1) 规避方舟运行时"私有成员赋值表达式求值为 `true`"的缺陷，'
        '把约 10 处赋值表达式改写为等价的逗号表达式；(2) 把 60 fps 帧率上限改为可配置。其余内容与上游一致。',
        '- `wgpu-hal`：`native/wgpu-hal-ohos.patch`（VK_OHOS_surface、`libvulkan.so` 加载名、模拟器驱动兼容处理）。',
        '- `wgpu-native`：`native/wgpu-native-ohos.patch`（panic 转日志回调；submit / configure 错误改为校验错误）。',
        '',
        '## 4. 仅在源码仓库中（不进 HAR）',
        '',
        '| 组件 | 位置 | 许可 |',
        '|---|---|---|',
        '| shaderport 0.1.0（quizzyjoy/shaderport）HAR 与参考 GLES 渲染器，仅供演示应用的对比页 | '
        '`app/shaderport`、`app/entry/src/main/cpp/shaderport` | Apache-2.0 — `app/shaderport/LICENSE`、`app/shaderport/NOTICE`；'
        '修改过的文件在文件头注明了修改内容 |',
        '| 上游 `shaders` 原始 bundle 与效果注册表 | `upstream/` | MIT — `upstream/LICENSE` |',
        '',
        '## 5. 许可全文',
        '',
    ]
    for text, users in texts.items():
        L += ['### ' + ', '.join(users), '', '```', text, '```', '']
    L += ['### Apache License 2.0', '', '适用于：' + ', '.join(apache_users) + '。', '', '```', apache, '```', '']
    with open(os.path.join(ROOT, 'THIRD_PARTY_NOTICES.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(L))
    print(f'{len(npm)} npm packages, {len(crates)} crates, {len(texts)} distinct license texts', file=sys.stderr)


if __name__ == '__main__':
    main()
