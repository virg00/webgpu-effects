#!/usr/bin/env python3
"""Prints the average RGB of a few regions of a screenshot (center, quarters) — quick render checks without viewing."""
import subprocess, sys, struct, tempfile, os
src = sys.argv[1]
tmp = tempfile.mktemp(suffix='.bmp')
subprocess.run(['sips', '-s', 'format', 'bmp', src, '--out', tmp], capture_output=True, check=True)
d = open(tmp, 'rb').read(); os.unlink(tmp)
off = struct.unpack_from('<I', d, 10)[0]; w, h = struct.unpack_from('<ii', d, 18); bpp = struct.unpack_from('<H', d, 28)[0] // 8
row = (w * bpp + 3) & ~3
def px(x, y):
    yy = (h - 1 - y) if h > 0 else y
    i = off + yy * row + x * bpp
    return d[i + 2], d[i + 1], d[i]
h = abs(h)
for name, fx, fy in (('top', .5, .2), ('center', .5, .5), ('bottom', .5, .8), ('left', .15, .5), ('right', .85, .5)):
    print(name, px(int(w * fx), int(h * fy)))
