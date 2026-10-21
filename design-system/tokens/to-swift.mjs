// node design-system/tokens/to-swift.mjs [tokens.json] [out.swift]
// M14 step 1 (process.md Part 3: "Tokens first: generated Swift from tokens.json"). One source for values:
// this file is generated, never edited. Colours resolve light and dark from tokens.json (the
// $extensions.retrospect.dark value; color.*, glow.* and depth.*) into dynamic UIColors; dimensions, radii, opacity, durations and type
// sizes become CGFloat / Double constants. Names follow the token path in lowerCamelCase.
import { readFileSync, writeFileSync } from 'node:fs';

const src = process.argv[2] ?? new URL('./tokens.json', import.meta.url).pathname;
const out = process.argv[3] ?? new URL('../../Retrospect/Retrospect/DesignSystemV2/Generated/Tokens.swift', import.meta.url).pathname;
const T = JSON.parse(readFileSync(src, 'utf8'));
const get = (p) => p.split('.').reduce((o, k) => (o ? o[k] : undefined), T);

function resolve(v, dark, seen = 0) {
  if (seen > 12) throw new Error('reference loop at ' + v);
  if (typeof v !== 'string') return v;
  const m = v.match(/^\{([^}]+)\}$/);
  if (!m) return v;
  const n = get(m[1]);
  if (!n) throw new Error('missing ' + m[1]);
  const dv = n.$extensions?.retrospect?.dark;
  return resolve(dark && dv !== undefined ? dv : n.$value, dark, seen + 1);
}

function rgba(c) {
  c = String(c).trim();
  let m;
  if ((m = c.match(/^#([0-9a-f]{6})([0-9a-f]{2})?$/i))) {
    const h = m[1];
    return [0, 2, 4].map((i) => parseInt(h.substr(i, 2), 16) / 255).concat(m[2] ? parseInt(m[2], 16) / 255 : 1);
  }
  if ((m = c.match(/^rgba?\(([^)]+)\)$/))) {
    const p = m[1].split(/[\s,/]+/).filter(Boolean).map((x) => (x.endsWith('%') ? parseFloat(x) / 100 : parseFloat(x)));
    return [p[0] / 255, p[1] / 255, p[2] / 255, p[3] ?? 1];
  }
  return null;
}

const camel = (path) =>
  path.split(/[.\-_ ]/).filter(Boolean).map((s, i) => (i ? s[0].toUpperCase() + s.slice(1) : s)).join('')
    .replace(/^(\d)/, '_$1');
const num = (v) => {
  const n = parseFloat(String(v));
  return Number.isFinite(n) ? n : null;
};
const f = (x) => (+x.toFixed(4)).toString();

const colors = [], dims = [], numbers = [], springs = [], curves = [], haptics = [], artwork = [], skipped = [];
let cornerStyle = null;
(function walk(o, path) {
  if (!o || typeof o !== 'object') return;
  if ('$value' in o) {
    const type = o.$type, name = camel(path);
    if (type === 'color' && /^(color|glow|depth)\./.test(path)) {
      const light = rgba(resolve(o.$value, false));
      const dv = o.$extensions?.retrospect?.dark;
      const dark = rgba(resolve(dv ?? o.$value, true));
      if (light && dark) colors.push({ name: camel(path.startsWith('color.') ? path.slice(6) : path), light, dark, doc: o.$description });
      else skipped.push(path);
    } else if (type === 'dimension' && /^(space|size|radius|layout|font\.size|motion\.)/.test(path)) {
      const n = num(resolve(o.$value, false));
      n === null ? skipped.push(path) : dims.push({ name, n, doc: o.$description });
    } else if (type === 'dimension' && /^font\.tracking\./.test(path)) {
      // em values: a fraction of the font size, applied by RType
      const n = num(resolve(o.$value, false));
      n === null ? skipped.push(path) : numbers.push({ name, n, doc: o.$description });
    } else if (type === 'gradient' && /^gradient\.mesh/.test(path) && typeof o.$value === 'string' && o.$value.startsWith('base ')) {
      // "base #hex; blob #hex at X% Y% r R% (alpha A→0); …; grain N%"
      const v = o.$value;
      const base = v.match(/base (#[0-9a-f]{6})/i)?.[1];
      const blobs = [...v.matchAll(/blob (#[0-9a-f]{6}) at (\d+)% (\d+)% r (\d+)%(?:[^;]*?alpha \.?(\d*\.?\d+)→0)?/gi)].map((m) => ({
        hex: m[1], x: +m[2] / 100, y: +m[3] / 100, r: +m[4] / 100,
        a: m[5] === undefined ? 1 : (m[5].startsWith('.') ? +('0' + m[5]) : (+m[5] > 1 ? +('0.' + m[5]) : +m[5])),
      }));
      const grain = +(v.match(/grain (\d+(?:\.\d+)?)%/)?.[1] ?? 0) / 100;
      if (base && blobs.length) artwork.push({ name: camel(path.slice('gradient.mesh'.length).replace(/^./, (c) => c.toLowerCase())), base, blobs, grain, doc: o.$description });
      else skipped.push(path);
    } else if (type === 'spring' && /^motion\.spring\./.test(path)) {
      const v = o.$value;
      springs.push({ name: camel(path.slice('motion.spring.'.length)), r: v.response, d: v.dampingFraction, doc: o.$description });
    } else if (type === 'cubicBezier' && /^motion\.curve\./.test(path) && Array.isArray(o.$value)) {
      curves.push({ name: camel(path.slice('motion.curve.'.length)), p: o.$value, doc: o.$description });
    } else if (type === 'string' && path === 'radius.style') {
      cornerStyle = { v: String(o.$value), doc: o.$description };
    } else if (type === 'string' && /^haptic\./.test(path)) {
      haptics.push({ name: camel(path.slice('haptic.'.length)), v: String(o.$value), doc: o.$description });
    } else if ((type === 'number' && /^(opacity|layer|motion\.|radius\.)/.test(path)) || type === 'duration') {
      const n = num(resolve(o.$value, false));
      n === null ? skipped.push(path) : numbers.push({ name, n: type === 'duration' && /ms$/.test(String(o.$value)) ? n / 1000 : n, doc: o.$description });
    } else skipped.push(path);
    return;
  }
  for (const [k, v] of Object.entries(o)) if (!k.startsWith('$')) walk(v, path ? `${path}.${k}` : k);
})(T, '');

const doc = (d) => (d ? `    /// ${String(d).replace(/\n/g, ' ')}\n` : '');
const hexColor = (h) => { const [r, g, b] = rgba(h); return `Color(red: ${f(r)}, green: ${f(g)}, blue: ${f(b)})`; };
const ui = ([r, g, b, a]) => `UIColor(red: ${f(r)}, green: ${f(g)}, blue: ${f(b)}, alpha: ${f(a)})`;
// haptic token value → SwiftUI SensoryFeedback (typeOn's intensity is handled by RHaptic.typeOn())
const feedback = (v) => {
  const [kind, intensity] = v.split('@');
  const base = feedbackKinds[kind];
  if (!base || !intensity) return base;
  return base.replace(/\)$/, `, intensity: ${intensity})`);
};
const feedbackKinds = ({
  'selection': '.selection',
  'notification.success': '.success',
  'notification.warning': '.warning',
  'notification.error': '.error',
  'impact.light': '.impact(weight: .light)',
  'impact.medium': '.impact(weight: .medium)',
  'impact.heavy': '.impact(weight: .heavy)',
  'impact.soft': '.impact(flexibility: .soft)',
  'impact.rigid': '.impact(flexibility: .rigid)',
});
const lines = [
  '// Generated by design-system/tokens/to-swift.mjs from tokens.json. Do not edit; change the token and regenerate.',
  'import SwiftUI',
  'import UIKit',
  '',
  'private func dynamic(_ light: UIColor, _ dark: UIColor) -> Color {',
  '    Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })',
  '}',
  '',
  '/// Semantic colours. Each resolves to its light or dark value from tokens.json.',
  'public enum RColor {',
  ...colors.map((c) => `${doc(c.doc)}    public static let ${c.name} = dynamic(${ui(c.light)}, ${ui(c.dark)})`),
  '}',
  '',
  '/// Spacing, sizes, radii, layout and type sizes, in points.',
  'public enum RDimension {',
  ...dims.map((d) => `${doc(d.doc)}    public static let ${d.name}: CGFloat = ${f(d.n)}`),
  '}',
  '',
  ...(cornerStyle
    ? [
        '/// Corner shape from radius.style. Views draw corners through RShape, never a bare Capsule() or RoundedRectangle.',
        'public enum RCorner {',
        `${doc(cornerStyle.doc)}    public static let style: RoundedCornerStyle = .${cornerStyle.v}`,
        '}',
        '',
      ]
    : []),
  '/// Springs and curves from motion.* (design-system/principles/motion-system.md). Views use these, never a raw .spring(...).',
  'public enum RMotion {',
  ...springs.map((m) => `${doc(m.doc)}    public static let ${m.name}: Animation = .spring(response: ${f(m.r)}, dampingFraction: ${f(m.d)})`),
  ...curves.map((c) => `${doc(c.doc)}    public static func ${c.name}(_ duration: Double) -> Animation { .timingCurve(${c.p.map(f).join(', ')}, duration: duration) }`),
  '}',
  '',
  '/// Episode artwork recipes from gradient.mesh* (principles/gradients.md: blobs fading in alpha over a base, plus grain).',
  'public enum RArtworkRecipes {',
  ...artwork.map((a) => `${doc(a.doc)}    public static let ${a.name} = RArtworkRecipe(base: ${hexColor(a.base)}, blobs: [${a.blobs.map((b) => `.init(color: ${hexColor(b.hex)}, x: ${f(b.x)}, y: ${f(b.y)}, radius: ${f(b.r)}, alpha: ${f(b.a)})`).join(', ')}], grain: ${f(a.grain)})`),
  '}',
  '',
  '/// Haptics from haptic.* as SwiftUI feedback. Pair each with the visual change it lands on.',
  'public enum RHaptic {',
  ...haptics.filter((h) => feedback(h.v)).map((h) => `${doc(h.doc)}    public static let ${h.name}: SensoryFeedback = ${feedback(h.v)}`),
  '}',
  '',
  '/// Opacities, layers and durations (seconds).',
  'public enum RNumber {',
  ...numbers.map((d) => `${doc(d.doc)}    public static let ${d.name}: Double = ${f(d.n)}`),
  '}',
  '',
];
writeFileSync(out, lines.join('\n'));
console.log(`${out}: ${colors.length} colours, ${dims.length} dimensions, ${numbers.length} numbers, ${springs.length} springs, ${curves.length} curves, ${haptics.length} haptics, ${artwork.length} artworks; ${skipped.length} tokens left for hand-built Swift (type styles, shadows, gradients, springs, haptics, materials)`);
