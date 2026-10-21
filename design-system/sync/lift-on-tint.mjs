// node design-system/sync/lift-on-tint.mjs [--apply]
// M12 (20 Oct): a canvas-filled element sitting on a tinted or raised parent (a pill in a wash card, a card in a
// sheet, a row on a control) is "lifted" by purpose. In light the canvas is the lightest neutral, so it reads
// raised; in dark the canvas is the darkest, so it read as a hole. Those elements now use surface.lifted (the
// canvas colour in light, night.750 in dark). Light pixels don't change. Re-run after drawing new light screens.
// Rule 2: a surface.control frame with a raised child directly on it (the page behind a sheet, a segmented
// track behind its thumb) is an underlay by purpose: background.underlay (paper.200 in light, like control;
// night.950 in dark, so the sheet or thumb on it rises instead of sinking).
import { connect } from './paper-client.mjs';
const F = '01M5D5J321P5X86ZT58002B7NT';
const PAGES = ['p-3-0', 'p-C-0', 'p-D-0', 'p-F-0', 'p-G-0']; // components, in review, 04b, 05, approvals
const TINTED = new Set(['surface-wash', 'background-raised', 'surface-control', 'surface-secondary-action', 'surface-wash-pressed']);
const PHONE_WIDTHS = new Set([375, 390, 393, 402, 430, 440]);
const apply = process.argv.includes('--apply');
const p = await connect();
let total = 0;
for (const pageId of PAGES) {
  const info = await p.call('get_basic_info', { fileId: F, pageId });
  for (const a of info.artboards) {
    if (/^(archived?|dark ·)/i.test(a.name)) continue;
    const j = String(await p.call('get_jsx', { fileId: F, nodeId: a.id }));
    const re = /<(\/?)([a-zA-Z]+)\b((?:[^>"']|"[^"]*"|'(?:[^'\\]|\\.)*')*?)(\/?)>/g; const stack = []; let m; const ids = [], under = new Set();
    while ((m = re.exec(j))) {
      const [, c, tag, attrs, self] = m;
      if (c) { while (stack.length && stack.pop().tag !== tag); continue; }
      const bg = (attrs.match(/backgroundColor: 'var\(--color-([a-z0-9-]+)\)'/) || [])[1];
      const id = (attrs.match(/\bid="([^"]+)"/) || [])[1];
      // a phone (a whole screen drawn inside a card) keeps the canvas: it's a page, not a pill
      const w = +(attrs.match(/\bwidth: '(\d+)px'/) || [])[1];
      // …and a page sitting on a surface.control phone frame (the journal drawer's pushed page) makes that frame an underlay
      if (bg === 'background-canvas' && PHONE_WIDTHS.has(w)) {
        const par = [...stack].reverse().find((x) => x.bg); if (par && par.bg === 'surface-control') under.add(par.id);
        if (!self) stack.push({ tag, bg, id }); continue;
      }
      if (bg === 'background-canvas') { const par = [...stack].reverse().find((x) => x.bg); if (par && TINTED.has(par.bg)) ids.push(id); }
      if (bg === 'background-raised') { const par = [...stack].reverse().find((x) => x.bg); if (par && par.bg === 'surface-control') under.add(par.id); }
      if (!self) stack.push({ tag, bg, id });
    }
    if (!ids.length && !under.size) continue;
    total += ids.length + under.size; console.log(`${a.name.slice(0, 60)}: ${ids.length} lifted, ${under.size} underlay`);
    const ups = [];
    if (ids.length) ups.push({ nodeIds: ids, styles: { backgroundColor: 'var(--color-surface-lifted)' } });
    if (under.size) ups.push({ nodeIds: [...under], styles: { backgroundColor: 'var(--color-background-underlay)' } });
    if (apply) await p.call('update_styles', { fileId: F, updates: ups });
  }
}
console.log(`${apply ? 'repointed' : 'would repoint'} ${total}`);
p.close();
