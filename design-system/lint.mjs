// node design-system/lint.mjs  ->  checks every element of the design system, not only the tokens.
// tokens:     validate.mjs rules (references, purpose, dark value, purpose-names, source)
// components: every spec has the Lime sections; every token it names exists; every state in
//             craft.md §11 is covered or excused; it has a row in audit.md and a line in README.md
// icons:      24 grid, stroke 1.75, round caps and joins, listed in icons.json with a note
// contrast:   every component colour pair, light and dark, meets WCAG AA
// docs:       every relative link resolves
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const root = dirname(fileURLToPath(import.meta.url));
const read = (p) => readFileSync(join(root, p), 'utf8');
const problems = [];
const say = (where, what) => problems.push(`${where}: ${what}`);

// tokens
try { execFileSync('node', [join(root, 'tokens/validate.mjs')], { stdio: 'pipe' }); }
catch (e) { say('tokens', e.stdout.toString().trim()); }

const pairs = execFileSync('node', [join(root, 'tokens/contrast-pairs.cjs'), join(root, 'tokens/tokens.json')]).toString();
for (const l of pairs.split('\n').filter((x) => x.startsWith('FAIL'))) say('contrast', l.slice(5));
const T = JSON.parse(read('tokens/tokens.json'));
const paths = [];
(function walk(n, p) {
  if (n && typeof n === 'object' && '$value' in n) { paths.push(p.join('.')); return; }
  for (const [k, v] of Object.entries(n ?? {})) if (!k.startsWith('$') && typeof v === 'object') walk(v, [...p, k]);
})(T, []);
const groups = new Set(paths.map((p) => p.split('.')[0]));
// specs write semantic colours without the `color.` prefix (text.primary) and may abbreviate a/b
const exists = (ref) => {
  const tries = [ref, `color.${ref}`];
  return tries.some((t) => t.endsWith('.*')
    ? paths.some((p) => p.startsWith(t.slice(0, -1)))
    : paths.some((p) => p === t || p.startsWith(`${t}.`)));
};
const expand = (ref) => {
  const parts = ref.split('/');
  if (parts.length === 1) return [ref];
  const head = parts[0].split('.');
  const base = head.slice(0, -1).join('.');
  return [parts[0], ...parts.slice(1).map((s) => (s.includes('.') ? s : `${base}.${s}`))];
};
const looksLikeToken = (s) => /^[a-z][a-zA-Z0-9]*(\.[a-zA-Z0-9*-]+)+(\/[a-zA-Z0-9.*-]+)*$/.test(s)
  && (groups.has(s.split('.')[0]) || paths.some((p) => p.startsWith(`color.${s.split('.')[0]}.`)));

// components
const SECTIONS = ['## Use when', "## Don't use when", '## Anatomy', '## Rules', '## States', '## Accessibility', '## Taken out', '## Edge cases', '## Tokens'];
const STATES = ['rest', 'pressed', 'focused', 'pending', 'disabled', 'error', 'empty', 'loading', 'offline', 'dark', 'accessibility 3', 'reduce motion', 'reduce transparency', 'increase contrast'];
const NOT_SPECS = new Set(['README.md', 'audit.md', 'craft.md', 'inspiration-notes.md']);
const audit = read('components/audit.md');
const readme = read('components/README.md');
const specs = readdirSync(join(root, 'components')).filter((f) => f.endsWith('.md') && !NOT_SPECS.has(f));
const icons = JSON.parse(read('icons/icons.json'));
for (const f of specs) {
  const md = read(`components/${f}`);
  const name = f.replace('.md', '');
  for (const s of SECTIONS) if (!md.includes(s)) say(f, `missing section "${s.slice(3)}"`);
  const states = (md.split('## States')[1] ?? '').split('\n## ')[0].toLowerCase()
    + (md.split('## Accessibility')[1] ?? '').split('\n## ')[0].toLowerCase();
  for (const s of STATES) if (!states.includes(s)) say(f, `state "${s}" not covered or excused`);
  for (const [, code] of md.matchAll(/`([^`]+)`/g)) {
    if (!looksLikeToken(code)) continue;
    for (const r of expand(code)) if (!exists(r)) say(f, `token \`${r}\` does not exist`);
  }
  for (const [, icon] of md.matchAll(/icon `([a-z0-9-]+)`/g)) if (!icons[icon]) say(f, `icon "${icon}" is not in the set`);
  if (!audit.includes(`[${name}]`)) say(f, 'no row in audit.md');
  if (!readme.includes(`./${f}`)) say(f, 'not listed in components/README.md');
  if (!/^drawn: /m.test(md)) say(f, 'no "drawn:" line saying where it is in Paper');
}

// icons
for (const f of readdirSync(join(root, 'icons')).filter((x) => x.endsWith('.svg'))) {
  const svg = read(`icons/${f}`);
  const n = f.replace('.svg', '');
  if (!svg.includes('viewBox="0 0 24 24"')) say(`icons/${f}`, 'not on the 24 grid');
  if (!icons[n]) say(`icons/${f}`, 'not in icons.json');
  else if (!icons[n][2]) say(`icons/${f}`, 'no note in icons.json');
  if (icons[n]?.[0] === 'stroke') {
    if (!svg.includes('stroke-width="1.75"')) say(`icons/${f}`, 'stroke is not 1.75');
    if (!svg.includes('stroke-linecap="round"') || !svg.includes('stroke-linejoin="round"')) say(`icons/${f}`, 'caps or joins not round');
  }
}
for (const n of Object.keys(icons)) if (!existsSync(join(root, `icons/${n}.svg`))) say('icons.json', `"${n}" has no svg`);

// links
const docs = ['process.md', ...['components', 'principles', 'tokens'].flatMap((d) => readdirSync(join(root, d)).filter((f) => f.endsWith('.md')).map((f) => `${d}/${f}`))];
for (const d of docs) {
  if (!existsSync(join(root, d))) continue;
  for (const [, href] of read(d).matchAll(/\]\(([^)#\s]+)(#[^)]*)?\)/g)) {
    if (/^https?:/.test(href)) continue;
    if (!existsSync(resolve(join(root, dirname(d)), href))) say(d, `link ${href} is broken`);
  }
}

console.log(`${specs.length} components, ${Object.keys(icons).length} icons, ${paths.length} tokens, ${docs.length} docs: ${problems.length} problem(s)`);
for (const p of problems) console.log('  ✗', p);
process.exit(problems.length ? 1 : 0);
