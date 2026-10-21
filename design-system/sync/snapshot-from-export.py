# Builds a paper-sync snapshot from Paper exports, so the sync can run on real screens.
# usage: python3 snapshot-from-export.py <export.txt> <master.jsx> <out.json> <component> <copy-id>=<name>=<screen> ...
#   export.txt  a get_jsx tool result saved by the harness (JSON [header, {text}]) or a plain .jsx file
#   master.jsx  the master's JSX; its direct children are the item masters, keyed by the names given with --item
# Copies are cut out of the export by id (a balanced-tag walk), so one export of a board covers every copy on it.
import json, re, sys

def load(path):
    raw = open(path).read()
    try:
        return json.loads(raw)[1]['text']
    except Exception:
        return raw

def subtree(src, nid):
    m = re.search(r'<(\w+)\b[^>]*\bid="%s"' % re.escape(nid), src)
    if not m:
        return None
    depth, i = 0, m.start()
    for t in re.finditer(r'<(/?)(\w+)\b[^>]*?(/?)>', src[i:]):
        if t.group(3):            # self-closing
            if depth == 0:
                return src[i:i + t.end()]
            continue
        depth += -1 if t.group(1) else 1
        if depth == 0:
            return src[i:i + t.end()]
    return None

export, master_file, out = sys.argv[1], sys.argv[2], sys.argv[3]
masters = json.load(open(master_file)) if master_file.endswith('.json') else {}
src = load(export)
copies = []
for arg in sys.argv[4:]:
    nid, name, screen = arg.split('=')
    jsx = subtree(src, nid)
    copies.append({'id': nid, 'name': name, 'screen': screen, 'jsx': jsx or ''})
json.dump({'masters': masters, 'copies': copies}, open(out, 'w'))
print(len(copies), 'copies,', sum(1 for c in copies if c['jsx']), 'found in the export')
