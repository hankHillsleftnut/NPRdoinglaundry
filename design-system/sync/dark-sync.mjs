// node design-system/sync/dark-sync.mjs [--dry] [--only <lightBoardId>] [--force]
// M12 · dark mode that follows light (founder, 20 Oct: "put dark mode on a different page, and have it
// follow along with everything that is happening with light mode").
//
// Reads every light hi-fi board on the source pages (dark-sync.config.json), and keeps one dark twin of
// each on the dark page, in the same layout. A twin is the light board duplicated with every
// var(--color-X) swapped for var(--color-dark-X) (process.md: "the dark version swaps each token for its
// --color-dark-… pair; no new values"). Subtrees named in `keepLight` (system chrome such as the lock
// screen, which looks the same in both modes) are left alone.
//
// It only redoes what changed: each light board's export is hashed (ids stripped); a board whose hash
// matches the last run is left as it is. A changed board's old twin is removed once its replacement is
// built: twins are machine-made and rebuildable from light, and the working file has a size limit (21 Oct:
// keeping superseded twins on an archive page filled the file; history lives in the separate archive file).
// If Paper refuses the delete, the old twin is hidden and listed so a person can remove it.
// Run it after any change to a light screen. State lives in snapshots/dark-sync.json.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { connect } from './paper-client.mjs';
import { keptIds } from './dark-lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const CONFIG = JSON.parse(readFileSync(join(here, 'dark-sync.config.json'), 'utf8'));
const STATE_FILE = join(here, 'snapshots/dark-sync.json');
const state = existsSync(STATE_FILE) ? JSON.parse(readFileSync(STATE_FILE, 'utf8')) : { boards: {} };
const args = process.argv.slice(2);
const DRY = args.includes('--dry'), FORCE = args.includes('--force');
const ONLY = args.includes('--only') ? args[args.indexOf('--only') + 1] : null;
const F = CONFIG.fileId, DF = CONFIG.darkFileId ?? CONFIG.fileId;
const CROSS = DF !== F; // 21 Oct: dark moved to its own file ("Retrospect · dark") to keep the working file under Paper's size limit

const p = await connect();
const call = (name, a) => p.call(name, { fileId: F, ...a });   // light (source)
const dcall = (name, a) => p.call(name, { fileId: DF, ...a }); // dark (target)
const log = (...a) => console.log(...a);

// ---- the swap -------------------------------------------------------------------------------------
const tokens = await dcall('get_tokens', { types: ['color'], namePattern: '--color-*' });
const NAMES = new Set((tokens.items ?? tokens.tokens ?? tokens).map((t) => t.name));
const VAR = /var\(--color-([a-z0-9-]+)\)/g;
const COLOR_PROPS = new Set(['color', 'backgroundColor', 'backgroundImage', 'boxShadow', 'borderColor', 'outline',
  'outlineColor', 'borderTopColor', 'borderBottomColor', 'textShadow', 'fill', 'stroke']);
// Apple's status bar glyphs are raw black in the guide's markup: they become the dark text colour, as iOS does
const SYSTEM = { '#000000': 'var(--color-dark-text-primary)', '#00000059': 'var(--color-dark-text-tertiary)' };
// raw colours drawn on light boards that equal a token's light value: the twin treats them as that token
// (config rawAsToken), so they still go dark; each is a light-side token-check finding to tokenise at source
for (const [raw, tok] of Object.entries(CONFIG.rawAsToken ?? {})) SYSTEM[raw] = SYSTEM[raw.toUpperCase()] = `var(--color-dark-${tok})`;
function swap(v, unpaired) {
  if (SYSTEM[v]) return SYSTEM[v];
  return v.replace(VAR, (m, n) => {
    if (n.startsWith('dark-')) return m;
    if (NAMES.has(`--color-dark-${n}`)) return `var(--color-dark-${n})`;
    unpaired[n] = (unpaired[n] ?? 0) + 1;
    return m;
  });
}

// Paper numbers an svg's descendants right after the svg id, visiting the last child first, depth-first
// (svg ABC → its last path ABD; a group ABD → its path ABE). Checked against the duplicate's id map.
const A36 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const plus = (id, n) => {
  let v = 0; for (const c of id.slice(0, -2)) v = v * 36 + A36.indexOf(c);
  v += n; let o = ''; while (v) { o = A36[v % 36] + o; v = Math.floor(v / 36); }
  return `${o}-0`;
};

function plan(jsx, validIds, kept) {
  const groups = new Map(), unpaired = {}, badIds = [], svgOf = {};
  const add = (prop, val, id) => { const k = `${prop}\u0000${val}`; (groups.get(k) ?? groups.set(k, []).get(k)).push(id); };
  for (const m of jsx.matchAll(/<(\w+)\b([^>]*?)\bid="([^"]+)"([^>]*)>/g)) {
    const id = m[3]; if (kept.has(id)) continue;
    const sm = (m[2] + m[4]).match(/style=\{\{(.*?)\}\}/s);
    if (!sm) continue;
    for (const [, k, v] of sm[1].matchAll(/(\w+):\s*'((?:[^'\\]|\\.)*)'/g)) {
      if (!COLOR_PROPS.has(k)) continue;
      const nv = swap(v, unpaired); if (nv !== v) add(k, nv, id);
    }
  }
  for (const m of jsx.matchAll(/<svg\b[^>]*\bid="([^"]+)"[^>]*>(.*?)<\/svg>/gs)) {
    const sid = m[1]; if (kept.has(sid)) continue;
    const root = { kids: [] }, stack = [root];
    for (const t of m[2].matchAll(/<(\/?)(\w+)\b((?:[^>"]|"[^"]*")*?)(\/?)>/g)) {
      if (t[1]) { if (stack.length > 1) stack.pop(); continue; }
      const node = { attrs: t[3], kids: [] }; stack.at(-1).kids.push(node); if (!t[4]) stack.push(node);
    }
    let n = 0; const all = [];
    (function visit(node) { for (const k of [...node.kids].reverse()) { k.id = plus(sid, ++n); all.push(k); visit(k); } })(root);
    for (const k of all) for (const attr of ['fill', 'stroke']) {
      const a = k.attrs.match(new RegExp(`\\b${attr}="([^"]+)"`)); if (!a) continue;
      const nv = swap(a[1], unpaired); if (nv === a[1]) continue;
      if (validIds && !validIds.has(k.id)) { badIds.push(k.id); svgOf[k.id] = sid; continue; }
      add(attr, nv, k.id);
    }
  }
  const updates = [...groups].map(([k, ids]) => { const [prop, val] = k.split('\u0000'); return { nodeIds: ids, styles: { [prop]: val } }; });
  return { updates, unpaired, badIds, svgOf };
}

// ---- sources --------------------------------------------------------------------------------------
const exclude = new RegExp(CONFIG.excludeBoards, 'i');
// keep-light rules match Frames only (a note that mentions "lock screen" is still a note), optionally only
// inside an ancestor frame whose name matches `within`
const keepRules = CONFIG.keepLight.map((k) => ({ name: new RegExp(k.name, 'i'), within: k.within ? new RegExp(k.within, 'i') : null }));
// the layer outline of a board: [{ kind, name, id, ancestors }]. Paper truncates the summary of a big board,
// so a truncated outline is rebuilt from each child's own summary.
async function outline(nodeId, ancestors = []) {
  const t = await call('get_tree_summary', { nodeId, depth: 10 });
  const rows = [], stack = [...ancestors];
  for (const m of String(t.summary ?? t).matchAll(/^(\s*)(\w+) "([^"]*)" \(([^)]+)\)/gm)) {
    const depth = ancestors.length + m[1].length / 2;
    stack.length = depth;
    rows.push({ kind: m[2], name: m[3], id: m[4], ancestors: stack.slice(0, depth) });
    stack[depth] = m[3];
  }
  if (!t.truncated) return rows;
  const kids = (await call('get_children', { nodeId })).children ?? [];
  const out = rows.slice(0, 1);
  for (const k of kids) out.push(...(await outline(k.id, [...ancestors, rows[0]?.name ?? ''])));
  return out;
}
const keepRootsFrom = (rows) => rows.filter((r) => r.kind === 'Frame' && keepRules.some((k) => k.name.test(r.name) && (!k.within || r.ancestors.some((a) => k.within.test(a))))).map((r) => r.id);
const sources = [];
for (const src of CONFIG.sources) {
  const info = await call('get_basic_info', { pageId: src.pageId });
  for (const a of info.artboards) {
    if (exclude.test(a.name)) continue;
    if (src.include && !new RegExp(src.include).test(a.name)) continue; // pages where only some boards follow
    const node = await call('get_node_info', { nodeId: a.id });
    if (!node.isVisible) continue;
    sources.push({ ...a, page: src, darkLeft: a.worldX + (src.dx ?? 0), darkTop: a.worldY + src.dy });
  }
}
log(`${sources.length} light boards on ${CONFIG.sources.length} pages`);

const darkRoot = `root_node_${CONFIG.darkPageId}`;
const leftovers = [];
async function retire(id, name) {
  try { await dcall('delete_nodes', { nodeIds: [id] }); return 'removed'; }
  catch {
    await dcall('update_styles', { updates: [{ nodeIds: [id], styles: { display: 'none' } }] });
    await dcall('rename_nodes', { updates: [{ nodeId: id, name: `superseded · remove · ${name}`.slice(0, 50) }] });
    leftovers.push(`${id} ${name}`); return 'hidden (delete refused)';
  }
}

// ---- cross-file build ---------------------------------------------------------------------------------
// Paper can't duplicate between files, so the twin is rebuilt from the light board's export: every colour
// token in it is swapped for its dark pair (outside keep-light chrome), layer names are carried over from the
// light tree, and the result is written into the dark file one top-level group at a time.
async function namesOf(rootId) {
  const names = new Map(), kinds = new Map(), parents = new Map();
  const info = await call('get_node_info', { nodeId: rootId }); names.set(rootId, info.name); kinds.set(rootId, info.component);
  const walk = async (id) => {
    for (const c of (await call('get_children', { nodeId: id })).children ?? []) {
      names.set(c.id, c.name); kinds.set(c.id, c.component); parents.set(c.id, id);
      if (c.childCount && c.component !== 'SVG') await walk(c.id);
    }
  };
  await walk(rootId);
  return { names, kinds, parents };
}
const kebab = (k) => k.replace(/^(Moz|Webkit)/, (m) => '-' + m.toLowerCase()).replace(/[A-Z]/g, (c) => '-' + c.toLowerCase());
const esc = (t) => t.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
function toHtml(jsx, names) {
  let src = jsx.trim().replace(/^\(\s*/, '').replace(/\s*\)\s*$/, '');
  src = src.replace(/style=\{\{([^}]*)\}\}/g, (_, body) => {
    const decls = [...body.matchAll(/(\w+):\s*(?:'((?:[^'\\]|\\.)*)'|(\d+(?:\.\d+)?))/g)].map(([, k, v, n]) => `${kebab(k)}:${(v ?? n).replace(/"/g, "'")}`);
    return `style="${decls.join(';')}"`;
  });
  src = src.replace(/\b(strokeWidth|strokeLinecap|strokeLinejoin|fillRule|clipRule|stopColor|stopOpacity|strokeDasharray|fillOpacity|strokeOpacity|strokeMiterlimit|clipPath|gradientUnits|gradientTransform)=/g, (_, a) => kebab(a) + '=');
  src = src.replace(/\sid="([^"]*)"/g, (_, id) => (names.has(id) ? ` layer-name="${esc(names.get(id))}"` : ''));
  src = src.replace(/\{' '\}/g, ' ').replace(/\{"((?:[^"\\]|\\.)*)"\}/g, '$1').replace(/\{'((?:[^'\\]|\\.)*)'\}/g, '$1');
  // HTML has no self-closing divs: <div …/> would swallow its siblings
  src = src.replace(/<(div|span|p)\b([^>]*?)\s*\/>/g, '<$1$2></$1>');
  return src;
}
// split an element's markup into [openTag, [child markup…]] by tag depth
function children(markup) {
  const open = markup.match(/^<(\w+)\b(?:[^>"']|"[^"]*"|'[^']*')*>/)[0];
  const tag = open.match(/^<(\w+)/)[1];
  const inner = markup.slice(open.length, markup.lastIndexOf(`</${tag}>`));
  const out = []; const re = /<(\/?)(\w+)\b((?:[^>"']|"[^"]*"|'[^']*')*?)(\/?)>/g; let depth = 0, start = -1, m;
  while ((m = re.exec(inner))) {
    if (m[1]) { depth--; if (depth === 0) { out.push(inner.slice(start, re.lastIndex)); start = -1; } }
    else if (!m[4]) { if (depth === 0) start = m.index; depth++; }
    else if (depth === 0) out.push(m[0]);
  }
  return [open, out];
}
async function buildInOtherFile(s, jsxLight) {
  const { names, kinds } = await namesOf(s.id);
  // keep-light roots by full layer name and ancestry
  const rows = [...names].map(([id, name]) => ({ id, name, kind: kinds.get(id) === 'Frame' ? 'Frame' : kinds.get(id), ancestors: [] }));
  const anc = (await namesOf(s.id)).parents; // ancestry for `within`
  for (const r of rows) { let a = anc.get(r.id); while (a) { r.ancestors.unshift(names.get(a)); a = anc.get(a); } }
  const keepRoots = keepRootsFrom(rows);
  const kept = keptIds(jsxLight, keepRoots);
  const unpaired = {}; let swaps = 0;
  // swap styles element by element (ids are still the light ids here)
  let jsx = jsxLight.replace(/<(\w+)\b([^>]*?)\bid="([^"]+)"([^>]*)>/g, (whole, tag, a1, id, a2) => {
    if (kept.has(id)) return whole;
    let out = whole.replace(/style=\{\{(.*?)\}\}/s, (st, body) => 'style={{' + body.replace(/(\w+):\s*'((?:[^'\\]|\\.)*)'/g, (d, k, v) => {
      if (!COLOR_PROPS.has(k)) return d; const nv = swap(v, unpaired); if (nv !== v) swaps++; return `${k}: '${nv}'`;
    }) + '}}');
    if (names.get(id) === 'needs you · red dot') out = out.replace(/style=\{\{/, "style={{ display: 'none', ");
    return out;
  });
  // svg child fills and strokes
  jsx = jsx.replace(/(<svg\b[^>]*\bid="([^"]+)"[^>]*>)(.*?)(<\/svg>)/gs, (whole, open, sid, body, close) => kept.has(sid) ? whole
    : open + body.replace(/\b(fill|stroke)="([^"]+)"/g, (d, attr, v) => { const nv = swap(v, unpaired); if (nv !== v) swaps++; return `${attr}="${nv}"`; }) + close);
  // a raw board background becomes the dark canvas
  jsx = jsx.replace(/^(\s*\(?\s*<div id="[^"]+" style=\{\{[^}]*backgroundColor: ')(#[0-9A-Fa-f]{3,8})'/, '$1var(--color-dark-background-canvas)\'');
  const html = toHtml(jsx, names);
  const [open, kids] = children(html);
  const rootStyle = Object.fromEntries((open.match(/style="([^"]*)"/)?.[1] ?? '').split(';').filter(Boolean).map((d) => { const i = d.indexOf(':'); return [d.slice(0, i).replace(/-([a-z])/g, (_, c) => c.toUpperCase()), d.slice(i + 1)]; }));
  const darkName = `dark · ${s.name.replace(/ · (approve\?|approved)$/, '')} · approve?`;
  const art = await dcall('create_artboard', { pageId: CONFIG.darkPageId, name: darkName, styles: { width: rootStyle.width?.endsWith('px') ? rootStyle.width : '1600px', height: '400px' } });
  const darkId = art.id;
  await dcall('update_styles', { updates: [{ nodeIds: [darkId], styles: { ...rootStyle, left: `${s.darkLeft}px`, top: `${s.darkTop}px` } }] });
  for (const k of kids) await dcall('write_html', { targetNodeId: darkId, mode: 'insert-children', html: k });
  const w = await dcall('write_html', { targetNodeId: darkId, mode: 'insert-children',
    html: '<div layer-name="dark · needs you · red dot" style="width:var(--spacing-3);height:var(--spacing-3);border-radius:var(--radius-control);background-color:var(--color-dark-status-danger)"></div>' });
  const dotId = w.createdNodes?.[0]?.id;
  if (dotId) await dcall('update_styles', { updates: [{ nodeIds: [dotId], styles: { position: 'absolute', top: '24px', right: '24px' } }] });
  // write_html drops `position` on pasted roots of absolutely placed layers: put each back from the light export
  const abs = [...jsxLight.matchAll(/<\w+\b[^>]*\bid="([^"]+)"[^>]*style=\{\{[^}]*position: 'absolute'/g)].map((m) => names.get(m[1])).filter(Boolean);
  if (abs.length) {
    const out = await dcall('get_jsx', { nodeId: darkId });
    // positions survive inside a pasted group; only a pasted group's own root can lose it, and the outline
    // check in dark-audit reports any absolute layer that came back static
    void out;
  }
  await dcall('finish_working_on_nodes', { nodeIds: [darkId] });
  // keep-light roots in the dark file, for the audit
  const { names: dn, kinds: dk, parents: dp } = await (async () => { const r = await namesOfIn(dcall, darkId); return r; })();
  const drows = [...dn].map(([id, name]) => { const r = { id, name, kind: dk.get(id) === 'Frame' ? 'Frame' : dk.get(id), ancestors: [] }; let a = dp.get(id); while (a) { r.ancestors.unshift(dn.get(a)); a = dp.get(a); } return r; });
  return { darkId, darkName, swaps, unpaired, keptRoots: keepRootsFrom(drows) };
}
async function namesOfIn(fn, rootId) {
  const names = new Map(), kinds = new Map(), parents = new Map();
  const info = await fn('get_node_info', { nodeId: rootId }); names.set(rootId, info.name); kinds.set(rootId, info.component);
  const walk = async (id) => { for (const c of (await fn('get_children', { nodeId: id })).children ?? []) { names.set(c.id, c.name); kinds.set(c.id, c.component); parents.set(c.id, id); if (c.childCount && c.component !== 'SVG') await walk(c.id); } };
  await walk(rootId);
  return { names, kinds, parents };
}

const today = new Date().toLocaleDateString('en-CA');
const report = [];
for (const s of sources) {
  if (ONLY && s.id !== ONLY) continue;
  const jsxLight = await call('get_jsx', { nodeId: s.id });
  const hash = createHash('sha1').update(String(jsxLight).replace(/\sid="[^"]*"/g, '')).digest('hex').slice(0, 12);
  const prev = state.boards[s.id];
  let darkAlive = false;
  if (prev) { try { await dcall('get_node_info', { nodeId: prev.darkId }); darkAlive = true; } catch { darkAlive = false; } }
  if (prev && darkAlive && prev.hash === hash && !FORCE) {
    if (!DRY) await dcall('update_styles', { updates: [{ nodeIds: [prev.darkId], styles: { left: `${s.darkLeft}px`, top: `${s.darkTop}px` } }] });
    report.push(`  = ${s.name} (unchanged)`); continue;
  }
  if (DRY) { report.push(`  ~ ${s.name} (${prev ? 'changed' : 'new'})`); continue; }

  if (CROSS) {
    const built = await buildInOtherFile(s, String(jsxLight));
    if (prev && darkAlive) report.push(`  · old twin of ${s.name}: ${await retire(prev.darkId, prev.name)}`);
    state.boards[s.id] = { darkId: built.darkId, hash, name: built.darkName, page: s.page.name, synced: today, keptRoots: built.keptRoots };
    writeFileSync(STATE_FILE, JSON.stringify(state, null, 1));
    const up = Object.entries(built.unpaired).sort((a, b) => b[1] - a[1]).map(([n, c]) => `${n}×${c}`).join(' ');
    report.push(`  + ${s.name} → ${built.darkId}: ${built.swaps} swaps, ${built.keptRoots.length} kept-light${up ? `; palette kept: ${up}` : ''}`);
    log(report.at(-1)); continue;
  }
  const dup = await call('duplicate_nodes', { nodes: [{ id: s.id, parentId: darkRoot }] });
  const d = dup.duplicatedNodes[0];
  const darkId = d.newId, idMap = d.descendantIdMap;
  await call('update_styles', { updates: [{ nodeIds: [darkId], styles: { left: `${s.darkLeft}px`, top: `${s.darkTop}px` } }] });
  const darkName = `dark · ${s.name.replace(/ · (approve\?|approved)$/, '')} · approve?`;
  await call('rename_nodes', { updates: [{ nodeId: darkId, name: darkName }] });

  // keep-light subtrees, found by layer name in the light board's tree (ids map across the duplicate)
  const rows = await outline(s.id);
  const keepRoots = keepRootsFrom(rows).map((id) => idMap[id]).filter(Boolean);

  const jsxDark = await call('get_jsx', { nodeId: darkId });
  const valid = new Set(Object.values(idMap));
  const first = plan(String(jsxDark), valid, keptIds(String(jsxDark), keepRoots));
  // an svg whose computed child ids aren't in the duplicate's map: ask Paper for its real children
  for (const id of first.badIds) { const sid = first.svgOf[id]; if (sid && !valid.has(`checked:${sid}`)) {
    valid.add(`checked:${sid}`);
    const walk = async (n) => { for (const c of (await call('get_children', { nodeId: n })).children ?? []) { valid.add(c.id); if (c.childCount) await walk(c.id); } };
    await walk(sid);
  } }
  const { updates, unpaired, badIds } = first.badIds.length ? plan(String(jsxDark), valid, keptIds(String(jsxDark), keepRoots)) : first;
  const rootBg = String(jsxDark).match(/^\s*\(?\s*<div id="[^"]+" style=\{\{[^}]*backgroundColor: '(#[0-9A-Fa-f]{3,8})'/);
  if (rootBg) updates.push({ nodeIds: [darkId], styles: { backgroundColor: 'var(--color-dark-background-canvas)' } });
  for (let i = 0; i < updates.length; i += 40) await call('update_styles', { updates: updates.slice(i, i + 40) });

  // every dark board waits on the founder: one red dot, top right. The light board's own dot (shown while
  // the light screen is pending, hidden once approved) is hidden on the twin so there is never two.
  const lightDots = rows.filter((r) => r.name === 'needs you · red dot').map((r) => idMap[r.id]).filter(Boolean);
  if (lightDots.length) await call('update_styles', { updates: [{ nodeIds: lightDots, styles: { display: 'none' } }] });
  const w = await call('write_html', { targetNodeId: darkId, mode: 'insert-children',
    html: '<div layer-name="dark · needs you · red dot" style="width:var(--spacing-3);height:var(--spacing-3);border-radius:var(--radius-control);background-color:var(--color-dark-status-danger)"></div>' });
  const dotId = w.createdNodes?.[0]?.id;
  if (dotId) await call('update_styles', { updates: [{ nodeIds: [dotId], styles: { position: 'absolute', top: '24px', right: '24px' } }] });
  await call('finish_working_on_nodes', { nodeIds: [darkId] });

  // the replacement is built; now remove the old twin (never before, so a failed run loses nothing)
  if (prev && darkAlive) report.push(`  · old twin of ${s.name}: ${await retire(prev.darkId, prev.name)}`);
  state.boards[s.id] = { darkId, hash, name: darkName, page: s.page.name, synced: today, keptRoots: keepRoots };
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 1));
  const up = Object.entries(unpaired).sort((a, b) => b[1] - a[1]).map(([n, c]) => `${n}×${c}`).join(' ');
  report.push(`  + ${s.name} → ${darkId}: ${updates.reduce((a, u) => a + u.nodeIds.length, 0)} swaps, ${keepRoots.length} kept-light, ${badIds.length} unmatched svg ids${up ? `; palette kept: ${up}` : ''}`);
  log(report.at(-1));
}

// twins whose light board is gone (approved and moved off a source page counts as still present)
if (!ONLY && !DRY) for (const [lid, b] of Object.entries(state.boards)) {
  if (sources.some((s) => s.id === lid)) continue;
  let how = 'already gone';
  try { await dcall('get_node_info', { nodeId: b.darkId }); how = await retire(b.darkId, b.name); } catch { /* already gone */ }
  report.push(`  - ${b.name} (light board gone → twin ${how})`); delete state.boards[lid];
}
writeFileSync(STATE_FILE, JSON.stringify(state, null, 1));
log(report.join('\n'));
if (leftovers.length) log(`\n${leftovers.length} superseded twin(s) hidden because Paper refused the delete; remove by hand:\n  ${leftovers.join('\n  ')}`);
p.close();
