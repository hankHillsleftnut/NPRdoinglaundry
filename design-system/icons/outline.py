# Build each icon into one finished shape (founder, 20 Oct: "complete components… not in pieces").
# Source of truth stays editable: base.json (clean geometry) + ink.py (ink joins) → icons.json.
# This script outlines every stroke (1.75, round caps and joins), adds the ink pools, fills and numerals
# (SF Mono 600 as outlines), merges it all into ONE filled path, and writes:
#   shipped/<name>.svg   one <path fill="currentColor">, 24 × 24, ready for an Xcode template asset or Paper
#   outlined.json        the same paths, for generators
# ICON_SIZE=20 writes shipped-20/ and outlined-20.json: the 20pt optical size (stroke 2 in the 24 grid)
# Run with the scratch venv: shapely, svgpathtools, fontTools.
import json, re, sys
from shapely.geometry import LineString, Polygon, MultiPolygon, Point
from shapely.ops import unary_union
from shapely.affinity import translate
from svgpathtools import parse_path
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen
from fontTools.varLib.instancer import instantiateVariableFont

import os
# optical sizes: 24pt draws a 1.75 stroke; 20pt draws 2.0 in the same 24 grid (~1.67pt on screen) so it holds its weight
SIZE = os.environ.get('ICON_SIZE', '24')
W = (2.0 if SIZE == '20' else 1.75) / 2
SUFFIX = '' if SIZE == '24' else f'-{SIZE}'
def attrs(tag): return dict(re.findall(r'([\w:-]+)="([^"]*)"', tag))
def sample(d, per=240):
    """Flatten a path into lists of points, one list per subpath."""
    out, cur = [], []
    for seg in parse_path(d):
        n = 2 if seg.__class__.__name__ == 'Line' else per
        pts = [seg.point(t / n) for t in range(n + 1)]
        if cur and abs(cur[-1] - pts[0]) > 1e-6: out.append(cur); cur = []
        cur += pts if not cur else pts[1:]
    if cur: out.append(cur)
    return [[(p.real, p.imag) for p in s] for s in out]
def rect_d(a):
    x, y, w, h, r = (float(a.get(k, 0)) for k in ('x', 'y', 'width', 'height', 'rx'))
    return (f'M{x+r} {y}H{x+w-r}A{r} {r} 0 0 1 {x+w} {y+r}V{y+h-r}A{r} {r} 0 0 1 {x+w-r} {y+h}'
            f'H{x+r}A{r} {r} 0 0 1 {x} {y+h-r}V{y+r}A{r} {r} 0 0 1 {x+r} {y}Z')
def circle_d(a):
    cx, cy, r = float(a['cx']), float(a['cy']), float(a['r'])
    return f'M{cx-r} {cy}A{r} {r} 0 1 0 {cx+r} {cy}A{r} {r} 0 1 0 {cx-r} {cy}Z'
def subpaths(d):
    return re.findall(r'M[^M]*', d)   # our sources start every subpath with an absolute M
def stroked(d, w=W):
    geoms = []
    for s in sample(d):
        if len(s) == 1 or max(abs(s[0][0]-p[0]) + abs(s[0][1]-p[1]) for p in s) < 1e-3:   # a dot (h.01)
            geoms.append(Point(s[0]).buffer(w, 64)); continue
        geoms.append(LineString(s).buffer(w, cap_style='round', join_style='round', quad_segs=64))
    return unary_union(geoms)
def filled(d):
    polys = [Polygon(s) for s in sample(d) if len(s) > 2]
    out = None
    for p in polys:   # even-odd like SVG nonzero for our simple shapes: later rings inside earlier ones are holes
        p = p.buffer(0)
        out = p if out is None else (out.difference(p) if out.contains(p) else out.union(p))
    return out
_font = None
def numerals(text, x, y, size, anchor):
    global _font
    if _font is None:
        f = TTFont('/System/Library/Fonts/SFNSMono.ttf')
        if 'fvar' in f: f = instantiateVariableFont(f, {'wght': 600})
        _font = f
    gs, cmap, upem = _font.getGlyphSet(), _font.getBestCmap(), _font['head'].unitsPerEm
    sc = size / upem
    adv = sum(_font['hmtx'][cmap[ord(c)]][0] for c in text) * sc
    pen_x = x - (adv / 2 if anchor == 'middle' else 0)
    shapes = []
    for c in text:
        g = cmap[ord(c)]; rp = RecordingPen(); gs[g].draw(rp)
        d = []
        for op, pts in rp.value:
            P = [f'{pen_x + px*sc:.3f} {y - py*sc:.3f}' for px, py in pts]
            d.append({'moveTo': 'M', 'lineTo': 'L', 'qCurveTo': 'Q', 'curveTo': 'C', 'closePath': 'Z', 'endPath': ''}[op] + ' '.join(P))
        dd = ' '.join(d)
        # TrueType qCurveTo may carry several off-curve points; expand to plain Q segments
        dd = re.sub(r'Q([^MLQCZ]+)', lambda m: expand_q(m.group(1)), dd)
        shapes.append(filled_evenodd(dd))
        pen_x += _font['hmtx'][g][0] * sc
    return unary_union(shapes)
def expand_q(body):
    pts = [tuple(map(float, p.split())) for p in re.findall(r'-?[\d.]+ -?[\d.]+', body)]
    out = []
    for i in range(len(pts) - 1):
        ctrl = pts[i]
        end = pts[i+1] if i == len(pts) - 2 else ((pts[i][0]+pts[i+1][0])/2, (pts[i][1]+pts[i+1][1])/2)
        out.append(f'Q{ctrl[0]} {ctrl[1]} {end[0]} {end[1]}')
    return ''.join(out)
def filled_evenodd(d):
    # glyphs fill non-zero: contours wound like the largest are ink (unioned), counter-wound ones are counters (cut)
    rings = [s for s in sample(d, 40) if len(s) > 2]
    def area(s): return sum(s[i][0]*s[(i+1) % len(s)][1] - s[(i+1) % len(s)][0]*s[i][1] for i in range(len(s))) / 2
    big = max(rings, key=lambda s: abs(area(s)))
    sign = 1 if area(big) > 0 else -1
    ink = unary_union([Polygon(s).buffer(0) for s in rings if area(s) * sign > 0])
    holes = [Polygon(s).buffer(0) for s in rings if area(s) * sign < 0]
    return ink.difference(unary_union(holes)) if holes else ink
def smooth_ring(c, corner_deg=20, err=0.006):
    """One closed ring as cubic Béziers fitted within err (Schneider), split at true corners so they stay sharp."""
    import math
    from fitcurves import fit
    n = len(c)
    def turn(i):
        a, b, d = c[i-1], c[i], c[(i+1) % n]
        v1, v2 = (b[0]-a[0], b[1]-a[1]), (d[0]-b[0], d[1]-b[1])
        l1, l2 = math.hypot(*v1), math.hypot(*v2)
        if l1 == 0 or l2 == 0: return 0
        return math.degrees(math.acos(max(-1, min(1, (v1[0]*v2[0] + v1[1]*v2[1]) / (l1*l2)))))
    corners = [i for i in range(n) if turn(i) > corner_deg] or [0]
    out = [f'M{c[corners[0]][0]:.3f} {c[corners[0]][1]:.3f}']
    for k, s in enumerate(corners):
        e = corners[(k + 1) % len(corners)]
        run = [c[(s + j) % n] for j in range(((e - s) % n or n) + 1)]
        for b in fit(run, err):
            if abs(b[1][0]-b[0][0]) + abs(b[1][1]-b[0][1]) + abs(b[2][0]-b[3][0]) + abs(b[2][1]-b[3][1]) < 1e-9 or len(run) == 2:
                out.append(f'L{b[3][0]:.3f} {b[3][1]:.3f}')
            else:
                out.append(f'C{b[1][0]:.3f} {b[1][1]:.3f} {b[2][0]:.3f} {b[2][1]:.3f} {b[3][0]:.3f} {b[3][1]:.3f}')
    return ''.join(out) + 'Z'
def to_d(geom):
    polys = list(geom.geoms) if isinstance(geom, MultiPolygon) else [geom]
    parts = []
    for p in polys:
        for ring in [p.exterior, *[i for i in p.interiors if Polygon(i).area > 0.5]]:   # no slivers or crumbs
            parts.append(smooth_ring(list(ring.coords)[:-1]))
    return ''.join(parts)

src = json.load(open('icons.json'))
out = {}
for name, (kind, markup, note) in src.items():
    shape, parts, slash, glyphs, junctions, slash_gap = [], [], None, [], [], 0
    for tag in re.findall(r'<(?:rect|circle|path|text)[^>]*/?>(?:[^<]*</text>)?', markup):
        a = attrs(tag)
        el = tag[1:tag.index(' ')]
        if el == 'text':
            txt = re.search(r'>([^<]*)<', tag).group(1)
            g = numerals(txt, float(a['x']), float(a['y']), float(a['font-size']), a.get('text-anchor'))
            if 'data-optical' in a:   # centre on the ink's weight across, its height down (an open 3 or a 1 reads off-centre by box)
                ox, oy = map(float, a['data-optical'].split())
                b = g.bounds
                g = translate(g, ox - g.centroid.x, oy - (b[1] + b[3]) / 2)
            glyphs.append(g)
            continue
        d = rect_d(a) if el == 'rect' else circle_d(a) if el == 'circle' else a['d']
        if 'class="ink"' in tag:   # ink.py's pools: keep each junction's point and radius, rebuild it exactly below
            for sp in re.findall(r'M[^Z]*Z', d):
                nums = [tuple(map(float, q)) for q in re.findall(r'(-?[\d.]+) (-?[\d.]+)', sp)]
                r = float(re.search(r'A(-?[\d.]+)', sp).group(1))
                P = nums[-1]
                reach = max(((x-P[0])**2 + (y-P[1])**2) ** 0.5 for x, y in nums) + 0.5
                junctions.append((P, r, reach))
            continue
        if a.get('class') == 'slash':
            slash = stroked(d); slash_line = LineString(sample(d)[0]); slash_gap = float(a.get('data-gap', 0)); continue
        is_fill = kind == 'fill' or a.get('fill') == 'currentColor'
        shape.append(filled(d) if is_fill else stroked(d))
        if not is_fill:
            parts += [(stroked(sd), LineString(sample(sd)[0]) if len(sample(sd)[0]) > 1 else Point(sample(sd)[0][0])) for sd in subpaths(d)]
    geom = unary_union([g for g in shape if g is not None])
    # each pool is the exact fillet between the real stroke edges meeting there (a local closing), so it meets
    # straight and curving edges alike with no step
    pools = []
    for P, r, reach in junctions:
        near = [p for p, _ in parts if p.distance(Point(P)) < 1e-3]
        if len(near) < 1: continue
        both = unary_union(near)
        pools.append(both.buffer(r, quad_segs=48).buffer(-r, quad_segs=48).difference(both).intersection(Point(P).buffer(reach, 48)))
    geom = unary_union([geom, *pools])
    if slash is not None and slash_gap:   # the strokes stop short of the slash, their cut ends softened round (offline, founder 20 Oct)
        band = slash_line.buffer(W + slash_gap, cap_style='round', quad_segs=24)
        geom = geom.difference(band).buffer(-0.4, quad_segs=32).buffer(0.4, quad_segs=32)
        geom = unary_union([geom, slash])
    elif slash is not None:   # the slash crosses; ink pools only in the corners right at each crossing (r 0.5)
        pools = []
        for p, line in parts:   # one stroke at a time, so neighbouring strokes never web together
            hit = line.intersection(slash_line)
            pts = [hit] if hit.geom_type == 'Point' else list(getattr(hit, 'geoms', []))
            if not pts: continue
            near = unary_union([q.buffer(W + 1.1) for q in pts if q.geom_type == 'Point'])
            both = p.union(slash)
            pools.append(both.buffer(0.5, quad_segs=24).buffer(-0.5, quad_segs=24).difference(both).intersection(near))
        geom = unary_union([geom, slash, *pools])
    # an opening then a closing (r 0.25) melt the hairline nubs and steps where an exact fillet meets a flattened
    # curve (founder's 30s close-up). r 0.25 is under every cap (0.875) and pool (0.66+). Numerals join after, so their corners stay sharp.
    geom = geom.buffer(-0.25, quad_segs=32).buffer(0.5, quad_segs=32).buffer(-0.25, quad_segs=32)
    if glyphs: geom = unary_union([geom, *glyphs])
    geom = geom.simplify(0.001, preserve_topology=True)
    d = to_d(geom)
    out[name] = d
    os.makedirs(f'shipped{SUFFIX}', exist_ok=True); open(f'shipped{SUFFIX}/{name}.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path fill="currentColor" fill-rule="evenodd" d="{d}"/></svg>\n')
json.dump(out, open(f'outlined{SUFFIX}.json', 'w'))
print(len(out), 'icons outlined; each is one path')
