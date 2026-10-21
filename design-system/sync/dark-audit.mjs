// node design-system/sync/dark-audit.mjs [lightBoardId…]
// The contrast and token audit for the dark page (M12). For every dark twin in snapshots/dark-sync.json:
//  1. leftovers: any var(--color-X) that has a dark pair but wasn't swapped (outside keep-light chrome)
//  2. raw colours: any colour that isn't a token (the status bar's black glyphs excepted, as in token-check)
//  3. contrast: every text node's colour against what it actually sits on — its nearest ancestor fill,
//     with translucent fills (washes, scrims) composited down to the first solid one, and element and
//     ancestor opacity applied to the text. WCAG 2.2 AA: 4.5 body, 3 for large text (24+, or 19+ at 600+).
//     Text over a gradient or artwork is listed for a visual check (no single background to measure).
// Writes snapshots/dark-audit.json and prints the failures.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { connect } from './paper-client.mjs';
import { keptIds } from './dark-lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const CONFIG = JSON.parse(readFileSync(join(here, 'dark-sync.config.json'), 'utf8'));
const state = JSON.parse(readFileSync(join(here, 'snapshots/dark-sync.json'), 'utf8'));
const only = process.argv.slice(2);
const p = await connect();
const call = (name, a) => p.call(name, { fileId: CONFIG.fileId, ...a });

// ---- tokens → rgba ----------------------------------------------------------------------------------
const toks = await call('get_tokens', {});
const T = new Map((toks.items ?? toks.tokens ?? toks).map((t) => [t.name, String(t.value)]));
function resolve(v, depth = 0) {
  if (depth > 12) return v;
  return v.replace(/var\((--[a-z0-9-]+)\)/g, (m, n) => (T.has(n) ? resolve(T.get(n), depth + 1) : m));
}
function rgba(c) {
  c = c.trim();
  let m;
  if ((m = c.match(/^#([0-9a-f]{3,8})$/i))) {
    let h = m[1]; if (h.length <= 4) h = [...h].map((x) => x + x).join('');
    const n = [0, 2, 4, 6].map((i) => (i < h.length ? parseInt(h.slice(i, i + 2), 16) : 255));
    return [n[0], n[1], n[2], n[3] / 255];
  }
  if ((m = c.match(/^rgba?\(([^)]*)\)$/))) {
    const parts = m[1].replace(/\//, ' ').replace(/,/g, ' ').split(/\s+/).filter(Boolean);
    const a = parts[3] === undefined ? 1 : parts[3].endsWith('%') ? parseFloat(parts[3]) / 100 : parseFloat(parts[3]);
    return [+parts[0], +parts[1], +parts[2], a];
  }
  if ((m = c.match(/^color-mix\((.*) (\d+(?:\.\d+)?)%, transparent\)$/))) {
    const base = rgba(m[1]); if (!base) return null; return [base[0], base[1], base[2], base[3] * (+m[2] / 100)];
  }
  if (c === 'transparent') return [0, 0, 0, 0];
  if (c === 'white') return [255, 255, 255, 1];
  if (c === 'black') return [0, 0, 0, 1];
  return null;
}
const colour = (v) => rgba(resolve(v));
const over = (f, b) => [0, 1, 2].map((i) => f[i] * f[3] + b[i] * (1 - f[3])).concat(1);
const lum = (c) => { const s = c.slice(0, 3).map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }); return 0.2126 * s[0] + 0.7152 * s[1] + 0.0722 * s[2]; };
const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
const px = (v) => { if (!v) return null; const r = resolve(v); const m = r.match(/([\d.]+)px/); return m ? +m[1] : null; };

// ---- jsx → tree ---------------------------------------------------------------------------------------
function tree(jsx) {
  const root = { kids: [], style: {}, text: '' }; const stack = [root];
  const re = /<(\/?)([a-zA-Z]+)\b((?:[^>"']|"[^"]*"|'(?:[^'\\]|\\.)*')*?)(\/?)>|([^<]+)/g;
  let m;
  while ((m = re.exec(jsx))) {
    if (m[5] !== undefined) { const t = m[5].trim(); if (t && stack.at(-1).tag !== 'svg') stack.at(-1).text += t + ' '; continue; }
    const [, close, tag, attrs, self] = m;
    if (close) { while (stack.length > 1 && stack.pop().tag !== tag); continue; }
    const style = {};
    const sm = attrs.match(/style=\{\{(.*?)\}\}/s);
    if (sm) for (const [, k, v] of sm[1].matchAll(/(\w+):\s*'((?:[^'\\]|\\.)*)'/g)) style[k] = v;
    for (const [, k, v] of (sm?.[1] ?? '').matchAll(/(\w+):\s*(\d+(?:\.\d+)?)\b/g)) if (!(k in style)) style[k] = v;
    const node = { tag, id: attrs.match(/\bid="([^"]+)"/)?.[1], style, kids: [], text: '', parent: stack.at(-1) };
    stack.at(-1).kids.push(node);
    if (!self) stack.push(node);
  }
  return root;
}

const report = {};
let fails = 0, checked = 0, visual = 0, inverted = 0;
for (const [lid, b] of Object.entries(state.boards)) {
  if (only.length && !only.includes(lid)) continue;
  const jsx = String(await call('get_jsx', { nodeId: b.darkId }));
  const r = report[b.name] = { leftovers: [], raw: [], fail: [], onArt: [], inverted: [] };
  // keep-light subtrees are system chrome: excluded from leftovers, still measured for contrast
  const kept = keptIds(jsx, b.keptRoots ?? []);
  for (const el of jsx.matchAll(/<\w+\b[^>]*?\bid="([^"]+)"[^>]*>/g)) {
    if (kept.has(el[1])) continue;
    for (const m of el[0].matchAll(/var\(--color-((?!dark-)[a-z0-9-]+)\)/g)) if (T.has(`--color-dark-${m[1]}`)) r.leftovers.push(`${m[1]} (${el[1]})`);
  }
  const root = tree(jsx);
  // 4. depth: anything that rises (raised, lifted, controls, secondary actions) must be lighter than what it
  //    sits on in dark (surfaces.md: surfaces get lighter as they rise); a darker one reads as a hole
  const RISES = /--color-dark-(background-raised|surface-lifted|surface-control|surface-secondary-action)\)/;
  (function depth(n) {
    for (const k of n.kids) depth(k);
    if (!n.style.backgroundColor || !RISES.test(n.style.backgroundColor) || n.style.display === 'none') return;
    const layers = [];
    for (let a = n.parent; a && a.style; a = a.parent) {
      if (a.style.backgroundImage && a.style.backgroundImage !== 'none') return;
      if (a.style.backgroundColor) { const c = colour(a.style.backgroundColor); if (c) { layers.push(c); if (c[3] >= 0.999) break; } }
    }
    if (!layers.length || layers.at(-1)[3] < 0.999) return;
    let bg = layers.at(-1); for (let i = layers.length - 2; i >= 0; i--) bg = over(layers[i], bg);
    const me = colour(n.style.backgroundColor); if (!me) return;
    if (lum(over(me, bg)) + 0.002 < lum(bg)) { inverted++; r.inverted.push(`${n.id} ${n.style.backgroundColor.match(/dark-([a-z-]+)/)[1]}`); }
  })(root);
  (function walk(n) {
    for (const k of n.kids) walk(k);
    if (!n.text.trim() || n.tag === 'svg' || n.style.display === 'none') return;
    let hidden = false, op = 1, bg = null, art = false;
    for (let a = n; a; a = a.parent) {
      if (a.style.display === 'none') hidden = true;
      if (a.style.opacity) { const o = resolve(a.style.opacity); op *= o.endsWith('%') ? parseFloat(o) / 100 : parseFloat(o) > 1 ? parseFloat(o) / 100 : (parseFloat(o) || 1); }
    }
    if (hidden) return;
    const layers = [];
    for (let a = n; a && a.style; a = a.parent) {
      if (a.style.backgroundImage && a.style.backgroundImage !== 'none') { art = true; break; }
      if (a.style.backgroundColor) { const c = colour(a.style.backgroundColor); if (c) { layers.push(c); if (c[3] >= 0.999) break; } }
    }
    const fgv = (() => { for (let a = n; a && a.style; a = a.parent) if (a.style.color) return a.style.color; return null; })();
    if (!fgv) return;
    const fg = colour(fgv);
    if (fg && fg[3] === 0) return; // transparent text: the sharp/blurred copies of a progressive blur, never read
    if (art || !layers.length || layers.at(-1)[3] < 0.999 || !fg) { r.onArt.push(`${n.id} "${n.text.trim().slice(0, 40)}"`); visual++; return; }
    bg = layers.at(-1); for (let i = layers.length - 2; i >= 0; i--) bg = over(layers[i], bg);
    const f = over([fg[0], fg[1], fg[2], fg[3] * op], bg);
    const size = px(n.style.fontSize) ?? 16;
    const weight = parseFloat(resolve(n.style.fontWeight ?? '400')) || 400;
    const large = size >= 24 || (size >= 19 && weight >= 600);
    const need = large ? 3 : 4.5;
    const cr = ratio(f, bg); checked++;
    if (cr < need) { fails++; r.fail.push({ id: n.id, text: n.text.trim().slice(0, 48), ratio: +cr.toFixed(2), need, color: fgv, size, opacity: +op.toFixed(2) }); }
  })(root);
  for (const m of jsx.matchAll(/(?:color|backgroundColor|fill|stroke|boxShadow|backgroundImage): '([^']*)'/g)) {
    const bare = m[1].replace(/var\(--[a-z0-9-]+\)/g, '');
    for (const c of bare.matchAll(/#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)/g)) if (!/^#0000(00)?(00|59)?$/i.test(c[0])) r.raw.push(c[0]);
  }
  for (const m of jsx.matchAll(/\s(fill|stroke)="(#[0-9a-fA-F]{3,8}|rgba?\([^"]*\))"/g)) if (!/^#000000$/i.test(m[2])) r.raw.push(m[2]);
  console.log(`${b.name}: ${r.fail.length} contrast fails, ${r.leftovers.length} unswapped, ${r.raw.length} raw, ${r.onArt.length} on art, ${r.inverted.length} depth inversions`);
  if (r.inverted.length) console.log(`   ⇣ ${r.inverted.slice(0, 8).join(' · ')}`);
  for (const f of r.fail) console.log(`   ✗ ${f.ratio} < ${f.need} "${f.text}" ${f.color} ${f.size}px op ${f.opacity} (${f.id})`);
}
writeFileSync(join(here, 'snapshots/dark-audit.json'), JSON.stringify(report, null, 1));
console.log(`\n${checked} text nodes measured, ${fails} below AA, ${visual} on gradients/art (checked by eye), ${inverted} depth inversions`);
p.close();
