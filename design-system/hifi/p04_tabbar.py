from review import *
import json, re, sys
from shapely.geometry import Polygon, MultiPolygon
# Part 04 · tab bar · three versions. Run with the icon venv (shapely).
# The shipped icons are single outlines at a 1.75 stroke, so "weight, not colour" (tab-bar rule 3) is made by growing the outline:
# +0.225 on each side gives the 2.2 emphasis stroke, with the ink joins kept (they grow with it).
O = json.load(open('../icons/outlined.json'))
def geom(d):   # the shipped paths are fitted curves now (C commands): sample each segment, then rebuild with even-odd
    from svgpathtools import parse_path
    g = None
    for sub in parse_path(d).continuous_subpaths():
        pts = [(z.real, z.imag) for seg in sub for z in (seg.point(t / 12) for t in range(12))]
        p = Polygon(pts).buffer(0)
        g = p if g is None else g.symmetric_difference(p)
    return g
def to_d(g):
    out = []
    for p in (g.geoms if isinstance(g, MultiPolygon) else [g]):
        for r in [p.exterior, *p.interiors]:
            c = list(r.coords)[:-1]
            out.append('M' + 'L'.join(f'{x:.2f} {y:.2f}' for x, y in c) + 'Z')
    return ''.join(out)
EMPH = {n: to_d(geom(O[n]).buffer(0.225, quad_segs=16).simplify(0.012)) for n in ['journal', 'podcasts', 'goals', 'you']}
REST = {n: O[n] for n in ['journal', 'podcasts', 'goals', 'you']}   # the shipped curves, untouched
def icon(n, sel, size=22):
    d = EMPH[n] if sel else REST[n]
    return (f'<svg layer-name="c:icon/{n}{"/emphasis" if sel else ""}" width="{size}" height="{size}" viewBox="0 0 24 24" style="display:inline-block;flex-shrink:0">'
            f'<path fill="{C("text-primary") if sel else C("icon-muted")}" fill-rule="evenodd" d="{d}"/></svg>')
TABS = ['journal', 'podcasts', 'goals', 'you']
def slot(n, sel, wash=False, k=1):
    lab = (f'<div style="font-family:{V("font-label")};font-size:{V("text-xs")};line-height:{V("leading-snug")};letter-spacing:{V("tracking-label")};'
           f'font-weight:{V("font-weight-medium") if sel else V("font-weight-regular")};color:{C("text-primary") if sel else C("text-label")}">{n}</div>')
    bg = f'background:{C("surface-wash")};border-radius:{V("radius-control")};' if wash and sel else ''
    return (f'<div layer-name="c:tab-bar/item/{"selected" if sel else "rest"}" style="width:72px;height:48px;flex-shrink:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:{V("spacing-size-border-ring")};{bg}">'
            + icon(n, sel) + lab + '</div>')
def items(sel, wash=False):
    return ''.join(slot(n, n == sel, wash) for n in TABS)
# a bit of the journal behind, so the edge has something to fade
BEHIND = (f'<div style="position:absolute;left:{V("spacing-6")};right:{V("spacing-6")};top:{V("spacing-4")};display:flex;flex-direction:column;gap:{V("spacing-3")}">'
          f'<div style="align-self:flex-end;max-width:250px;padding:{V("spacing-3")} {V("spacing-4")};border-radius:{V("radius-message")} {V("radius-message")} {V("spacing-size-border-inset")} {V("radius-message")};background:{C("message-mine")};font-family:{V("font-text")};font-size:{V("text-body")};letter-spacing:{V("tracking-card")};line-height:{V("leading-snug")};color:{C("text-primary")}">i think it\'s the 9am standup. i dread it.</div>'
          f'<div style="max-width:300px;font-family:{V("font-text")};font-size:{V("text-body")};letter-spacing:{V("tracking-card")};line-height:{V("leading-normal")};color:{C("text-primary")}">want me to keep an eye on how mondays go for the next few weeks?</div></div>')
HOME = f'<div style="position:absolute;left:0;right:0;bottom:{V("spacing-2")};display:flex;justify-content:center"><div layer-name="home indicator" style="width:134px;height:5px;border-radius:{V("radius-control")};background:{C("text-primary")}"></div></div>'
def phone_bottom(inner):
    return (f'<div layer-name="phone · bottom 240" style="width:390px;height:240px;position:relative;overflow:hidden;background:{C("background-canvas")};'
            f'border-radius:0 0 {V("radius-sheet")} {V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">' + BEHIND + inner + HOME + '</div>')
# One structure for all three, so B and C are copies of A with the bar's style changed (the sync compares copies to masters this way)
# The progressive blur is one masked layer in the app (tab-bar.md). Paper cannot mask a backdrop blur, so on the board the thread is
# drawn twice (sharp, masked out; blurred 6, masked in) by hand on the Paper node; here only the canvas tint is generated.
FADE = f'<div layer-name="canvas tint" style="position:absolute;left:0;bottom:0;width:390px;height:170px;background:linear-gradient(180deg, transparent 0%, {C("background-canvas")} 75%)"></div>'
PILL = (f'border-radius:{V("radius-control")};background:{C("background-raised")};padding:{V("spacing-1")};gap:{V("spacing-0")};'
        f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 2px {C("depth-shadow-contact")}, 0 12px 28px -12px {C("depth-shadow-cast")}, 0 24px 60px -20px {C("depth-shadow-ambient")}')
def version(name, bar_style, wash=False):
    return phone_bottom(FADE + f'<div layer-name="dock" style="position:absolute;left:0;right:0;bottom:{V("spacing-8")};display:flex;justify-content:center">'
                        + f'<div layer-name="c:tab-bar/{name}/rest" style="display:flex;{bar_style}">' + items('journal', wash) + '</div></div>')
A = version('system', f'gap:{V("spacing-3")}')        # A · the system bar: no plate, no line; the page fades into the canvas under it (iOS 26 soft scroll edge)
B = version('floating', PILL)                          # B · a floating pill, selection by weight only
C_ = version('floating-wash', PILL, wash=True)         # C · the pill, with the selected tab on a wash (concentric: 28 − 4 = 24)
# 4× of one slot each way, so the emphasis weight and the label weight can be read
big = lambda n, sel: (f'<div style="display:flex;flex-direction:column;align-items:center;gap:{V("spacing-2")}">'
                      + icon(n, sel, 88) + f'<div style="font-family:{V("font-label")};font-size:{V("text-4xl")};font-weight:{V("font-weight-medium") if sel else V("font-weight-regular")};color:{C("text-primary") if sel else C("text-label")}">{n}</div></div>')
Z = f'<div style="display:flex;gap:{V("spacing-12")};align-items:flex-end;padding:{V("spacing-6")};background:{C("background-canvas")};border-radius:{V("radius-card")}">' + big('journal', True) + big('podcasts', False) + '</div>'
vis = (tile(A, 'A · system bar · soft scroll edge, no plate (as specced)') + tile(B, 'B · floating pill · weight only')
       + tile(C_, 'C · floating pill · the selected tab on a wash') + tile(Z, '4× · selected (2.2 emphasis, Geist 500) | rest (1.75, icon.muted, Geist 400)'))
rows = {
 'purpose': ('✓', 'the four places, always there; never an action (tab-bar spec)'),
 'colour': ('✓', 'no accent: selected is text.primary at 2.2, others icon.muted at 1.75 (rule 3: weight, not colour)'),
 'type': ('✓', 'Geist 11, 500 selected / 400 rest, +0.01em; was mono in the spec (founder: Geist for labels)'),
 'space': ('✓', '72 slots, icon 22 over the label 2 apart, the pair centred by mass; A sits on the home inset (32); B and C float 30 above the bottom'),
 'shape': ('✓', 'B and C: the pill 28 radius, 4 inset, so C\'s wash is 24: concentric'),
 'depth': ('✓', 'A: no plate, only the fade (z: chrome over content). B and C: raised, dual shadow (contact + cast + ambient)'),
 'texture': ('—', 'none'),
 'icon': ('✓', 'the shipped ink-joined outlines; the selected one grown 0.225 a side (2.2 stroke), joins kept'),
 'tokens': ('✓', 'all colour, radius, spacing, type tokens; widths, the 34 inset and the home indicator are frame sizes'),
 'optical centring': ('✓', 'goals and you are round, journal and podcasts are not: each icon is centred by its 24 grid, which already holds them optically'),
 'contrast': ('✓', 'selected ≈ 15 : 1; rest icon 3.3 : 1 (non-text, passes 3 : 1); rest label 5.2 : 1'),
 'hit area': ('✓', 'each slot 72 × 48, and in A the full 49 bar height; over 44 everywhere'),
 'states': ('—', 'rest drawn; pressed (opacity.pressed), focused ring and dark follow the pick'),
 'motion': ('✓', 'change: old weight down, new up, 140ms; C\'s wash slides to the new tab (spring 0.25 / 0.85, as the title menu)'),
 'haptic': ('✓', 'haptic.tab on change'),
 'goals': ('✓', 'rule 1 four tabs; rule 2 no badges'),
 'wireframe': ('✓', 'same four slots and order as every mid-fi page'),
}
open('p04_a.html', 'w').write(part(4, 'tab bar · three versions', 'the four places, quiet, always there', tile(A, 'A · system bar · soft scroll edge, no plate (as specced)'), rows, 'waiting on your pick. my lean: A (it lets the page breathe); C if you want the floating feel everywhere.'))
open('p04.html', 'w').write(part(4, 'tab bar · three versions', 'the four places, quiet, always there', vis, rows, 'waiting on your pick. my lean: A (it lets the page breathe); C if you want the floating feel everywhere.'))
