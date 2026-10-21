// node design-system/sync/paper-sync.mjs <snapshot.json> [...]
// The wiring between masters and copies (components/README.md, "Masters, copies and the sync").
// A snapshot is { masters: { "<component/variant/state>": "<jsx>" }, copies: [{ name, screen, jsx }] },
// read from Paper with get_jsx. Copies may differ in text; every style must match the master's.
// Prints each copy that drifted, and which style differs, so the master can be pushed or the copy made a variant.
import { readFileSync } from 'node:fs';

const styles = (jsx) => [...jsx.matchAll(/style=\{\{([^}]*)\}\}/g)].map(([, s]) =>
  Object.fromEntries([...s.matchAll(/(\w+):\s*'([^']*)'/g)].map(([, k, v]) => [k, v])));

let drift = 0, checked = 0;
for (const file of process.argv.slice(2)) {
  const { masters, copies } = JSON.parse(readFileSync(file, 'utf8'));
  for (const copy of copies) {
    const key = copy.name.replace(/^c:/, '');
    const master = masters[key];
    checked++;
    if (!master) { console.log(`✗ ${copy.screen}: ${copy.name} has no approved master`); drift++; continue; }
    const a = styles(master), b = styles(copy.jsx);
    if (a.length !== b.length) { console.log(`✗ ${copy.screen}: ${copy.name} has ${b.length} layers, master has ${a.length}`); drift++; continue; }
    a.forEach((m, i) => {
      for (const k of new Set([...Object.keys(m), ...Object.keys(b[i])])) {
        if (m[k] !== b[i][k]) { console.log(`✗ ${copy.screen}: ${copy.name} layer ${i} ${k}: master "${m[k] ?? '—'}", copy "${b[i][k] ?? '—'}"`); drift++; }
      }
    });
  }
}
console.log(`${checked} copies checked, ${drift} difference(s)`);
process.exit(drift ? 1 : 0);
