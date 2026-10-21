// node design-system/hifi/darkify.mjs <in.jsx> <out.html> <token-names.txt>
// M12: turns a Paper JSX export into HTML for its dark twin. Every var(--color-X) that has a
// var(--color-dark-X) pair is swapped for it; nothing else changes (process.md: "the dark version
// swaps each token for its --color-dark-… pair; no new values"). Prints the colour tokens with no
// dark pair, so each one is a decision (palette art stays, system chrome stays), not a silent miss.
import { readFileSync, writeFileSync } from 'node:fs';

const [inFile, outFile, namesFile] = process.argv.slice(2);
const names = new Set(readFileSync(namesFile, 'utf8').split('\n').filter(Boolean));
let src = readFileSync(inFile, 'utf8').trim().replace(/^\(\s*/, '').replace(/\s*\)\s*$/, '');

const kebab = (k) => k.replace(/^(Moz|Webkit)/, (m) => '-' + m.toLowerCase()).replace(/[A-Z]/g, (c) => '-' + c.toLowerCase());
// style={{ a: 'b', c: 'd' }} → style="a:b;c:d"
src = src.replace(/style=\{\{([^}]*)\}\}/g, (_, body) => {
  const decls = [...body.matchAll(/(\w+):\s*'((?:[^'\\]|\\.)*)'/g)].map(([, k, v]) => `${kebab(k)}:${v.replace(/"/g, "'")}`);
  return `style="${decls.join(';')}"`;
});
// svg attributes back to their HTML names
src = src.replace(/\b(strokeWidth|strokeLinecap|strokeLinejoin|fillRule|clipRule|stopColor|stopOpacity|strokeDasharray|fillOpacity|strokeOpacity)=/g, (_, a) => kebab(a) + '=');
// Paper ids would collide; layer names carry over through the id-less copy
src = src.replace(/\sid="[^"]*"/g, '');
src = src.replace(/\{' '\}/g, ' ').replace(/\{"([^"]*)"\}/g, '$1');

const unpaired = new Map();
src = src.replace(/var\(--color-([a-z0-9-]+)\)/g, (m, name) => {
  if (name.startsWith('dark-')) return m;
  if (names.has(`--color-dark-${name}`)) return `var(--color-dark-${name})`;
  unpaired.set(name, (unpaired.get(name) || 0) + 1);
  return m;
});
writeFileSync(outFile, src);
console.log(`${outFile}: ${src.length} chars`);
for (const [n, c] of [...unpaired].sort((a, b) => b[1] - a[1])) console.log(`  no dark pair: --color-${n} ×${c}`);
