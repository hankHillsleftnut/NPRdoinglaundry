// node design-system/tokens/validate.mjs  ->  checks tokens.json and writes TOKENS.md
// Rules: every reference resolves; every semantic token has a purpose ($description);
// semantic colours have a dark value; no semantic name describes a look ("blue", "cream"...).
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const T = JSON.parse(readFileSync(join(here, 'tokens.json'), 'utf8'));
const LOOK_WORDS = /\b(blue|sky|cream|paper|night|grey|gray|red|green|amber|white|black|beige|warm|cool)\b/i;
const errors = [];
const tokens = [];

(function walk(node, path) {
  if (node && typeof node === 'object' && '$value' in node) { tokens.push({ path: path.join('.'), node }); return; }
  for (const [k, v] of Object.entries(node ?? {})) if (!k.startsWith('$') && typeof v === 'object') walk(v, [...path, k]);
})(T, []);

const byPath = new Map(tokens.map((t) => [t.path, t]));
const refs = (v) => JSON.stringify(v).match(/\{[a-zA-Z0-9_.]+\}/g) ?? [];
for (const { path, node } of tokens) {
  const semantic = !path.startsWith('palette.');
  for (const r of [...refs(node.$value), ...refs(node.$extensions?.retrospect?.dark ?? '')]) {
    if (!byPath.has(r.slice(1, -1))) errors.push(`${path}: reference ${r} does not exist`);
  }
  if (semantic && !node.$description) errors.push(`${path}: no purpose ($description)`);
  if (semantic && node.$type === 'color' && node.$extensions?.retrospect?.dark === undefined) errors.push(`${path}: no dark value`);
  if (semantic && LOOK_WORDS.test(path.split('.').slice(1).join(' ').replace(/([A-Z])/g, ' $1'))) errors.push(`${path}: name describes a look, not a purpose`);
  if (semantic && !node.$extensions?.retrospect?.source) errors.push(`${path}: no source (paywall / lime / to set)`);
}

const show = (v) => (typeof v === 'object' ? JSON.stringify(v) : String(v)).replace(/\|/g, '\\|');
const groups = new Map();
for (const t of tokens) { const g = t.path.split('.')[0]; (groups.get(g) ?? groups.set(g, []).get(g)).push(t); }
let md = `# Retrospect tokens\n\nGenerated from \`tokens.json\` by \`validate.mjs\`. Do not edit by hand.\n\n**${tokens.length} tokens** · ${tokens.filter((t) => !t.path.startsWith('palette.')).length} semantic · ${tokens.filter((t) => t.node.$extensions?.retrospect?.source?.startsWith('to set')).length} marked *to set*\n`;
for (const [g, list] of groups) {
  md += `\n## ${g}\n\n| Token | Purpose | Light | Dark | Source |\n|---|---|---|---|---|\n`;
  for (const { path, node } of list) md += `| \`${path}\` | ${show(node.$description ?? '')} | ${show(node.$value)} | ${show(node.$extensions?.retrospect?.dark ?? '')} | ${node.$extensions?.retrospect?.source ?? ''} |\n`;
}
writeFileSync(join(here, 'TOKENS.md'), md);
console.log(`${tokens.length} tokens, ${errors.length} problem(s)`);
for (const e of errors) console.log('  ✗', e);
process.exit(errors.length ? 1 : 0);
