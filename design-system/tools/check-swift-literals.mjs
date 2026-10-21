// node design-system/tools/check-swift-literals.mjs [paths...]
// M14 F12: fails (exit 1) when new-design Swift writes a raw colour, size, font,
// spring, curve or haptic instead of a token (docs/design/swift-implementation-plan.md §3).
// Scans DesignSystemV2/ and Features/ by default. Generated tokens and the hand-built
// token files are exempt; a line can opt out with `// literal-ok: <reason>`.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = new URL('../../Retrospect/Retrospect/', import.meta.url).pathname;
const targets = process.argv.slice(2).length ? process.argv.slice(2) : ['DesignSystemV2', 'Features'].map((d) => join(root, d));
const exempt = [/\/Generated\//, /\/RType\.swift$/, /\/RDepth\.swift$/, /\/RMotionExtras\.swift$/, /\/RMotionLab\.swift$/, /\/RFoundationGallery\.swift$/];

const rules = [
  [/\b(UI)?Color\(\s*(red|white|hue)\s*:/, 'raw colour: use RColor'],
  [/#colorLiteral|Color\(\s*"#|Color\(hex/, 'raw colour: use RColor'],
  [/(?<![A-Za-z0-9_])\.(red|blue|green|black|white|gray|grey|orange|yellow|pink|purple)\b(?!\s*[:(])/, 'system colour: use RColor'],
  // .primary / .secondary are also common enum cases, so only flag them where a colour goes.
  [/(Color\s*\.|(foregroundStyle|foregroundColor|tint|fill|stroke|background)\(\s*\.)(primary|secondary|tertiary)\b/, 'system colour: use RColor'],
  [/\.font\(\s*\.system\(\s*size/, 'raw font: use .rText(...)'],
  [/\.(padding|frame|cornerRadius|spacing)\([^)]*\b\d+(\.\d+)?\b/, 'raw size: use RDimension'],
  [/spacing:\s*\d/, 'raw spacing: use RDimension'],
  [/\.spring\(|\.interpolatingSpring\(|\.interactiveSpring|\.easeIn|\.easeOut|\.linear\b|\.timingCurve\(|(?<!RMotion)\.(smooth|snappy|bouncy)\b|(withAnimation|animation)\(\s*\.default\b/, 'raw motion: use RMotion'],
  [/UI(Impact|Selection|Notification)FeedbackGenerator|\.sensoryFeedback\(\s*\.(impact|selection|success|warning|error)/, 'raw haptic: use RHaptic'],
];

const files = [];
const walk = (p) => {
  if (!existsSync(p)) return;
  if (statSync(p).isDirectory()) return readdirSync(p).forEach((f) => walk(join(p, f)));
  if (p.endsWith('.swift') && !exempt.some((r) => r.test(p))) files.push(p);
};
targets.forEach(walk);

// Drop a trailing // comment, but not a // inside a string literal (URLs).
const stripComment = (line) => {
  let inString = false;
  for (let i = 0; i < line.length - 1; i++) {
    if (line[i] === '"' && line[i - 1] !== '\\') inString = !inString;
    if (!inString && line[i] === '/' && line[i + 1] === '/') return line.slice(0, i);
  }
  return line;
};

// Every corner is a squircle (radius.style): this applies to every file, the hand-built
// token files included, since a circular corner is never right.
const shapeRules = [
  [/\bCapsule\(\s*\)|\bCapsule\(\s*style:\s*\.circular/, 'circular pill: use RShape.pill (radius.style)'],
  [/\bRoundedRectangle\(\s*cornerRadius:(?![^)]*\bstyle:)/, 'corner without a style: use RShape.rect(...) (radius.style)'],
  [/style:\s*\.circular\b/, 'circular corner: use RShape (radius.style)'],
  [/\.cornerRadius\(|\.rect\(\s*cornerRadius:(?![^)]*\bstyle:)/, 'circular corner: clip with RShape.rect(...) (radius.style)'],
];
const shapeFiles = [];
const walkAll = (p) => {
  if (!existsSync(p)) return;
  if (statSync(p).isDirectory()) return readdirSync(p).forEach((f) => walkAll(join(p, f)));
  if (p.endsWith('.swift') && !/\/Generated\//.test(p)) shapeFiles.push(p);
};
targets.forEach(walkAll);

let problems = 0;
for (const f of shapeFiles) {
  readFileSync(f, 'utf8').split('\n').forEach((line, i) => {
    const code = stripComment(line);
    if (/^\s*(\/\/\/|\/\/|\*)/.test(line)) return;
    for (const [re, msg] of shapeRules) {
      if (re.test(code)) {
        problems++;
        console.log(`${relative(root, f)}:${i + 1}: ${msg}\n    ${line.trim()}`);
        break;
      }
    }
  });
}
for (const f of files) {
  const text = readFileSync(f, 'utf8');
  // Sizes in modifiers whose arguments wrap onto the next lines (SwiftFormat wraps long calls).
  for (const m of text.matchAll(/\.(padding|frame|cornerRadius)\(\s*\n([^)]*)\)/g)) {
    if (/(^|[^A-Za-z0-9_.])\d+(\.\d+)?\b/.test(m[2].split('\n').map(stripComment).join(' ')) && !/literal-ok:/.test(m[0])) {
      problems++;
      const line = text.slice(0, m.index).split('\n').length;
      console.log(`${relative(root, f)}:${line}: raw size: use RDimension\n    ${m[0].replace(/\s+/g, ' ').trim()}`);
    }
  }
  text.split('\n').forEach((line, i) => {
    const code = stripComment(line);
    if (/literal-ok:/.test(line) || /^\s*(\/\/\/|\/\/|\*)/.test(line)) return;
    for (const [re, msg] of rules) {
      if (re.test(code)) {
        problems++;
        console.log(`${relative(root, f)}:${i + 1}: ${msg}\n    ${line.trim()}`);
        break;
      }
    }
  });
}
console.log(`${files.length} files checked, ${problems} literal(s).`);
process.exit(problems ? 1 : 0);
