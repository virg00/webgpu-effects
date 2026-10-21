#!/usr/bin/env python3
"""Writes the app's layered-icon PNGs (pure Python, no PIL): a violet→blue gradient background and a white ring foreground."""
import math, struct, sys, zlib

def png(path, w, h, px):
    raw = b''.join(b'\x00' + b''.join(bytes(px(x, y)) for x in range(w)) for y in range(h))
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))

def bg(x, y, n=1024):
    t = (x + y) / (2 * n)
    a, b = (124, 58, 237), (3, 104, 255)
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)

def fg(x, y, n=1024):
    d = math.hypot(x - n / 2, y - n / 2) / n
    alpha = max(0.0, min(1.0, (0.012 - abs(d - 0.2)) * 300))
    return (255, 255, 255, int(alpha * 255))

out = sys.argv[1]
png(f'{out}/background.png', 1024, 1024, bg)
png(f'{out}/foreground.png', 1024, 1024, fg)
