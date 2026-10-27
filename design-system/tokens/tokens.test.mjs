// node --test design-system/tokens/tokens.test.mjs
// SH.composer (founder, 26 Oct): Paper's shadow stacks live beside the older recipes, never over them.
// 1. Every token that existed before (baseline.json, written by baseline.mjs) keeps its exact value
//    and dark value, and every generated Swift line it produced is still there, in order. New tokens
//    and new generated lines anywhere pass.
// 2. Each new depth.* shadow token equals Paper's box-shadow, copied verbatim from get_computed_styles
//    on the node named in its source, layer for layer (x, y, blur, spread, inset, colour token).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (p) => readFileSync(new URL(p, import.meta.url), 'utf8');
const tokens = JSON.parse(read('./tokens.json'));
const baseline = JSON.parse(read('./baseline.json'));
const get = (path) => path.split('.').reduce((o, k) => o?.[k], tokens);

test('every existing token keeps its value and dark value', () => {
  for (const [path, frozen] of Object.entries(baseline.tokens)) {
    const node = get(path);
    assert.ok(node && '$value' in node, `${path} was removed`);
    assert.deepEqual(node.$value, frozen.value, `${path} changed value`);
    assert.deepEqual(node.$extensions?.retrospect?.dark ?? null, frozen.dark, `${path} changed its dark value`);
  }
});

test('every existing generated Swift line is still there, in order (additions anywhere are fine)', () => {
  const lines = read('../../Retrospect/Retrospect/DesignSystemV2/Generated/Tokens.swift').split('\n');
  let at = 0;
  for (const want of baseline.generatedSwiftLines) {
    while (at < lines.length && lines[at] !== want) at++;
    assert.ok(at < lines.length, `generated line changed or removed: ${want.trim()}`);
    at++;
  }
});

// Paper's CSS, verbatim (file 01M5D5J321P5X86ZT58002B7NT). Colour vars map to the token they name.
const paper = {
  '1F7K-0': 'var(--color-depth-stroke-inner-top) 0px 1px 0px inset, var(--color-depth-stroke-inner) 0px 0px 0px 1px inset, var(--color-depth-stroke-outer) 0px 0px 0px 0.5px, var(--color-depth-shadow-contact) 0px 1px 2px, var(--color-depth-shadow-cast) 0px 12px 28px -12px, var(--color-depth-shadow-ambient) 0px 24px 60px -20px',
  '26LI-0': 'var(--color-depth-stroke-inner-top) 0px 1px 0px inset, var(--color-glow-primary-ring) 0px 0px 0px 0.5px, var(--color-depth-shadow-contact) 0px 1px 2px, color-mix(var(--color-sky-400) 45%, transparent) -64px 10px 34px -16px, color-mix(var(--color-sky-200) 60%, transparent) 72px -6px 30px -14px, color-mix(var(--color-sky-500) 38%, transparent) 18px 20px 36px -18px, color-mix(var(--color-amber-200) 26%, transparent) -10px -12px 26px -16px',
  'D9Z-0': 'var(--color-depth-stroke-inner-top) 0px 1px 0px inset, var(--color-depth-stroke-inner) 0px 0px 0px 1px inset, var(--color-depth-stroke-outer) 0px 0px 0px 0.5px, var(--color-depth-shadow-contact) 0px 1px 1.5px, var(--color-depth-shadow-cast) 0px 4px 6px -2px',
  'DA6-0': 'var(--color-depth-stroke-inner-top) 0px 1px 0px inset, var(--color-depth-stroke-inner) 0px 0px 0px 1px inset, var(--color-depth-stroke-outer) 0px 0px 0px 0.5px, var(--color-depth-shadow-contact) 0px 0.5px 1px, var(--color-depth-shadow-cast) 0px 1px 2px -1px',
  // ON-13 first home (1FI8-0), FH.home.a
  '1FJL-0': 'var(--color-depth-stroke-inner-top) 0px 1px 0px inset, var(--color-depth-stroke-inner) 0px 0px 0px 1px inset, var(--color-depth-stroke-outer) 0px 0px 0px 0.5px, var(--color-depth-shadow-contact) 0px 1px 2px, var(--color-depth-shadow-cast) 0px 12px 28px -12px',
  '1FJ6-0': 'var(--color-depth-stroke-inner-top) 0px 1px 0px inset, var(--color-depth-stroke-outer) 0px 0px 0px 0.5px, var(--color-depth-shadow-contact) 0px 1px 2px, var(--color-depth-shadow-cast) 0px 10px 24px -12px',
};
// Paper's colour variables and mixes → the token each new layer must reference.
const colourToken = {
  'var(--color-depth-stroke-inner-top)': '{depth.stroke.innerTop}',
  'var(--color-depth-stroke-inner)': '{depth.stroke.inner}',
  'var(--color-depth-stroke-outer)': '{depth.stroke.outer}',
  'var(--color-depth-shadow-contact)': '{depth.shadow.contact}',
  'var(--color-depth-shadow-cast)': '{depth.shadow.cast}',
  'var(--color-depth-shadow-ambient)': '{depth.shadow.ambient}',
  'var(--color-glow-primary-ring)': '{glow.primary.ring}',
  'color-mix(var(--color-sky-400) 45%, transparent)': '{color.voice.glowPool}',
  'color-mix(var(--color-sky-200) 60%, transparent)': '{color.voice.glowLift}',
  'color-mix(var(--color-sky-500) 38%, transparent)': '{color.voice.glowUnder}',
  'color-mix(var(--color-amber-200) 26%, transparent)': '{color.voice.glowTop}',
};

function parse(css) {
  return css.split(/,\s*(?=var\(|color-mix\()/).map((part) => {
    const m = part.trim().match(/^(var\([^)]*\)|color-mix\(var\([^)]*\)\s+\d+%,\s*transparent\))\s+(.*)$/);
    assert.ok(m, `cannot parse "${part}"`);
    const words = m[2].trim().split(/\s+/);
    const inset = words.at(-1) === 'inset';
    const [x, y, blur, spread = '0px'] = (inset ? words.slice(0, -1) : words).map((w) => w.replace('px', 'pt'));
    const color = colourToken[m[1].replace(/\s+/g, ' ')];
    assert.ok(color, `no token for Paper colour ${m[1]}`);
    return { offsetX: x, offsetY: y, blur, spread, color, ...(inset ? { inset: true } : {}) };
  });
}
const pt = (layer) => ({ ...layer, ...Object.fromEntries(['offsetX', 'offsetY', 'blur', 'spread'].map((k) => [k, `${+parseFloat(layer[k])}pt`])) });
const outerOnly = (layers) => layers.filter((l) => !l.inset && !(l.blur === '0pt' && l.offsetX === '0pt' && l.offsetY === '0pt'));

const pinned = [
  ['depth.boxShadow.composer.rest', '1F7K-0', (l) => l],
  ['depth.boxShadow.composer.listening', '26LI-0', (l) => l],
  ['depth.boxShadow.pill.raised.rest', 'D9Z-0', (l) => l],
  ['depth.boxShadow.pill.raised.pressed', 'DA6-0', (l) => l],
  ['depth.boxShadow.firstHome.recap', '1FJ6-0', (l) => l],
  ['depth.boxShadow.firstHome.episodeCard', '1FJL-0', (l) => l],
  ['depth.boxShadow.stroke.innerTop', '1F7K-0', (l) => l.slice(0, 1)],
  ['depth.boxShadow.stroke.inner', '1F7K-0', (l) => l.slice(1, 2)],
  ['depth.boxShadow.stroke.outer', '1F7K-0', (l) => l.slice(2, 3)],
  // the outer-only stacks (no strokes): the contact and the pulled-in casts / glows
  ['depth.glow.listening', '26LI-0', outerOnly],
  ['depth.pill.raised.rest', 'D9Z-0', outerOnly],
  ['depth.pill.raised.pressed', 'DA6-0', outerOnly],
];

for (const [path, node, pick] of pinned) {
  test(`${path} equals Paper ${node}`, () => {
    const token = get(path);
    assert.ok(token, `${path} missing`);
    assert.equal(token.$type, 'shadow');
    assert.match(token.$extensions.retrospect.source, new RegExp(node.replace('-', '\\-')), `${path} must name Paper ${node} as its source`);
    assert.deepEqual(token.$value.map(pt), pick(parse(paper[node])).map(pt));
  });
}
