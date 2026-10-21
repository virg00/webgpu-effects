#!/usr/bin/env python3
"""Writes docs/effects.md: every effect by category, with the demo's Chinese name and description."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = f'{ROOT}/app/entry/src/main/resources/rawfile'
cat = json.load(open(f'{RAW}/catalog.json'))
zh = json.load(open(f'{RAW}/zh.json'))
rank = json.load(open(f'{RAW}/ranking.json'))
ZH = {'Shape Effects': '材质', 'Textures': '纹理', 'Interactive': '交互', 'Stylize': '风格化', 'Distortions': '扭曲',
      'Blurs': '模糊', 'Adjustments': '调色', 'Transitions': '转场', 'Shapes': '形状', 'Utilities': '工具'}
ORDER = list(ZH)
UNSUPPORTED = {'HTMLInCanvas'}
out = ['# 效果目录', '',
       f'共 {len(cat) - len(UNSUPPORTED)} 个效果（上游 {len(cat)} 个，`HTMLInCanvas` 依赖浏览器 DOM，鸿蒙上不提供）。',
       '「需要输入」表示该效果作用于之前绘制的图层（滤镜类）。每个效果都有同名的带类型工厂函数，参数见 '
       '`components.ts` 里的 `<Name>Props`。', '']
out += ['| 分类 | 数量 |', '|---|---|']
for c in ORDER:
    n = sum(1 for e in cat if e['category'] == c and e['name'] not in UNSUPPORTED)
    out.append(f'| {ZH[c]}（{c}） | {n} |')
out += ['', '## 推荐', '', '演示应用首页的排序（视觉效果最好的在前）：', '',
        '、'.join(f'`{n}`' for n in rank[:30]) + ' …', '']
for c in ORDER:
    rows = sorted((e for e in cat if e['category'] == c and e['name'] not in UNSUPPORTED), key=lambda e: e['name'])
    out += [f'## {ZH[c]}（{c}，{len(rows)}）', '', '| 效果 | 中文名 | 说明 | 需要输入 |', '|---|---|---|---|']
    for e in rows:
        t = zh.get(e['name'], [e['name'], e['description']])
        out.append(f"| `{e['name']}` | {t[0]} | {t[1]} | {'是' if e['requiresChild'] else ''} |")
    out.append('')
open(f'{ROOT}/docs/effects.md', 'w').write('\n'.join(out))
print('docs/effects.md')
