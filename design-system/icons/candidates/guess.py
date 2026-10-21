# Guess icon candidates (founder comment on the old sparkle, 20 Oct: "change this, this is super ugly").
# The system already says how a guess looks: dashed, and it says "a guess" (principles/accessibility.md).
import json, math, sys
sys.path.insert(0, '.')
from shapely.geometry import Polygon, LineString, Point
from shapely.ops import unary_union
W = 0.875
def star(cx, cy, R, c=0.3, soft=0.3, rx=1.0):
    # four tips, concave sides as quadratic curves pulled toward the centre; tips softened like a nib
    tips = [(cx, cy - R), (cx + R * rx, cy), (cx, cy + R), (cx - R * rx, cy)]
    pts = []
    for i in range(4):
        a, b = tips[i], tips[(i + 1) % 4]
        ctrl = (cx + ((a[0] - cx) + (b[0] - cx)) * c, cy + ((a[1] - cy) + (b[1] - cy)) * c)
        for t in [k / 24 for k in range(24)]:
            pts.append(((1-t)**2*a[0] + 2*(1-t)*t*ctrl[0] + t*t*b[0], (1-t)**2*a[1] + 2*(1-t)*t*ctrl[1] + t*t*b[1]))
    return Polygon(pts).buffer(-soft, quad_segs=16).buffer(soft, quad_segs=16)
def dashed_ring(cx, cy, r, n, gap_deg):
    segs = []
    step = 360 / n
    for i in range(n):
        a0, a1 = math.radians(i * step - 90 + gap_deg / 2), math.radians((i + 1) * step - 90 - gap_deg / 2)
        pts = [(cx + r * math.cos(a0 + (a1 - a0) * k / 12), cy + r * math.sin(a0 + (a1 - a0) * k / 12)) for k in range(13)]
        segs.append(LineString(pts).buffer(W, cap_style='round', quad_segs=16))
    return unary_union(segs)
def to_d(g):
    polys = list(getattr(g, 'geoms', [g]))
    out = []
    for p in polys:
        for ring in [p.exterior, *p.interiors]:
            c = list(ring.simplify(0.008).coords)
            out.append('M' + 'L'.join(f'{x:.2f} {y:.2f}' for x, y in c[:-1]) + 'Z')
    return ''.join(out)
C = {
  'a · two sparkles': unary_union([star(10.25, 13.5, 7.25, c=0.27), star(18, 6, 3, c=0.27, soft=0.2)]),
  'b · dashed ring, sparkle inside': unary_union([dashed_ring(12, 12, 8.375, 8, 18), star(12, 12, 4.5, c=0.27, soft=0.2)]),
  'c · one soft sparkle': star(12, 12, 8.75, c=0.2, soft=0.35),
}
json.dump({k: to_d(v) for k, v in C.items()}, open('candidates/guess.json', 'w'), indent=1)
for k, v in C.items(): print(k, [round(b, 2) for b in v.bounds], 'area', round(v.area, 1))
