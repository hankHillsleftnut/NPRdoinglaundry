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
  [/\.(red|blue|green|black|white|gray|orange|yellow|pink|purple)\b(?!\))/, 'system colour: use RColor'],
  [/\.font\(\s*\.system\(\s*size/, 'raw font: use .rText(...)'],
  [/\.(padding|frame|cornerRadius|spacing)\([^)]*\b\d+(\.\d+)?\b/, 'raw size: use RDimension'],
  [/spacing:\s*\d/, 'raw spacing: use RDimension'],
  [/\.spring\(|\.interpolatingSpring\(|\.easeIn|\.easeOut|\.linear\b|\.bouncy|\.timingCurve\(/, 'raw motion: use RMotion'],
  [/UI(Impact|Selection|Notification)FeedbackGenerator|\.sensoryFeedback\(\s*\.(impact|selection|success|warning|error)/, 'raw haptic: use RHaptic'],
];

const files = [];
const walk = (p) => {
  if (!existsSync(p)) return;
  if (statSync(p).isDirectory()) return readdirSync(p).forEach((f) => walk(join(p, f)));
  if (p.endsWith('.swift') && !exempt.some((r) => r.test(p))) files.push(p);
};
targets.forEach(walk);

let problems = 0;
for (const f of files) {
  readFileSync(f, 'utf8').split('\n').forEach((line, i) => {
    const code = line.replace(/\/\/.*$/, '');
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
