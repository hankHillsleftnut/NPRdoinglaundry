# M12: from a Paper JSX export of a duplicated board, build the update_styles batches that turn it
# dark. Each var(--color-X) with a --color-dark-X pair is swapped; nothing else changes.
# Output: JSON list of {nodeIds, styles}, grouped so one entry sets one property on many nodes.
# Apple's status bar is system chrome: its black glyphs become the dark text colour, as iOS does.
# usage: python3 dark_updates.py <jsx-tool-result.txt> <token-names.txt> <out.json> [duplicate-result.json]
# 20 Oct (dark recalibration): svg child paths are addressed by id. Paper numbers an svg's descendants
# after the svg id, visiting the last child first, depth-first (svg ABC → last path ABD, a group ABD → its
# path ABE). When the duplicate_nodes result is given, every computed id is checked against its
# descendantIdMap; an id that isn't there is reported, never written.
import json, re, sys
from collections import defaultdict

src = json.load(open(sys.argv[1]))[1]['text']
names = set(open(sys.argv[2]).read().split())
VAR = re.compile(r'var\(--color-([a-z0-9-]+)\)')
unpaired = defaultdict(int)

def swap(v):
    def one(m):
        n = m.group(1)
        if n.startswith('dark-'):
            return m.group(0)
        if f'--color-dark-{n}' in names:
            return f'var(--color-dark-{n})'
        unpaired[n] += 1
        return m.group(0)
    return VAR.sub(one, v)

SYSTEM = {'#000000': 'var(--color-dark-text-primary)', '#00000059': 'var(--color-dark-text-tertiary)'}
COLOR_PROPS = {'color', 'backgroundColor', 'backgroundImage', 'boxShadow', 'borderColor', 'outline',
               'outlineColor', 'borderTopColor', 'borderBottomColor', 'textShadow', 'fill', 'stroke'}
groups = defaultdict(list)

# every opening tag with an id: <tag ... id="X" ... style={{ ... }} ...>
for m in re.finditer(r'<(\w+)\b([^>]*?)\bid="([^"]+)"([^>]*)>', src):
    attrs = m.group(2) + m.group(4)
    nid = m.group(3)
    sm = re.search(r'style=\{\{(.*?)\}\}', attrs, re.S)
    if sm:
        for k, v in re.findall(r"(\w+):\s*'((?:[^'\\]|\\.)*)'", sm.group(1)):
            if k not in COLOR_PROPS:
                continue
            nv = SYSTEM.get(v, swap(v))
            if nv != v:
                groups[(k, nv)].append(nid)

A = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
def plus(i, n):
    v = 0
    for c in i[:-2]:
        v = v * 36 + A.index(c)
    v += n; o = ''
    while v:
        o = A[v % 36] + o; v //= 36
    return o + '-0'

valid = None
if len(sys.argv) > 4:
    d = json.load(open(sys.argv[4]))
    valid = set(d['duplicatedNodes'][0]['descendantIdMap'].values())
TAG = re.compile(r'<(/?)(\w+)\b((?:[^>"]|"[^"]*")*?)(/?)>')
bad_ids = []
for m in re.finditer(r'<svg\b[^>]*\bid="([^"]+)"[^>]*>(.*?)</svg>', src, re.S):
    sid, body = m.group(1), m.group(2)
    root = {'tag': 'svg', 'attrs': '', 'kids': []}
    stack = [root]
    for t in TAG.finditer(body):
        close, tag, attrs, selfclose = t.groups()
        if close:
            if len(stack) > 1: stack.pop()
            continue
        node = {'tag': tag, 'attrs': attrs, 'kids': []}
        stack[-1]['kids'].append(node)
        if not selfclose: stack.append(node)
    n = [0]
    def visit(node):
        for k in reversed(node['kids']):
            n[0] += 1
            k['id'] = plus(sid, n[0])
            visit(k)
    visit(root)
    def each(node):
        for k in node['kids']:
            yield k
            yield from each(k)
    for k in each(root):
        for attr in ('fill', 'stroke'):
            a = re.search(rf'\b{attr}="([^"]+)"', k['attrs'])
            if not a: continue
            v = a.group(1); nv = SYSTEM.get(v, swap(v))
            if nv == v: continue
            if valid is not None and k['id'] not in valid:
                bad_ids.append((sid, k['id'])); continue
            groups[(attr, nv)].append(k['id'])

out = [{'nodeIds': ids, 'styles': {k: v}} for (k, v), ids in groups.items()]
json.dump({'updates': out}, open(sys.argv[3], 'w'))
if bad_ids: print('  svg ids not in the duplicate (skipped):', bad_ids[:20], len(bad_ids))
print(len(out), 'groups,', sum(len(i) for i in groups.values()), 'node-props (svg paths included)')
for n, c in sorted(unpaired.items(), key=lambda x: -x[1]):
    print(f'  no dark pair: --color-{n} x{c}')
