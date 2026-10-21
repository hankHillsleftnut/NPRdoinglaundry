import json
from review import *
base = json.load(open('../icons/base.json')); ink = json.load(open('../icons/icons.json'))
def svg(geo, kind, px, sw=1.75):
    a = f'fill="none" stroke="{C("icon-default")}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"' if kind == 'stroke' else f'fill="{C("icon-default")}"'
    geo = geo.replace('fill="currentColor"', f'fill="{C("icon-default")}"').replace('var(--cut,#F4F2EE)', C('background-canvas'))
    return f'<svg width="{px}" height="{px}" viewBox="0 0 24 24" {a}>{geo}</svg>'
cells = []
for k in base:
    kind = base[k][0]
    changed = base[k][1] != ink[k][1]
    cells.append(f'<div layer-name="icon · {k}" style="width:132px;display:flex;flex-direction:column;gap:{V("spacing-2")};padding:{V("spacing-3")};border-radius:{V("radius-default")};background:{C("background-raised") if changed else "transparent"}">'
                 f'<div style="display:flex;gap:{V("spacing-3")};align-items:center">{svg(base[k][1], kind, 48)}{svg(ink[k][1], kind, 48)}</div>'
                 f'<div style="display:flex;gap:{V("spacing-4")};align-items:center">{svg(base[k][1], kind, 24)}{svg(ink[k][1], kind, 24)}</div>'
                 + label(k + (' · ink' if changed else '')) + '</div>')
grid = f'<div style="display:flex;flex-wrap:wrap;gap:{V("spacing-3")};width:1400px">' + ''.join(cells) + '</div>'
close = ''.join(tile(f'<div style="display:flex;gap:{V("spacing-2")}">' + svg(base[k][1], base[k][0], 144) + svg(ink[k][1], base[k][0], 144) + '</div>', f'6× · {k} · before | after')
                for k in ['check', 'arrow-right', 'calendar', 'you', 'search', 'brief'])
head = (f'<div style="display:flex;gap:{V("spacing-3")};align-items:baseline">' + label('part 00')
        + f'<div style="font-family:{V("font-display")};font-size:{V("text-2xl")};letter-spacing:{V("tracking-title")};color:{C("text-primary")}">the icon set · ink joins</div>'
        + f'<div style="font-family:{V("font-text")};font-size:{V("text-md")};color:{C("text-secondary")}">wherever strokes meet, the ink pools. each cell: before | after, at 2× then 1×. raised cells changed.</div></div>')
html = f'<div layer-name="part 00 · the icon set · ink joins" style="display:flex;flex-direction:column;gap:{V("spacing-6")}">' + head + f'<div style="display:flex;gap:{V("spacing-10")};flex-wrap:wrap">{close}</div>' + grid + '</div>'
open('p00.html', 'w').write(html)
print(len(html))
