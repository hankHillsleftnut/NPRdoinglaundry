// node design-system/token-check.mjs <file.html|file.jsx> [...]
// The token pass for a screen: every colour, type value, radius, spacing and opacity must be a
// token (var(--…)). Reports each raw value with the property it sits in.
// Allowed raw: 0, transparent, frame width/height/position, shadow geometry (Paper has no shadow token type;
// shadow colours must still be tokens), gradient stop positions, SVG path data and icon art.
import { readFileSync } from 'node:fs';

const TOKENISED = {
  colour: /^(color|background|background-color|backgroundColor|border-color|borderColor|fill|stroke|box-shadow|boxShadow|text-shadow|textShadow|outline-color)$/,
  type: /^(font-family|fontFamily|font-size|fontSize|font-weight|fontWeight|letter-spacing|letterSpacing|line-height|lineHeight)$/,
  radius: /^(border-radius|borderRadius|border-top-left-radius|border-top-right-radius|borderTopLeftRadius|borderTopRightRadius)$/,
  spacing: /^(gap|row-gap|column-gap|padding|padding-[a-z]+|padding[A-Z][a-z]+|margin|margin-[a-z]+|margin[A-Z][a-z]+)$/,
  opacity: /^opacity$/,
};
const RAW_COLOUR = /#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)|hsla?\([^)]*\)|oklch\([^)]*\)/g;

const problems = [];
for (const file of process.argv.slice(2)) {
  // brand marks (the Google G, the Apple logo) keep their own colours: wrap them in <svg data-brand>
  // Apple's status bar is system chrome, pasted unmodified from Paper's guide (layer "Status bar"): not ours to tokenise
  const src = readFileSync(file, 'utf8').replace(/<svg[^>]*data-brand[\s\S]*?<\/svg>/g, '')
    .replace(/<div layer-name="Status bar"[\s\S]*?<\/svg><\/div><\/div>/g, '');
  // inline CSS: style="a:b;c:d"  and JSX: style={{ a: 'b', c: 'd' }}
  const decls = [];
  for (const [, css] of src.matchAll(/style="([^"]*)"/g)) for (const d of css.split(';')) { const i = d.indexOf(':'); if (i > 0) decls.push([d.slice(0, i).trim(), d.slice(i + 1).trim()]); }
  // Paper's JSX export puts an invisible default (fontSize 12px, lineHeight 16px) on every frame; skip that pair
  for (const [, obj] of src.matchAll(/style=\{\{([^}]*)\}\}/g)) for (const [, k, v] of obj.matchAll(/(\w+):\s*'([^']*)'/g)) if (!((k === 'fontSize' && v === '12px') || (k === 'lineHeight' && v === '16px'))) decls.push([k, v]);
  for (const [prop, value] of decls) {
    const kind = Object.keys(TOKENISED).find((k) => TOKENISED[k].test(prop));
    if (!kind) continue;
    const bare = value.replace(/var\(--[a-z0-9-]+\)/g, '');
    if (kind === 'colour') {
      for (const m of bare.matchAll(RAW_COLOUR)) problems.push(`${file}: ${prop} uses raw colour ${m[0]}`);
      if (/\b(white|black)\b/.test(bare) && !/none/.test(bare)) problems.push(`${file}: ${prop} uses a named colour`);
    } else if (kind === 'type') {
      if (bare.trim() && !/^(inherit|normal)$/.test(bare.trim())) problems.push(`${file}: ${prop} is "${value}", not a token`);
    } else if (kind === 'radius' || kind === 'spacing') {
      if (/\d/.test(bare.replace(/\b0(px)?\b/g, ''))) problems.push(`${file}: ${prop} is "${value}", not a token`);
    } else if (kind === 'opacity') {
      if (!/var\(/.test(value) && !/^(0|1)$/.test(value)) problems.push(`${file}: opacity ${value} is not a token`);
    }
  }
  // SVG attributes outside icon art: fill/stroke colours on shapes must be tokens too
  for (const m of src.matchAll(/\s(fill|stroke)="(#[0-9a-fA-F]{3,8}|rgba?\([^"]*\))"/g)) problems.push(`${file}: svg ${m[1]}="${m[2]}" is not a token`);
}
console.log(`${problems.length} raw value(s)`);
for (const p of problems) console.log('  ✗', p);
process.exit(problems.length ? 1 : 0);
