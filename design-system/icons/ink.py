# Ink joins (principles/icons.md): where strokes meet, the inside corner gets a concave fillet, as if the ink pooled.
# Exact geometry for any angle: the two stroke edges facing the corner are offset by half the stroke; the fillet is
# tangent to both. Radius 1.0 at 24pt, smaller on sharp joints so a pool never runs more than 1.6 along a stroke.
# Reads base.json (the clean geometry) and writes icons.json + one svg per icon.
import json, math
W = 0.875                      # half of the 1.75 stroke
def n(x, y): l = math.hypot(x, y); return (x / l, y / l)
def f(v): return f'{v:.3f}'.rstrip('0').rstrip('.')
def corner(P, u, v, rmax=1.0, dmax=1.6):
    u, v = n(*u), n(*v)
    th = math.acos(max(-1, min(1, u[0]*v[0] + u[1]*v[1])))
    if th > math.radians(120): return ''   # obtuse joints don't pool
    b = n(u[0] + v[0], u[1] + v[1])
    r = min(rmax, dmax * math.tan(th / 2))
    q = (P[0] + b[0] * W / math.sin(th / 2), P[1] + b[1] * W / math.sin(th / 2))
    d = r / math.tan(th / 2)
    tu, tv = (q[0] + u[0]*d, q[1] + u[1]*d), (q[0] + v[0]*d, q[1] + v[1]*d)
    o = (q[0] + b[0] * r / math.sin(th / 2), q[1] + b[1] * r / math.sin(th / 2))
    a, c = (tu[0]-o[0], tu[1]-o[1]), (tv[0]-o[0], tv[1]-o[1])
    sweep = 1 if a[0]*c[1] - a[1]*c[0] > 0 else 0
    # blend: overlap 0.4 into both strokes and close through the joint's centre, so the pool and the stroke are one ink, no seam
    nu = (-u[1], u[0]) if (-u[1])*v[0] + u[0]*v[1] > 0 else (u[1], -u[0])
    nv = (-v[1], v[0]) if (-v[1])*u[0] + v[0]*u[1] > 0 else (v[1], -v[0])
    tu2, tv2 = (tu[0] - nu[0]*0.4, tu[1] - nu[1]*0.4), (tv[0] - nv[0]*0.4, tv[1] - nv[1]*0.4)
    return (f'M{f(tu2[0])} {f(tu2[1])}L{f(tu[0])} {f(tu[1])}A{f(r)} {f(r)} 0 0 {sweep} {f(tv[0])} {f(tv[1])}'
            f'L{f(tv2[0])} {f(tv2[1])}L{f(P[0])} {f(P[1])}Z')
def tee(P, stem, along): return [corner(P, stem, along), corner(P, stem, (-along[0], -along[1]))]
def cross(P, a, b): return [corner(P, a, b), corner(P, b, (-a[0], -a[1])), corner(P, (-a[0], -a[1]), (-b[0], -b[1])), corner(P, (-b[0], -b[1]), a)]
def curve(P, O, R, a, m, inner=False, r=None):
    # a straight stroke (through P, running along a) meeting a circular stroke (centre O, radius R), on the side m.
    # The fillet circle is tangent to the straight stroke's edge and to the circle's true offset edge (outer or inner),
    # so it meets the curve exactly. Small circles get a smaller pool so short spokes don't web over.
    a, m = n(*a), n(*m)
    r = r or (0.7 if R < 2 else 1.0)
    D = (R - W - r) if inner else (R + W + r)
    B = (P[0] + m[0]*(W + r) - O[0], P[1] + m[1]*(W + r) - O[1])
    ba = B[0]*a[0] + B[1]*a[1]; disc = ba*ba - (B[0]**2 + B[1]**2 - D*D)
    if disc < 0: return ''
    roots = sorted([-ba - math.sqrt(disc), -ba + math.sqrt(disc)])
    s_ = next((x for x in roots if x > 0), None) if inner else roots[1]
    if s_ is None: return ''
    Cc = (B[0] + a[0]*s_ + O[0], B[1] + a[1]*s_ + O[1])
    Tl = (P[0] + m[0]*W + a[0]*s_, P[1] + m[1]*W + a[1]*s_)
    k = (R - W) / D if inner else (R + W) / D
    Tc = (O[0] + (Cc[0]-O[0])*k, O[1] + (Cc[1]-O[1])*k)
    k2 = (R - W + 0.4) / D if inner else (R + W - 0.4) / D
    Tc2 = (O[0] + (Cc[0]-O[0])*k2, O[1] + (Cc[1]-O[1])*k2)
    Tl2 = (Tl[0] - m[0]*0.4, Tl[1] - m[1]*0.4)
    u1, u2 = (Tl[0]-Cc[0], Tl[1]-Cc[1]), (Tc[0]-Cc[0], Tc[1]-Cc[1])
    sweep = 1 if u1[0]*u2[1] - u1[1]*u2[0] > 0 else 0
    return (f'M{f(Tl2[0])} {f(Tl2[1])}L{f(Tl[0])} {f(Tl[1])}A{f(r)} {f(r)} 0 0 {sweep} {f(Tc[0])} {f(Tc[1])}'
            f'L{f(Tc2[0])} {f(Tc2[1])}L{f(P[0])} {f(P[1])}Z')
def spoke(P, O, R, away):  # a straight stroke leaving a circle radially: pools on both sides
    a = n(*away); return [curve(P, O, R, a, (-a[1], a[0])), curve(P, O, R, a, (a[1], -a[0]))]
H, V_ = (1, 0), (0, 1)
s2 = 6 / math.sqrt(2)
J = {
 'drawer': tee((9.25, 5.25), V_, H) + tee((9.25, 18.75), (0, -1), H),
 'calendar': tee((4.25, 10), H, V_) + tee((19.75, 10), (-1, 0), V_) + cross((8.5, 5.5), V_, H) + cross((15.5, 5.5), V_, H),
 'lock': [corner((8.5, 10.5), (0, -1), H), corner((15.5, 10.5), (0, -1), (-1, 0))],
 'mic': [curve((12, 17.25), (12, 11), 6.25, V_, H), curve((12, 17.25), (12, 11), 6.25, V_, (-1, 0))],
 'mic-off': [curve((12, 17.25), (12, 11), 6.25, V_, H), curve((12, 17.25), (12, 11), 6.25, V_, (-1, 0))],
 'arrow-right': [corner((19.25, 12), (-1, 0), (-1, -1)), corner((19.25, 12), (-1, 0), (-1, 1))],
 'send': [corner((12, 5.25), V_, (-1, 1)), corner((12, 5.25), V_, (1, 1))],
 'sign-out': [corner((19.25, 12), (-1, 0), (-1, -1)), corner((19.25, 12), (-1, 0), (-1, 1))],
 'download': [corner((12, 14.75), (0, -1), (-1, -1)), corner((12, 14.75), (0, -1), (1, -1))],
 'share': [corner((12, 3.5), V_, (-1, 1)), corner((12, 3.5), V_, (1, 1))],
 'external': [corner((16.5, 7.5), (-1, 1), (-1, 0)), corner((16.5, 7.5), (-1, 1), V_)],
 'add': cross((12, 12), H, V_),
 'close': cross((12, 12), (1, 1), (1, -1)),
 'check': [corner((9.75, 16.5), (-4, -3.75), (8.5, -8.75))],
 'chevron-down': [corner((12, 14.75), (-1, -1), (1, -1))],
 'chevron-right': [corner((14.75, 12), (-1, -1), (-1, 1))],
 'chevron-up-down': [corner((12, 5.75), (-1, 1), (1, 1)), corner((12, 18.25), (-1, -1), (1, -1))],
 'retry': [corner((14.5, 5.25), (-1, 0), (-1, -1)), corner((14.5, 5.25), (-1, 0), (-1, 1))],
 'skip-back-15': [corner((9.25, 5.25), H, (1, -1)), corner((9.25, 5.25), H, (1, 1))],
 'skip-forward-30': [corner((14.75, 5.25), (-1, 0), (-1, -1)), corner((14.75, 5.25), (-1, 0), (-1, 1))],
 'search': spoke((10.75 + s2, 10.75 + s2), (10.75, 10.75), 6, (1, 1)),
 'sliders': spoke((12.75, 7.5), (15, 7.5), 2.25, (-1, 0)) + spoke((17.25, 7.5), (15, 7.5), 2.25, H) + spoke((6.75, 16.5), (9, 16.5), 2.25, (-1, 0)) + spoke((11.25, 16.5), (9, 16.5), 2.25, H),
 'brief': [curve((7.5, 17.5), (12, 17.5), 4.5, (-1, 0), (0, -1)), curve((7.5, 17.5), (12, 17.5), 4.5, H, (0, -1), inner=True),
           curve((16.5, 17.5), (12, 17.5), 4.5, H, (0, -1)), curve((16.5, 17.5), (12, 17.5), 4.5, (-1, 0), (0, -1), inner=True)],
 'you': (spoke((6.8, 7.5), (5.5, 6.25), 1.75, (3.15, 2.9)) + spoke((9.95, 10.4), (12, 12.25), 2.75, (-3.15, -2.9))
         + spoke((17.2, 7), (18.5, 5.75), 1.75, (-3.1, 3.3)) + spoke((14.1, 10.3), (12, 12.25), 2.75, (3.1, -3.3))
         + spoke((16.7, 17.2), (18, 18.5), 1.75, (-2.6, -2.9)) + spoke((14.1, 14.3), (12, 12.25), 2.75, (2.6, 2.9))
         + spoke((7.1, 16.7), (5.75, 18), 1.75, (2.85, -2.6)) + spoke((9.95, 14.1), (12, 12.25), 2.75, (-2.85, 2.6))),
 # slashes (mic-off, offline): pooled in outline.py, where the crossings are found exactly
 # heart: no pool. Its cleft is the shape; filling it flattens the heart (checked at 6×, 20 Oct)
 # correct (speech bubble): no pool in the tail's acute corner, it fills into a blot
}
base = json.load(open('base.json'))
out = {}
for k, (kind, geo, note) in base.items():
    d = ''.join(p for p in J.get(k, []) if p)
    ink = f'<path class="ink" fill="currentColor" stroke="none" d="{d}"/>' if d else ''
    out[k] = [kind, geo + ink, note]
    attrs = 'fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"' if kind == 'stroke' else 'fill="currentColor"'
    open(f'{k}.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" {attrs}>{geo}{ink}</svg>\n')
json.dump(out, open('icons.json', 'w'), indent=1, ensure_ascii=False)
print(sum(1 for k in J if any(J[k])), 'icons with ink joins;', sum(len([p for p in v if p]) for v in J.values()), 'pools')
