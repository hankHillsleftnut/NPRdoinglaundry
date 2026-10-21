// shared by dark-sync.mjs and dark-audit.mjs
// ids inside a keep-light subtree: the subtree is found by its layer name, then by its span in the export
export function keptIds(jsx, rootIds) {
  const kept = new Set();
  for (const rid of rootIds) {
    const start = jsx.indexOf(`id="${rid}"`);
    if (start < 0) continue;
    const open = jsx.lastIndexOf('<', start);
    const tag = jsx.slice(open + 1).match(/^\w+/)[0];
    let depth = 0, i = open;
    const re = new RegExp(`<(/?)${tag}\\b[^>]*?(/?)>`, 'g'); re.lastIndex = open;
    let m, end = jsx.length;
    while ((m = re.exec(jsx))) {
      if (m[1]) depth--; else if (!m[2]) depth++;
      if (depth === 0) { end = re.lastIndex; break; }
    }
    for (const x of jsx.slice(open, end).matchAll(/\bid="([^"]+)"/g)) kept.add(x[1]);
    i = end;
  }
  return kept;
}

