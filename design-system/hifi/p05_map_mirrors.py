from review import *
# Part 05 · you map · six straight-line variations in the "space mirror" style (founder, 20 Oct: c-dihuje, c-odr62e).
# The look is taken from "the moment" on 02 · components: each thing is a glass sphere (two radial gradients catching light,
# a top rim, a hairline, a soft cast), far things are out of focus (blur + dimmed), threads are straight hairlines to the centres.
# Frosted (founder, 20 Oct): a 12% white glass under the gradients and a 1.5 backdrop blur, so threads and rings behind an orb
# show as a soft smear ("see through, but blurring the line below"). Orbits was picked; the other five are archived.
# No card around the map. The constellation on 02 · components is marked hand-crafted: the founder works on it.
W, H = 390, 360
GLASS = {  # (light, shadow) gradient pairs, as in "the moment"
    'sky': ('radial-gradient(ellipse 80% 70% at 25% 10% in oklab, {a} 0%, transparent 100%), radial-gradient(ellipse 80% 80% at 100% 100% in oklab, {b} 0%, transparent 100%)', 'sky-300', 'sky-700'),
    'amber': ('radial-gradient(ellipse 70% 60% at 85% 15% in oklab, {a} 0%, transparent 100%), radial-gradient(ellipse 90% 90% at 0% 100% in oklab, {b} 0%, transparent 100%)', 'map-node-theme', 'sky-800'),
    'pearl': ('radial-gradient(ellipse 70% 60% at 80% 10% in oklab, {a} 0%, transparent 100%), radial-gradient(ellipse 80% 80% at 10% 90% in oklab, {b} 0%, transparent 100%)', 'sky-200', 'paper-300'),
    'green': ('radial-gradient(ellipse 70% 60% at 30% 15% in oklab, {a} 0%, transparent 100%), radial-gradient(ellipse 85% 85% at 90% 95% in oklab, {b} 0%, transparent 100%)', 'map-node-goal', 'sky-800'),
}
def sphere(x, y, d, kind, far=0):
    tpl, a, b = GLASS[kind]
    bg = tpl.format(a=C(a), b=C(b))
    blur = {0: '', 1: f'filter:blur(1.5px);opacity:{V("opacity-pressed")};', 2: f'filter:blur(2.5px);opacity:{V("opacity-dimmed")};'}[far]
    cast = f'0 {round(d / 6)}px {round(d / 3)}px -{round(d / 12) + 1}px {C("depth-shadow-cast")}'
    return (f'<div style="position:absolute;left:{x - d / 2:.0f}px;top:{y - d / 2:.0f}px;width:{d}px;height:{d}px;border-radius:{V("radius-control")};'
            f'background-color:{C("alpha-white12")};backdrop-filter:blur({3 if far else 1.5}px);background-image:{bg};box-shadow:inset 0 1px 0 {C("glow-primary-rim")}, 0 0 0 0.5px {C("depth-stroke-outer")}, {cast};{blur}"></div>')
def you(x, y, d=64):
    return (f'<div style="position:absolute;left:{x - d / 2:.0f}px;top:{y - d / 2:.0f}px;width:{d}px;height:{d}px;border-radius:{V("radius-control")};'
            f'background-image:radial-gradient(circle farthest-corner at 34% 28% in oklab, {C("sky-300")} 0%, {C("map-node-self")} 55%, {C("sky-800")} 100%);'
            f'box-shadow:inset 0 1px 0 {C("glow-primary-rim")}, 0 0 0 4px {C("background-canvas")}, 0 0 0 5px {C("glow-primary-ring")}, 0 10px 22px -8px {C("depth-tint-primary")}, 0 0 48px {C("glow-primary-bloom")}"></div>')
def label(t, x, y, side='right', strong=False):
    pos = f'left:{x}px;' if side == 'right' else f'left:{x - 120}px;width:120px;justify-content:flex-end;'
    return (f'<div style="position:absolute;{pos}top:{y - 8}px;display:flex;font-family:{V("font-label")};font-size:{V("text-xs")};line-height:{V("leading-snug")};'
            f'font-weight:{V("font-weight-medium") if strong else V("font-weight-regular")};color:{C("text-primary") if strong else C("text-secondary")}">{t}</div>')
def lines(pairs, strong=()):
    out = ''.join(f'<path d="M{a[0]} {a[1]}L{b[0]} {b[1]}" fill="none" stroke="var(--color-map-edge{"-strong" if (a, b) in strong else ""})" stroke-width="{1 if (a, b) in strong else 0.75}" stroke-linecap="round"/>' for a, b in pairs)
    return f'<svg width="{W}" height="{H}" viewBox="0 0 {W} {H}" style="position:absolute;left:0;top:0">{out}</svg>'
def frame(name, inner):
    return f'<div layer-name="c:you-map/{name}/rest" style="width:{W}px;height:{H}px;flex-shrink:0;position:relative;overflow:hidden">{inner}</div>'
Y = (195, 180)
# each node: (x, y, diameter, glass, far, label or None)
def build(name, nodes, extra_pairs=(), strong=(), labels=True, you_d=64):
    pairs = [(Y, (x, y)) for x, y, *_ in nodes] + list(extra_pairs)
    s = lines(pairs, strong) + ''.join(sphere(x, y, d, g, f) for x, y, d, g, f, _ in sorted(nodes, key=lambda n: -n[4])) + you(*Y, you_d)
    if labels:
        s += ''.join(label(t, x + d / 2 + 6 if x >= Y[0] else x - d / 2 - 6, y, 'right' if x >= Y[0] else 'left', d >= 48) for x, y, d, g, f, t in nodes if t)
    return frame(name, s)
V1 = build('burst', [(134, 145, 54, 'sky', 0, 'maya'), (243, 97, 40, 'amber', 0, 'running'), (306, 220, 58, 'pearl', 0, 'the river'), (166, 259, 36, 'sky', 0, 'sam'),
                     (73, 224, 30, 'amber', 1, None), (156, 35, 24, 'pearl', 2, None), (275, 319, 20, 'sky', 2, None), (343, 154, 16, 'amber', 2, None), (80, 100, 22, 'pearl', 1, None)])
# orbits: the near ring is what matters this week, the far ring is the rest
import math
def ring(r, angles, d, kinds, far, labs):
    return [(round(Y[0] + r * math.cos(math.radians(a))), round(Y[1] + r * math.sin(math.radians(a))), d, k, far, l) for a, k, l in zip(angles, kinds, labs)]
near = ring(92, [-150, -40, 30, 140], 44, ['sky', 'amber', 'pearl', 'green'], 0, ['maya', 'running', 'the river', 'work'])
far_ = ring(158, [-100, -10, 70, 110, 200], 20, ['pearl', 'sky', 'amber', 'pearl', 'sky'], 1, [None] * 5)
orbit_svg = f'<svg width="{W}" height="{H}" viewBox="0 0 {W} {H}" style="position:absolute;left:0;top:0"><circle cx="{Y[0]}" cy="{Y[1]}" r="92" fill="none" stroke="var(--color-map-edge)" stroke-width="0.5" opacity="0.5"/><circle cx="{Y[0]}" cy="{Y[1]}" r="158" fill="none" stroke="var(--color-map-edge)" stroke-width="0.5" opacity="0.35"/></svg>'
V2 = build('orbits', near + far_).replace('overflow:hidden">', 'overflow:hidden">' + orbit_svg, 1)
# clusters: people up-left, places down, goals right; the kind is the place on the page, not a legend
V3 = build('clusters', [(110, 110, 50, 'sky', 0, 'maya'), (70, 160, 30, 'sky', 0, 'sam'), (140, 62, 22, 'sky', 1, None),
                        (170, 300, 46, 'pearl', 0, 'the river'), (240, 316, 26, 'pearl', 1, None),
                        (318, 140, 44, 'green', 0, 'running'), (330, 214, 30, 'amber', 0, 'work'), (352, 90, 18, 'amber', 2, None)])
# web: threads between things too, not only to you, so what's linked shows
w_nodes = [(120, 120, 48, 'sky', 0, 'maya'), (280, 108, 40, 'amber', 0, 'running'), (300, 250, 52, 'pearl', 0, 'the river'), (110, 262, 34, 'green', 0, 'work'), (205, 60, 20, 'sky', 1, None), (200, 318, 18, 'pearl', 2, None)]
V4 = build('web', w_nodes, extra_pairs=[((120, 120), (205, 60)), ((205, 60), (280, 108)), ((280, 108), (300, 250)), ((300, 250), (200, 318)), ((120, 120), (110, 262))],
           strong=[(Y, (120, 120)), (Y, (300, 250))])
# depth: a few near, big and sharp; many far, small and soft, so the map has a front and a back
V5 = build('depth', [(96, 92, 66, 'sky', 0, 'maya'), (318, 262, 60, 'pearl', 0, 'the river'), (300, 80, 26, 'amber', 1, None), (70, 270, 24, 'green', 1, None),
                     (240, 40, 16, 'pearl', 2, None), (360, 170, 14, 'sky', 2, None), (30, 180, 14, 'amber', 2, None), (180, 330, 16, 'sky', 2, None), (150, 230, 30, 'amber', 0, 'running')], you_d=56)
# sparse: you and the five that matter most, sized by how much, lots of air
V6 = build('sparse', [(92, 120, 48, 'sky', 0, 'maya'), (300, 96, 36, 'green', 0, 'running'), (318, 262, 44, 'pearl', 0, 'the river'), (110, 286, 28, 'amber', 0, 'work'), (196, 44, 20, 'sky', 0, 'sam')], you_d=60)
vis = (tile(V1, '1 · burst · like "the moment", with names') + tile(V2, '2 · orbits · near ring this week, far ring the rest')
       + tile(V3, '3 · clusters · people, places, goals by position') + tile(V4, '4 · web · what links to what, not only to you')
       + tile(V5, '5 · depth · a front and a back, focus pulls') + tile(V6, '6 · sparse · you and the five that matter most'))
rows = {'purpose': ('✓', 'the picture it has of you; the map is the page (YO-1)'), 'colour': ('✓', 'glass recipes from "the moment": sky, amber, pearl, green, all tokens'),
        'type': ('✓', 'Geist 11 names, 500 for the big ones'), 'space': ('✓', '390 × 360, the YO-1 map area'), 'shape': ('✓', 'spheres only; straight hairline threads'),
        'depth': ('✓', 'rim + hairline + cast per sphere; far ones blur 1.5–2.5 and dim (opacity tokens)'), 'texture': ('—', 'grain (as in "the moment") added on the pick'),
        'tokens': ('✓', 'token-check'), 'goals': ('✓', 'no legend; size is how much; the kind reads from glass and place'), 'wireframe': ('✓', 'YO-1')}
open('p05.html', 'w').write(part(5, 'you map · six straight-line variations', 'space mirrors, no card; the constellation stays yours to hand-craft', vis, rows, 'waiting on your pick.'))
