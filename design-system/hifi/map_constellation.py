from review import *
import random
# The you map, redrawn as the constellation the tokens already describe (map.star.*): founder, 20 Oct, "a much prettier graph".
# Each thing is a small bright core in a soft halo; threads are thin curves whose weight says how strong the link is;
# a faint field of stars sits behind, so the map reads as a sky of your life, not a diagram. Labels are HTML (Geist), over the SVG.
W, H = 520, 440
YOU = (260, 222)
# (name, kind, x, y, core, halo, strength 0–1, label)
NODES = [('maya', 'person', 148, 118, 7, 30, 0.9, 'maya'), ('work', 'writing', 398, 138, 5, 22, 0.35, 'work'),
         ('river', 'place', 118, 330, 6.5, 26, 0.55, 'the river'), ('running', 'goal', 382, 332, 7, 28, 0.85, 'running'),
         ('p2', 'person', 268, 92, 3.5, 13, 0.3, None), ('g2', 'goal', 452, 262, 3, 11, 0.25, None)]
WAIT = (248, 396)
rnd = random.Random(7)
def curve(a, b, bend):
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    dx, dy = b[0] - a[0], b[1] - a[1]
    return f'M{a[0]} {a[1]}Q{mx - dy * bend:.1f} {my + dx * bend:.1f} {b[0]} {b[1]}'
defs, body = [], []
# the field: 46 faint stars, kept off the nodes so nothing competes with them
for i in range(46):
    x, y = rnd.uniform(14, W - 14), rnd.uniform(14, H - 14)
    if any((x - n[2]) ** 2 + (y - n[3]) ** 2 < (n[5] + 10) ** 2 for n in NODES) or (x - YOU[0]) ** 2 + (y - YOU[1]) ** 2 < 70 ** 2:
        continue
    body.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rnd.choice([0.6, 0.8, 1, 1.2])}" fill="var(--color-map-star-field)" opacity="{rnd.choice([0.18, 0.26, 0.34, 0.42])}"/>')
# closeness: two hairline orbits round you
for r in (92, 168):
    body.append(f'<circle cx="{YOU[0]}" cy="{YOU[1]}" r="{r}" fill="none" stroke="var(--color-map-edge)" stroke-width="0.5" opacity="0.35"/>')
# threads: one curve from you to each; the stronger the link, the heavier and darker
for name, kind, x, y, core, halo, s, _ in NODES:
    col = 'var(--color-map-edge-strong)' if s > 0.6 else 'var(--color-map-edge)'
    body.append(f'<path d="{curve(YOU, (x, y), 0.12 if x > YOU[0] else -0.12)}" fill="none" stroke="{col}" stroke-width="{0.6 + s * 1.1:.2f}" stroke-linecap="round" opacity="{0.35 + s * 0.4:.2f}"/>')
body.append(f'<path d="{curve((148, 118), (268, 92), -0.15)}" fill="none" stroke="var(--color-map-edge)" stroke-width="0.7" opacity="0.4"/>')
body.append(f'<path d="{curve((382, 332), (452, 262), 0.15)}" fill="none" stroke="var(--color-map-edge)" stroke-width="0.7" opacity="0.4"/>')
body.append(f'<path d="{curve(YOU, WAIT, 0.1)}" fill="none" stroke="var(--color-map-edge)" stroke-width="0.75" stroke-dasharray="2 3" opacity="0.6"/>')
# halos are HTML (CSS radial gradients resolve tokens; SVG gradient stops don't in Paper), cores are SVG
halos = []
for name, kind, x, y, core, halo, s, _ in NODES + [('you', 'self', *YOU, 18, 60, 1, None)]:
    halos.append(f'<div style="position:absolute;left:{x - halo}px;top:{y - halo}px;width:{2 * halo}px;height:{2 * halo}px;border-radius:{V("radius-control")};'
                 f'background:radial-gradient(circle closest-side, {C(f"map-star-{kind}-halo")} 0%, transparent 100%)"></div>')
    body.append(f'<circle cx="{x}" cy="{y}" r="{core}" fill="var(--color-map-star-{kind}-core)"/>')
    body.append(f'<circle cx="{x - core * 0.3:.1f}" cy="{y - core * 0.35:.1f}" r="{core * 0.42:.1f}" fill="var(--color-glow-primary-foreground)" opacity="0.3"/>')
# the one thing waiting for you: a dashed ring, no core yet
body.append(f'<circle cx="{WAIT[0]}" cy="{WAIT[1]}" r="7" fill="none" stroke="var(--color-inference-marker)" stroke-width="1" stroke-dasharray="2 2.4"/>')
svg = (f'<svg width="{W}" height="{H}" viewBox="0 0 {W} {H}" style="position:absolute;left:0;top:0">{"".join(body)}</svg>')
def lab(text, x, y, strong=False, colour=None):
    return (f'<div style="position:absolute;left:{x - 60}px;top:{y}px;width:120px;display:flex;justify-content:center;font-family:{V("font-label")};'
            f'font-size:{V("text-xs")};line-height:{V("leading-snug")};font-weight:{V("font-weight-medium") if strong else V("font-weight-regular")};color:{C(colour or ("text-primary" if strong else "text-secondary"))}">{text}</div>')
# each label sits on the side facing away from you, so no thread runs through it
def place(x, y, core):
    return y - core - 8 - 15 if y < YOU[1] else y + core + 6
labels = (''.join(lab(t, x, place(x, y, core), s > 0.6) for _, _, x, y, core, _, s, t in NODES if t)
          + lab('you', YOU[0], YOU[1] - 8, True, 'glow-primary-foreground') + lab('one question waiting', WAIT[0], WAIT[1] + 12))
html = (f'<div layer-name="c:you-map/constellation/rest" style="width:{W}px;height:{H}px;flex-shrink:0;position:relative;overflow:hidden;'
        f'border-radius:{V("radius-card")};background:{C("background-raised")};box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 2px {C("depth-shadow-contact")}, 0 12px 28px -12px {C("depth-shadow-cast")}">'
        + ''.join(halos) + svg + labels + '</div>')
open('map.html', 'w').write(html)
