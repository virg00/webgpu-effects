#!/usr/bin/env python3
"""Builds rawfile/compare-report.json (+ shaderport thumbnails) from scripts/compare-bench.sh output.

  python3 -I scripts/build-compare-report.py build/compare

For every effect both ports share: FPS / CPU ms / first frame / PSS from the single-side runs, and
the mean colour difference between the two full-screen screenshots (meaningful for static effects;
animated ones differ by construction because the two clocks are not synchronised).
"""
import glob, json, os, struct, subprocess, sys, tempfile, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1]
RAW = f'{ROOT}/app/entry/src/main/resources/rawfile'
SPECS = {json.load(open(f))['name']: json.load(open(f))
         for f in glob.glob(f'{ROOT}/app/shaderport/src/main/resources/rawfile/effects/*/spec.json')}

runs = {}
for line in open(f'{OUT}/bench.jsonl'):
    r = json.loads(line)
    run = r['run']
    if run.get('missing'):
        continue
    side = run['mode']
    runs.setdefault(run['name'], {})[side] = dict(run['claude' if side == 'claude' else 'port'], pssKb=r['pssKb'])


# Optional second run with a finger moving (TOUCH=1): LTPO screens switch to 120 Hz.
touch = {}
tpath = f'{os.path.dirname(OUT.rstrip("/"))}/compare-touch/bench.jsonl'
if os.path.exists(tpath):
    for line in open(tpath):
        r = json.loads(line)['run']
        if not r.get('missing'):
            touch.setdefault(r['name'], {})[r['mode']] = r['claude' if r['mode'] == 'claude' else 'port']['fps']


def pixels(path, w=72, h=156):
    tmp = tempfile.mktemp(suffix='.bmp')
    # Same crop as the menu thumbnails: drop the status bar and the bottom controls.
    subprocess.run(['sips', '-c', '1500', '1140', path, '--out', tmp], capture_output=True, check=True)
    subprocess.run(['sips', '-z', str(h), str(w), '-s', 'format', 'bmp', tmp, '--out', tmp], capture_output=True, check=True)
    d = open(tmp, 'rb').read()
    os.unlink(tmp)
    off = struct.unpack_from('<I', d, 10)[0]
    bw, bh = struct.unpack_from('<ii', d, 18)
    bpp = struct.unpack_from('<H', d, 28)[0] // 8
    row = (bw * bpp + 3) & ~3
    return [d[off + y * row + x * bpp: off + y * row + x * bpp + 3] for y in range(abs(bh)) for x in range(bw)]


def diff(a, b):
    pa, pb = pixels(a), pixels(b)
    return sum(abs(x[i] - y[i]) for x, y in zip(pa, pb) for i in range(3)) / (len(pa) * 3 * 255) * 100


def view_pixels(path, phone, w=60, h=80):
    """Pixels of the shader view's middle band (no badges, no controls), resampled to w x h."""
    tmp = tempfile.mktemp(suffix='.bmp')
    subprocess.run(['sips', '-s', 'format', 'bmp', path, '--out', tmp], capture_output=True, check=True)
    d = open(tmp, 'rb').read()
    os.unlink(tmp)
    off = struct.unpack_from('<I', d, 10)[0]
    bw, bh = struct.unpack_from('<ii', d, 18)
    bpp = struct.unpack_from('<H', d, 28)[0] // 8
    row = (bw * bpp + 3) & ~3
    H = abs(bh)
    top, bottom = (116, 2356) if phone else (0, H)   # phone: below the status bar, above the nav bar
    vh = bottom - top
    y0, y1 = top + int(vh * 0.12), top + int(vh * 0.78)
    out = []
    for j in range(h):
        y = y0 + int((j + 0.5) * (y1 - y0) / h)
        yy = (H - 1 - y) if bh > 0 else y
        for i in range(w):
            x = int((i + 0.5) * bw / w)
            o = off + yy * row + x * bpp
            out.append(d[o:o + 3])
    return out


def diff_view(a, b):
    pa, pb = view_pixels(a, False), view_pixels(b, True)
    return sum(abs(x[i] - y[i]) for x, y in zip(pa, pb) for i in range(3)) / (len(pa) * 3 * 255) * 100


REFS = f'{ROOT}/build/upstream-ref/refs'


def write_triplet_ref(n):
    """The compared band (12%–78% of the view) of the upstream original, for the Analysis page."""
    w = int(subprocess.run(['sips', '-g', 'pixelWidth', f'{REFS}/{n}.png'], capture_output=True, text=True).stdout.split()[-1])
    h = int(subprocess.run(['sips', '-g', 'pixelHeight', f'{REFS}/{n}.png'], capture_output=True, text=True).stdout.split()[-1])
    tmp = tempfile.mktemp(suffix='.png')
    subprocess.run(['sips', '--cropOffset', str(int(h * 0.12)), '0', '-c', str(int(h * 0.66)), str(w), f'{REFS}/{n}.png',
                    '--out', tmp], capture_output=True)
    subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '75', '-Z', '300', tmp,
                    '--out', f'{RAW}/fidelity/{n}-ref.jpg'], capture_output=True)
    os.unlink(tmp)


def write_triplet_side(n, side):
    """Same band of the phone screenshot (view = y 116..2356)."""
    tmp = tempfile.mktemp(suffix='.jpeg')
    subprocess.run(['sips', '--cropOffset', str(116 + int(2240 * 0.12)), '0', '-c', str(int(2240 * 0.66)), '1140',
                    f'{OUT}/{n}-{side}.jpeg', '--out', tmp], capture_output=True)
    subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '75', '-Z', '300', tmp,
                    '--out', f'{RAW}/fidelity/{n}-{side}.jpg'], capture_output=True)
    os.unlink(tmp)

ANIMATED = {'Aurora', 'BlockNoise', 'DotGrid', 'FlowingGradient', 'Marble', 'MeshGradient', 'PerlinNoise', 'Plasma',
            'Ripples', 'SimplexNoise', 'SineWave', 'Spiral', 'Stripes', 'CursorRipples'}

os.makedirs(f'{RAW}/port-thumbs', exist_ok=True)
bench = []
for name in sorted(runs):
    r = runs[name]
    if 'claude' not in r or 'port' not in r:
        continue
    c_img, p_img = f'{OUT}/{name}-claude.jpeg', f'{OUT}/{name}-port.jpeg'
    d = None
    if os.path.exists(c_img) and os.path.exists(p_img):
        d = round(diff(c_img, p_img), 2)
        # Thumbnails of both sides as compared (same base, same defaults), cropped like the menu ones
        os.makedirs(f'{RAW}/cmp-thumbs', exist_ok=True)
        tmp = tempfile.mktemp(suffix='.jpeg')
        subprocess.run(['sips', '-c', '1800', '1140', c_img, '--out', tmp], capture_output=True)
        subprocess.run(['sips', '-Z', '360', '-s', 'format', 'jpeg', '-s', 'formatOptions', '72', tmp, '--out',
                        f"{RAW}/cmp-thumbs/{name}.jpg"], capture_output=True)
        os.unlink(tmp)
        tmp = tempfile.mktemp(suffix='.jpeg')
        subprocess.run(['sips', '-c', '1800', '1140', p_img, '--out', tmp], capture_output=True)
        subprocess.run(['sips', '-Z', '360', '-s', 'format', 'jpeg', '-s', 'formatOptions', '72', tmp, '--out',
                        f"{RAW}/port-thumbs/{SPECS[name]['id']}.jpg"], capture_output=True)
        os.unlink(tmp)
    animated = name in ANIMATED or bool((SPECS[name].get('base') or {}).get('id'))
    ref = f'{REFS}/{name}.png'
    vs_ref = None
    if not animated and os.path.exists(ref) and os.path.exists(c_img) and os.path.exists(p_img):
        vs_ref = {'claude': round(diff_view(ref, c_img), 2), 'port': round(diff_view(ref, p_img), 2)}
    bench.append({
        'name': name, 'animated': animated, 'diffPct': d, 'vsUpstream': vs_ref, 'base': (SPECS[name].get('base') or {}).get('id', ''),
        'claude': dict({k: r['claude'][k] for k in ('fps', 'cpuMs', 'firstFrameMs', 'ok', 'pssKb')},
                       fpsTouch=touch.get(name, {}).get('claude')),
        'port': dict({k: r['port'][k] for k in ('fps', 'cpuMs', 'firstFrameMs', 'ok', 'pssKb')},
                     fpsTouch=touch.get(name, {}).get('port')),
    })


def avg(side, key, rows=None):
    rows = [b for b in (rows or bench) if b['claude']['ok'] and b['port']['ok']]
    return sum(b[side][key] for b in rows) / max(1, len(rows))


static = [b for b in bench if not b['animated'] and b['diffPct'] is not None]
refd = [b for b in bench if b.get('vsUpstream')]
ref_c = sum(b['vsUpstream']['claude'] for b in refd) / max(1, len(refd))
ref_p = sum(b['vsUpstream']['port'] for b in refd) / max(1, len(refd))
close_c = sum(1 for b in refd if b['vsUpstream']['claude'] < 3)
close_p = sum(1 for b in refd if b['vsUpstream']['port'] < 3)
os.makedirs(f'{RAW}/fidelity', exist_ok=True)
for b in refd:
    n = b['name']
    # Triplet for the Analysis page: upstream original | Claude | shaderport (view area only).
    write_triplet_ref(n)
    for side in ('claude', 'port'):
        write_triplet_side(n, side)
    print(f"  vs upstream {b['name']:24s} claude {b['vsUpstream']['claude']:6.2f}%  port {b['vsUpstream']['port']:6.2f}%")
print(f'vs upstream over {len(refd)} static effects: claude {ref_c:.2f}% port {ref_p:.2f}%; within 3%: {close_c} / {close_p}')
json.dump({'bench': bench, 'avg': {s: {k: avg(s, k) for k in ('fps', 'cpuMs', 'firstFrameMs', 'pssKb')} for s in ('claude', 'port')},
           'staticDiffAvg': sum(b['diffPct'] for b in static) / max(1, len(static)),
           'date': datetime.date.today().isoformat()},
          open(f'{OUT}/measurements.json', 'w'), indent=1, ensure_ascii=False)
print(f"{len(bench)} effects; avg fps claude {avg('claude', 'fps'):.1f} port {avg('port', 'fps'):.1f}; "
      f"cpu {avg('claude', 'cpuMs'):.2f} / {avg('port', 'cpuMs'):.2f} ms; pss {avg('claude', 'pssKb')/1024:.0f} / {avg('port', 'pssKb')/1024:.0f} MB; "
      f"static diff {sum(b['diffPct'] for b in static) / max(1, len(static)):.2f}% over {len(static)}")

# ── assemble rawfile/compare-report.json for the Analysis page ─────────────────────────────
notes = json.load(open(f'{ROOT}/scripts/compare-notes.json'))
ok = [b for b in bench if b['claude']['ok'] and b['port']['ok']]
a = {s: {k: avg(s, k) for k in ('fps', 'cpuMs', 'firstFrameMs', 'pssKb')} for s in ('claude', 'port')}
both60 = sum(1 for b in ok if b['claude']['fps'] >= 55 and b['port']['fps'] >= 55)
slower = sorted(ok, key=lambda b: b['claude']['cpuMs'] - b['port']['cpuMs'], reverse=True)[:3]
static_diff = sum(b['diffPct'] for b in static) / max(1, len(static))
tt = [b for b in ok if b['claude'].get('fpsTouch') and b['port'].get('fpsTouch')]
touch_c = sum(b['claude']['fpsTouch'] for b in tt) / max(1, len(tt))
touch_p = sum(b['port']['fpsTouch'] for b in tt) / max(1, len(tt))
summary = [
    f"与上游原版（在 Mac 浏览器里用 WebGPU 直接跑 shaders 4.0.4 截图）对比 {len(refd)} 个静态效果：Claude 版平均差异 {ref_c:.2f}%（{close_c}/{len(refd)} 个在 3% 以内），shaderport 平均差异 {ref_p:.1f}%（{close_p}/{len(refd)} 个在 3% 以内）。shaderport 的形状类在默认参数下整屏填满，棋盘格格子比例不对。",
    (f"手指在屏幕上滑动时 LTPO 屏会升到 120Hz：此时共同效果平均帧率 Claude {touch_c:.0f} fps、shaderport {touch_p:.0f} fps（{len(tt)} 个效果）。上游引擎原本把帧率封顶在 60，鸿蒙版已放开为跟随屏幕（可用 setMaxFrameRate(60) 省电）。" if tt else "") ,
    f"静止时（屏幕 60Hz）共同效果 {len(bench)} 个两边都能出图；{both60} 个两边都跑满约 60 fps。" +
    ''.join(f"例外：{b['name']} 的 {'shaderport' if b['port']['fps'] < b['claude']['fps'] else 'Claude'} 只有 "
            f"{min(b['port']['fps'], b['claude']['fps']):.0f} fps（另一侧 {max(b['port']['fps'], b['claude']['fps']):.0f} fps）。"
            for b in ok if not (b['claude']['fps'] >= 55 and b['port']['fps'] >= 55)),
    f"每帧 CPU 耗时平均 Claude {a['claude']['cpuMs']:.1f} ms，shaderport {a['port']['cpuMs']:.1f} ms：Claude 版每帧要在方舟 JS 里跑引擎（参数驱动、组合、编码命令），开销更大，但离 16.7 ms 的帧预算还很远。",
    f"进程内存（PSS）平均 Claude {a['claude']['pssKb']/1024:.0f} MB，shaderport {a['port']['pssKb']/1024:.0f} MB（同一个演示应用里单独渲染一侧时测得；shaderport 一侧也包含了已加载但空闲的 Claude 引擎，所以它单独使用时会更省）。",
    f"页面到首帧平均 Claude {a['claude']['firstFrameMs']:.0f} ms，shaderport {a['port']['firstFrameMs']:.0f} ms。",
    "动画类效果（两边时钟不同步，无法逐像素比较）逐个人工核对：Claude 版 8/8 与原版一致；shaderport 的 Aurora 上下颠倒、SineWave 整屏纯白、Stripes 变成人字形、Spiral 方向不同、MeshGradient 布局不同。",
    "结论：要效果全、能组合、能接图片/视频/摄像头、要和上游保持一致——选 Claude 版；只需要几十个基础背景/形状/调色效果、在意包体积或需要支持 HarmonyOS 5 / 模拟器——shaderport 更轻。",
]
if slower:
    summary.insert(2, "CPU 开销差距最大的效果：" + "、".join(f"{b['name']}（{b['claude']['cpuMs']:.1f} vs {b['port']['cpuMs']:.1f} ms）" for b in slower) + "。")
# Animated effects can't be pixel-diffed (unsynchronised clocks); triplets + a manual verdict instead.
for chk in notes.get('animatedChecks', []):
    n = chk['name']
    write_triplet_ref(n)
    for side in ('claude', 'port'):
        write_triplet_side(n, side)

report = {
    'device': 'LAP-AL10 三折叠 · HarmonyOS 7.0（API 26）· 同一个演示应用内测量',
    'date': datetime.date.today().isoformat(),
    'summary': [x for x in summary if x],
    'rows': notes['rows'],
    'bench': sorted(bench, key=lambda b: b['name']),
    'animatedChecks': notes.get('animatedChecks', []),
    'touchFps': {'claude': touch_c, 'port': touch_p, 'count': len(tt)} if tt else None,
    'fidelity': {'claudeAvg': ref_c, 'portAvg': ref_p, 'claudeClose': close_c, 'portClose': close_p, 'count': len(refd),
                 'items': [{'name': b['name'], 'claude': b['vsUpstream']['claude'], 'port': b['vsUpstream']['port']} for b in refd]},
}
json.dump(report, open(f'{RAW}/compare-report.json', 'w'), ensure_ascii=False, indent=1)
print('wrote', f'{RAW}/compare-report.json')
