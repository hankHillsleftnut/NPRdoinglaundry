# YO-1 map versions for c-e52ubp ("more centered, the constellation should feel more real; a couple versions").
# A is the shipped orbit map, re-centred in Paper. B and C are drawn here. Positions are geometry (raw px is
# allowed); every colour and opacity is a token. Paper drops `position` from pasted HTML: set position:absolute on the children with update_styles after
# writing. Writes p50_map_b.html and p50_map_c.html (390 × 420 canvases).
import math, random
from review import V, C

W, H = 390, 420
CX, CY = 195, 210

def label(text, x, y, align='center', strong=False):
    tx = {'center': 'translateX(-50%)', 'left': 'none', 'right': 'translateX(-100%)'}[align]
    return (f'<div style="position:absolute;left:{x}px;top:{y}px;transform:{tx};width:max-content;font-family:{V("font-label")};font-size:{V("text-xs")};'
            f'line-height:{V("leading-snug")};color:{C("text-primary" if strong else "text-secondary")}">{text}</div>')

def svg(lines):
    return (f'<svg width="{W}" height="{H}" viewBox="0 0 {W} {H}" style="position:absolute;left:0;top:0">'
            + ''.join(lines) + '</svg>')

def line(a, b, width, colour='map-edge', op=None, dash=False):
    o = f' style="opacity:{V(op)}"' if op else ''
    d = ' stroke-dasharray="2 3"' if dash else ''
    return f'<path d="M{a[0]} {a[1]}L{b[0]} {b[1]}" fill="none" stroke="{C(colour)}" stroke-width="{width}" stroke-linecap="round"{d}{o}/>'

# ---------- B · night sky: stars with light, a field of things not yet connected ----------
def star(kind, x, y, core, op=None):
    box = core * 4
    o = f'opacity:{V(op)};' if op else ''
    return (f'<div layer-name="star · {kind}" style="position:absolute;left:{x - box / 2}px;top:{y - box / 2}px;width:{box}px;height:{box}px;border-radius:{V("radius-control")};{o}'
            f'background-image:radial-gradient(circle farthest-corner at 50% 50% in oklab, {C(f"map-star-{kind}-core")} 0%, {C(f"map-star-{kind}-core")} 16%, {C(f"map-star-{kind}-halo")} 22%, transparent 68%)"></div>')

B_NODES = {  # name: (kind, x, y, core, label side)
    'you': ('self', CX, CY, 22, None),
    'maya': ('person', 112, 136, 12, 'above'),
    'sam': ('person', 92, 262, 8, 'below'),
    'mum': ('person', 300, 302, 7, 'below'),
    'running': ('goal', 286, 118, 11, 'above'),
    'sleep by 11': ('goal', 318, 214, 8, 'right'),
    'the river': ('place', 232, 330, 10, 'below'),
    'lisbon': ('place', 58, 186, 6, 'below'),
    'morning pages': ('writing', 170, 74, 7, 'above'),
}
B_LINKS = [('you', n, 1.25 if B_NODES[n][3] >= 10 else 0.75) for n in B_NODES if n != 'you']
B_CROSS = [('maya', 'running'), ('maya', 'lisbon'), ('the river', 'mum'), ('running', 'sleep by 11'), ('sam', 'maya')]

def map_b():
    rnd = random.Random(7)
    field = []
    while len(field) < 46:
        x, y = rnd.uniform(8, W - 8), rnd.uniform(8, H - 8)
        if math.hypot(x - CX, y - CY) < 40: continue
        s = rnd.choice([2, 2, 2, 3, 3, 4])
        field.append(f'<div style="position:absolute;left:{x:.0f}px;top:{y:.0f}px;width:{s}px;height:{s}px;border-radius:{V("radius-control")};'
                     f'background:{C("map-star-field")};opacity:{V(rnd.choice(["opacity-dimmed", "opacity-dimmed", "opacity-disabled"]))}"></div>')
    pos = {n: (v[1], v[2]) for n, v in B_NODES.items()}
    lines = [line(pos[a], pos[b], w) for a, b, w in B_LINKS]
    lines += [line(pos[a], pos[b], 0.5, op='opacity-disabled', dash=True) for a, b in B_CROSS]
    stars = [star(k, x, y, c) for n, (k, x, y, c, _) in B_NODES.items()]
    labels = []
    for n, (k, x, y, c, side) in B_NODES.items():
        if not side: continue
        off = c * 1.6 + 4
        if side == 'above': labels.append(label(n, x, y - off - 14))
        elif side == 'below': labels.append(label(n, x, y + off))
        else: labels.append(label(n, x + off, y - 8, 'left'))
    return (f'<div layer-name="c:you-map/stars/rest" style="position:relative;width:{W}px;height:{H}px;flex-shrink:0">'
            + ''.join(field) + svg(lines) + ''.join(stars) + ''.join(labels) + '</div>')

# ---------- C · neighbourhoods: the same glass orbs, sized by how often they come up, grouped ----------
GLASS = {
    'person': (f'radial-gradient(ellipse 70% 60% at 80% 10% in oklab, {C("map-node-person")} 0%, transparent 100%), radial-gradient(ellipse 80% 80% at 10% 90% in oklab, {C("sky-700")} 0%, transparent 100%)'),
    'place': (f'radial-gradient(ellipse 70% 60% at 80% 10% in oklab, {C("map-node-place")} 0%, transparent 100%), radial-gradient(ellipse 80% 80% at 10% 90% in oklab, {C("paper-500")} 0%, transparent 100%)'),
    'goal': (f'radial-gradient(ellipse 70% 60% at 30% 15% in oklab, {C("map-node-goal")} 0%, transparent 100%), radial-gradient(ellipse 85% 85% at 90% 95% in oklab, {C("green-600")} 0%, transparent 100%)'),
}
def orb(kind, x, y, d, far=False):
    blur = 'filter:blur(1.5px);' if far else ''
    op = f'opacity:{V("opacity-pressed")};' if far else ''
    return (f'<div layer-name="orb · {kind}" style="position:absolute;left:{x - d / 2}px;top:{y - d / 2}px;width:{d}px;height:{d}px;border-radius:{V("radius-control")};{blur}{op}'
            f'background-color:{C("alpha-white12")};background-image:{GLASS[kind]};'
            f'box-shadow:inset 0 1px 0 {C("glow-primary-rim")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 {max(3, d // 7)}px {max(7, d // 3)}px -{max(3, d // 9)}px {C("depth-shadow-cast")}"></div>')
def self_orb():
    return (f'<div layer-name="orb · you" style="position:absolute;left:{CX - 28}px;top:{CY - 28}px;width:56px;height:56px;border-radius:{V("radius-control")};'
            f'background-image:radial-gradient(circle farthest-corner at 34% 28% in oklab, {C("sky-300")} 0%, {C("map-node-self")} 55%, {C("sky-800")} 100%);'
            f'box-shadow:inset 0 1px 0 {C("glow-primary-rim")}, 0 0 0 4px {C("background-canvas")}, 0 0 0 5px {C("glow-primary-ring")}, 0 10px 22px -8px {C("depth-tint-primary")}, 0 0 48px {C("glow-primary-bloom")}"></div>')
def hood(kind, x, y, r):
    return (f'<div layer-name="neighbourhood · {kind}" style="position:absolute;left:{x - r}px;top:{y - r}px;width:{2 * r}px;height:{2 * r}px;border-radius:{V("radius-control")};'
            f'background-image:radial-gradient(circle farthest-corner at 50% 50% in oklab, {C(f"map-star-{kind}-halo")} 0%, transparent 68%);opacity:{V("opacity-disabled")}"></div>')

C_HOODS = [('person', 'people', 112, 128, 92), ('goal', 'habits', 292, 150, 80), ('place', 'places', 210, 322, 84)]
C_NODES = [  # kind, name, x, y, size (8–56 by mentions), far
    ('person', 'maya', 104, 112, 46, False), ('person', 'sam', 60, 168, 24, False), ('person', 'mum', 150, 70, 18, False), ('person', '', 40, 96, 10, True),
    ('goal', 'running', 296, 124, 40, False), ('goal', 'sleep by 11', 334, 194, 22, False), ('goal', '', 254, 82, 10, True),
    ('place', 'the river', 230, 318, 36, False), ('place', 'lisbon', 162, 356, 20, False), ('place', '', 286, 372, 10, True),
]
C_INNER = [('maya', 'sam'), ('maya', 'mum'), ('running', 'sleep by 11'), ('the river', 'lisbon')]
C_ACROSS = [('maya', 'the river'), ('running', 'the river')]

def map_c():
    pos = {n: (x, y) for _, n, x, y, _, _ in C_NODES if n}
    size = {n: d for _, n, _, _, d, _ in C_NODES if n}
    lines = []
    for _, n, x, y, d, far in C_NODES:
        w = 0.5 + 2.5 * (d - 8) / 48
        lines.append(line((CX, CY), (x, y), round(w, 2), 'map-edge-strong' if d >= 36 else 'map-edge', 'opacity-disabled' if far else None))
    lines += [line(pos[a], pos[b], 0.75) for a, b in C_INNER]
    lines += [line(pos[a], pos[b], 0.5, op='opacity-disabled', dash=True) for a, b in C_ACROSS]
    hoods = [hood(k, x, y, r) for k, _, x, y, r in C_HOODS]
    hood_labels = [label(t, x, y + r - 14 if k == 'place' else y - r + 6) for k, t, x, y, r in C_HOODS]  # places reads under its group, clear of you
    orbs = [orb(k, x, y, d, far) for k, _, x, y, d, far in C_NODES]
    labels = [label(n, x, y + d / 2 + 4, strong=d >= 36) for _, n, x, y, d, _ in C_NODES if n]
    return (f'<div layer-name="c:you-map/neighbourhoods/rest" style="position:relative;width:{W}px;height:{H}px;flex-shrink:0">'
            + ''.join(hoods) + svg(lines) + ''.join(orbs) + self_orb() + ''.join(labels) + ''.join(hood_labels) + '</div>')

if __name__ == '__main__':
    open('p50_map_b.html', 'w').write(map_b())
    open('p50_map_c.html', 'w').write(map_c())
