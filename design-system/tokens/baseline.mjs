// node design-system/tokens/baseline.mjs [git-ref]   (default: origin/main)
// Writes baseline.json: every token's value and dark value, and every line of the generated
// Tokens.swift, as they are at <git-ref>. tokens.test.mjs then fails if any of them changes or
// disappears, while new tokens and new generated lines (anywhere) pass. Re-run it only for a
// deliberate, founder-approved change to an existing token, in the same PR, and say why.
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';

const ref = process.argv[2] ?? 'origin/main';
const show = (path) => execFileSync('git', ['show', `${ref}:${path}`], { encoding: 'utf8', maxBuffer: 64 << 20 });
const tokens = JSON.parse(show('design-system/tokens/tokens.json'));
const swift = show('Retrospect/Retrospect/DesignSystemV2/Generated/Tokens.swift');

const frozen = {};
(function walk(o, path) {
  if (!o || typeof o !== 'object') return;
  if ('$value' in o) {
    frozen[path.join('.')] = { value: o.$value, dark: o.$extensions?.retrospect?.dark ?? null };
    return;
  }
  for (const [k, v] of Object.entries(o)) if (!k.startsWith('$')) walk(v, [...path, k]);
})(tokens, []);

const rev = execFileSync('git', ['rev-parse', '--short', ref], { encoding: 'utf8' }).trim();
writeFileSync(
  new URL('./baseline.json', import.meta.url),
  JSON.stringify(
    {
      $description: `Frozen values of every token, and every generated Swift line, as at ${ref} ${rev}. Checked by tokens.test.mjs: an existing value or line that changes or disappears fails; additions anywhere pass. Regenerate with baseline.mjs only for a deliberate, founder-approved change, and say why in the PR.`,
      generatedSwiftLines: swift.split('\n').filter((l) => l.trim() !== ''),
      tokens: frozen,
    },
    null,
    1,
  ) + '\n',
);
console.log(`baseline.json: ${Object.keys(frozen).length} tokens, ${swift.split('\n').filter((l) => l.trim()).length} generated lines from ${ref} ${rev}`);
