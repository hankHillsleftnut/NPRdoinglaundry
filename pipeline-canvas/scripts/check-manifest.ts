import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { ALL_NODES, ALL_EDGES } from '../lib/nodes';
import { SOURCES } from '../lib/rollup';
import { computeLayout } from '../lib/layout';

// Guards the manifest as *content*. The purpose strings and the honesty of the
// notInstrumented reasons are the product value here, so they are enforced.

const problems: string[] = [];
const ids = new Set<string>();
const sourceNames = new Set(SOURCES.map((s) => s.source));

for (const n of ALL_NODES) {
  if (ids.has(n.id)) problems.push(`duplicate node id: ${n.id}`);
  ids.add(n.id);

  if (!n.purpose || n.purpose.trim().length < 12) {
    problems.push(`${n.id}: purpose is missing or too short to be useful`);
  }
  if (!/[.!?]$/.test(n.purpose.trim())) {
    problems.push(`${n.id}: purpose should be a sentence ending in punctuation`);
  }
  if (n.isNew && n.isLegacy) {
    problems.push(`${n.id}: cannot be both new and superseded`);
  }
  if (n.probe.kind === 'notInstrumented') {
    if (!n.probe.reason?.trim()) problems.push(`${n.id}: notInstrumented needs a reason`);
    if (!n.probe.wouldNeed?.trim()) problems.push(`${n.id}: notInstrumented needs wouldNeed`);
  } else if (!sourceNames.has(n.probe.source)) {
    problems.push(`${n.id}: probe reads unknown source "${n.probe.source}"`);
  }
}

const seenSlots = new Set<string>();
for (const n of ALL_NODES) {
  const slot = `${n.region}/${n.column ?? 0}/${n.order}`;
  if (seenSlots.has(slot)) problems.push(`layout collision at ${slot} (${n.id})`);
  seenSlots.add(slot);
}

for (const e of ALL_EDGES) {
  if (!ids.has(e.from)) problems.push(`edge from unknown node: ${e.from} -> ${e.to}`);
  if (!ids.has(e.to)) problems.push(`edge to unknown node: ${e.from} -> ${e.to}`);
}

// Every file:line on a card must point at a file that actually exists. Without
// this, a rename anywhere in either repo quietly turns the board's citations
// into fiction -- and a citation nobody can follow is worse than none.
const REPO_ROOTS = [resolve('..'), resolve('../..')];
for (const n of ALL_NODES) {
  if (!n.source) continue;
  const path = n.source.split(':')[0];
  if (path.includes(' = ')) continue; // pseudo-source, e.g. a column predicate
  if (!REPO_ROOTS.some((root) => existsSync(resolve(root, path)))) {
    problems.push(`${n.id}: source path does not exist -> ${path}`);
  }
}

const layout = computeLayout();
if (layout.nodes.length !== ALL_NODES.length) {
  problems.push(`layout placed ${layout.nodes.length} of ${ALL_NODES.length} nodes`);
}

const unusedSources = [...sourceNames].filter(
  (s) => !ALL_NODES.some((n) => n.probe.kind === 'rollup' && n.probe.source === s),
);

console.log(`nodes: ${ALL_NODES.length}  edges: ${ALL_EDGES.length}  canvas: ${layout.width}x${layout.height}`);
const blind = ALL_NODES.filter((n) => n.probe.kind === 'notInstrumented').length;
console.log(`instrumented: ${ALL_NODES.length - blind}   not recorded: ${blind}`);
console.log(`marked new (second brain): ${ALL_NODES.filter((n) => n.isNew).length}`);
console.log(`marked superseded:          ${ALL_NODES.filter((n) => n.isLegacy).length}`);
if (unusedSources.length) console.log(`sources with no node: ${unusedSources.join(', ')}`);

if (problems.length) {
  console.error(`\n${problems.length} problem(s):`);
  for (const p of problems) console.error(`  - ${p}`);
  process.exit(1);
}
console.log('manifest ok');
