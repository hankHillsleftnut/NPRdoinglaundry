import type { NodeSpec, RegionId } from './types';
import { ALL_NODES, REGIONS } from './nodes';

// ---------------------------------------------------------------------------
// Structure is declared in the manifest (region, column, order); coordinates are
// derived here. Hand-typed x/y rots the moment a node is added, and full
// auto-layout reshuffles the whole board on every change, destroying the spatial
// memory that makes a graph this size usable at all. This is the middle.
// ---------------------------------------------------------------------------

export const CARD_W = 300;
export const CARD_H = 188;
export const GAP_X = 64;
export const GAP_Y = 34;
export const PAD = 38;
export const HEADER = 62;
export const REGION_GAP = 112;
export const BAND_GAP = 150;

export type Placed = { spec: NodeSpec; x: number; y: number };
export type RegionBox = {
  id: RegionId;
  title: string;
  blurb: string;
  x: number;
  y: number;
  w: number;
  h: number;
};

const colSpan = (n: number) => n * CARD_W + (n - 1) * GAP_X;
const rowSpan = (n: number) => n * CARD_H + (n - 1) * GAP_Y;

function layoutRegion(specs: NodeSpec[], originX: number, originY: number) {
  const byCol = new Map<number, NodeSpec[]>();
  for (const s of specs) {
    const c = s.column ?? 0;
    if (!byCol.has(c)) byCol.set(c, []);
    byCol.get(c)!.push(s);
  }
  const cols = [...byCol.keys()].sort((a, b) => a - b);
  for (const c of cols) byCol.get(c)!.sort((a, b) => a.order - b.order);

  const placed: Placed[] = [];
  let maxRows = 0;
  cols.forEach((c, i) => {
    const list = byCol.get(c)!;
    maxRows = Math.max(maxRows, list.length);
    list.forEach((spec, r) => {
      placed.push({
        spec,
        x: originX + PAD + i * (CARD_W + GAP_X),
        y: originY + HEADER + r * (CARD_H + GAP_Y),
      });
    });
  });

  const w = PAD * 2 + colSpan(Math.max(cols.length, 1));
  const h = HEADER + PAD + rowSpan(Math.max(maxRows, 1));
  return { placed, w, h };
}

export function computeLayout() {
  const mainRegions = REGIONS.filter((r) => r.id !== 'sinks');
  const nodes: Placed[] = [];
  const boxes: RegionBox[] = [];

  let x = 0;
  let mainHeight = 0;

  for (const region of mainRegions) {
    const specs = ALL_NODES.filter((n) => n.region === region.id);
    if (specs.length === 0) continue;
    const { placed, w, h } = layoutRegion(specs, x, 0);
    nodes.push(...placed);
    boxes.push({ id: region.id, title: region.title, blurb: region.blurb, x, y: 0, w, h });
    mainHeight = Math.max(mainHeight, h);
    x += w + REGION_GAP;
  }

  // Sinks get their own band across the bottom, so the board reads at a glance:
  // anything below the main flow is material that stopped.
  const sinkSpecs = ALL_NODES.filter((n) => n.region === 'sinks');
  if (sinkSpecs.length > 0) {
    const sinkY = mainHeight + BAND_GAP;
    const { placed, w, h } = layoutRegion(sinkSpecs, 0, sinkY);
    nodes.push(...placed);
    const meta = REGIONS.find((r) => r.id === 'sinks')!;
    boxes.push({ id: 'sinks', title: meta.title, blurb: meta.blurb, x: 0, y: sinkY, w, h });
  }

  const width = Math.max(...boxes.map((b) => b.x + b.w), 0);
  const height = Math.max(...boxes.map((b) => b.y + b.h), 0);
  return { nodes, boxes, width, height };
}
