#!/usr/bin/env python3
"""Writes the demo's sample image (a synthetic sunset landscape) as PNG — no third-party assets needed."""
import math, struct, sys, zlib

W, H = 960, 720

def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def ridge(x, base, amp, freq, phase):
    return base + amp * (math.sin(x * freq + phase) * 0.6 + math.sin(x * freq * 2.7 + phase * 1.3) * 0.3 + math.sin(x * freq * 6.1 + phase) * 0.1)

def pixel(x, y):
    u, v = x / W, y / H
    sky = mix((38, 20, 92), (255, 128, 92), min(1, v / 0.62) ** 1.4)
    sky = mix(sky, (255, 214, 140), max(0, 1 - abs(v - 0.58) * 6) * 0.6)
    d = math.hypot(u - 0.62, (v - 0.47) * H / W)
    if d < 0.085:
        sky = mix((255, 236, 180), (255, 250, 230), 1 - d / 0.085)
    else:
        sky = mix(sky, (255, 220, 160), max(0, 0.25 - d) * 1.6)
    c = sky
    for base, amp, freq, phase, col in ((0.60, 0.05, 7, 0.4, (120, 52, 110)), (0.68, 0.06, 5, 2.1, (72, 30, 86)), (0.78, 0.05, 9, 4.0, (36, 16, 52))):
        if v > ridge(u, base, amp, freq, phase):
            c = col
    if v > 0.86:
        t = (v - 0.86) / 0.14
        c = mix((24, 12, 40), (8, 6, 18), t)
        if abs(u - 0.62) < 0.06 * (1 - t) and int(y) % 6 < 3:
            c = mix(c, (255, 200, 150), 0.7 * (1 - t))
    return bytes(int(max(0, min(255, k))) for k in c)

raw = b''.join(b'\x00' + b''.join(pixel(x, y) for x in range(W)) for y in range(H))
def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
open(sys.argv[1], 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
