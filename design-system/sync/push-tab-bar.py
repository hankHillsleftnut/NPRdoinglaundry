# M13: pushes the tab-bar masters onto every copy in one or more Paper exports.
# The selected tab is the item whose label is drawn in the primary text colour; every item is renamed to
# the master it should be a copy of (c:tab-bar/item/selected or /rest), and its styles are set to that
# master's: label colour and weight, the svg wrapper cleared, the icon path filled. Dark copies (labels
# in --color-dark-*) get the dark pairs. Icon paths are the svg id + 1 (Paper numbers a single child next).
# usage: python3 push-tab-bar.py <export.txt> [...] > push.json   → {renames: [...], updates: [...]}
import json, re, sys
from collections import defaultdict

A = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
def next_id(i):
    v = 0
    for c in i[:-2]:
        v = v * 36 + A.index(c)
    v += 1; o = ''
    while v:
        o = A[v % 36] + o; v //= 36
    return o + '-0'

def load(p):
    raw = open(p).read()
    try:
        return json.loads(raw)[1]['text']
    except Exception:
        return raw

# the masters' values come from their export (sync/snapshots/masters-tab-bar.json, cut from get_jsx of the
# master on 02 · components), so editing the master in Paper and re-exporting is all a change needs
def master_values(jsx):
    label = re.findall(r"style=\{\{([^}]*)\}\}", jsx)[-1]
    color = re.search(r"color: 'var\(--color-([a-z-]+)\)'", label).group(1)
    weight = re.search(r"fontWeight: '([^']+)'", label).group(1)
    icon = re.search(r'<path[^>]*fill="var\(--color-([a-z-]+)\)"', jsx).group(1)
    return {'label': {'color': color, 'fontWeight': weight}, 'icon': icon}
_m = json.load(open(__file__.replace('push-tab-bar.py', 'snapshots/masters-tab-bar.json')))
MASTER = {'selected': master_values(_m['tab-bar/item/selected']), 'rest': master_values(_m['tab-bar/item/rest'])}
renames, ups = [], defaultdict(list)
ITEM = re.compile(r"<div id=\"([^\"]+)\" style=\{\{[^}]*height: '48px'[^}]*width: '72px'[^}]*\}\}>\s*<svg[^>]*id=\"([^\"]+)\"[^>]*>.*?</svg>\s*<div id=\"([^\"]+)\" style=\{\{([^}]*)\}\}>", re.S)
for f in sys.argv[1:]:
    for m in ITEM.finditer(load(f)):
        item, svg, label, lstyle = m.groups()
        dark = '--color-dark-' in lstyle
        state = 'selected' if re.search(r"color: 'var\(--color-(dark-)?text-primary\)'", lstyle) else 'rest'
        tok = (lambda t: f'var(--color-dark-{t})') if dark else (lambda t: f'var(--color-{t})')
        renames.append({'nodeId': item, 'name': f'c:tab-bar/item/{state}'})
        spec = MASTER[state]
        ups[('color', tok(spec['label']['color']))].append(label)
        ups[('fontWeight', spec['label']['fontWeight'])].append(label)
        ups[('fill', '')].append(svg)
        ups[('fill', tok(spec['icon']))].append(next_id(svg))
out = {'renames': renames, 'updates': [{'nodeIds': ids, 'styles': {k: v}} for (k, v), ids in ups.items()]}
json.dump(out, sys.stdout, separators=(',', ':'))
print(f'\n{len(renames)} items', file=sys.stderr)
