'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ReactFlow,
  ReactFlowProvider,
  Background,
  BackgroundVariant,
  Controls,
  MarkerType,
  PanOnScrollMode,
  type Edge,
  type Node,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';

import { computeLayout } from '@/lib/layout';
import { ALL_EDGES, ALL_NODES } from '@/lib/nodes';
import type { Health, NodeState, SourceMeta } from '@/lib/types';
import { HEALTH_COLOR, HEALTH_LABEL, pathGrey } from '@/lib/colors';
import { Badge } from './Badge';
import { pathFrom } from '@/lib/graph';
import { PipelineNode } from './PipelineNode';
import { RegionNode } from './RegionNode';
import { DetailPanel } from './DetailPanel';

const nodeTypes = { pipeline: PipelineNode, region: RegionNode };

type SnapshotResponse = {
  takenAt: string;
  windowHours: number;
  states: Record<string, NodeState>;
  sources: Record<string, SourceMeta>;
  error?: string;
};

const POLL_MS = 30_000;
const LEGEND: Health[] = ['ok', 'degraded', 'failed', 'idle', 'never', 'notInstrumented', 'unknown'];

function CanvasInner() {
  const [snap, setSnap] = useState<SnapshotResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const res = await fetch('/api/snapshot', { cache: 'no-store' });
      const body = (await res.json()) as SnapshotResponse;
      if (!res.ok) throw new Error(body.error ?? `HTTP ${res.status}`);
      setSnap(body);
      setError(null);
    } catch (e) {
      // Leave the previous snapshot on screen but say loudly that it is stale;
      // silently showing old green is the failure mode this board exists to avoid.
      setError(e instanceof Error ? e.message : 'failed to load');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
    const t = setInterval(() => {
      if (!document.hidden) load();
    }, POLL_MS);
    return () => clearInterval(t);
  }, [load]);

  const layout = useMemo(() => computeLayout(), []);

  const matches = useCallback(
    (id: string) => {
      const q = query.trim().toLowerCase();
      if (!q) return true;
      const spec = ALL_NODES.find((n) => n.id === id);
      if (!spec) return false;
      return (
        spec.title.toLowerCase().includes(q) ||
        spec.purpose.toLowerCase().includes(q) ||
        spec.id.toLowerCase().includes(q) ||
        (spec.source ?? '').toLowerCase().includes(q)
      );
    },
    [query],
  );

  // The chain the clicked card sits on, as hop distances. Null when nothing is
  // selected, in which case every card renders normally.
  const path = useMemo(() => pathFrom(selectedId), [selectedId]);

  const nodes: Node[] = useMemo(() => {
    const regionNodes: Node[] = layout.boxes.map((box) => ({
      id: `region:${box.id}`,
      type: 'region',
      position: { x: box.x, y: box.y },
      data: { box },
      draggable: false,
      selectable: false,
      zIndex: 0,
      style: { zIndex: 0 },
    }));

    const cardNodes: Node[] = layout.nodes.map(({ spec, x, y }) => ({
      id: spec.id,
      type: 'pipeline',
      position: { x, y },
      draggable: false,
      zIndex: 1,
      data: {
        spec,
        state: snap?.states?.[spec.id],
        dimmed: !matches(spec.id),
        selected: selectedId === spec.id,
        pathDepth: path === null ? null : (path.get(spec.id) ?? -1),
      },
    }));

    return [...regionNodes, ...cardNodes];
  }, [layout, snap, matches, selectedId, path]);

  const edges: Edge[] = useMemo(
    () =>
      ALL_EDGES.map((e, i) => {
        const targetState = snap?.states?.[e.to];
        const dim = !matches(e.from) && !matches(e.to);

        const isBranch = e.kind === 'branch';
        const isInferred = e.kind === 'inferred';

        // An edge is on the path only when both ends are. Its grey comes from
        // the further of its two endpoints, so the chain fades outward evenly.
        const fromDepth = path?.get(e.from);
        const toDepth = path?.get(e.to);
        const onPath = fromDepth !== undefined && toDepth !== undefined;
        const offPath = path !== null && !onPath;

        const stroke = onPath
          ? pathGrey(Math.max(fromDepth!, toDepth!))
          : isBranch
            ? 'var(--degraded)'
            : isInferred
              ? 'var(--text-faint)'
              : '#3f3f3f';

        // A branch edge carries its own count, so a firing branch is legible
        // without opening anything.
        const count = isBranch && targetState && targetState.total > 0 ? targetState.total : null;
        const label = [e.label, count !== null ? `${count}` : null].filter(Boolean).join(' · ');

        return {
          id: `e${i}`,
          source: e.from,
          target: e.to,
          type: 'smoothstep',
          animated: path === null && e.kind === 'flow' && targetState?.health === 'ok',
          label: label || undefined,
          labelStyle: { fill: stroke, fontSize: 10.5, fontWeight: 600 },
          labelBgStyle: { fill: 'var(--bg)', fillOpacity: 0.92 },
          labelBgPadding: [5, 3] as [number, number],
          labelBgBorderRadius: 4,
          style: {
            stroke,
            strokeWidth: onPath ? 2.4 : isBranch ? 1.6 : 1.4,
            strokeDasharray: isBranch ? '6 4' : isInferred ? '2 4' : undefined,
            opacity: dim || offPath ? 0.07 : onPath ? 1 : isInferred ? 0.5 : 0.85,
          },
          markerEnd: isInferred
            ? undefined
            : { type: MarkerType.ArrowClosed, color: stroke, width: 14, height: 14 },
          zIndex: 2,
        } satisfies Edge;
      }),
    [snap, matches, path],
  );

  const selectedSpec = selectedId ? ALL_NODES.find((n) => n.id === selectedId) : undefined;
  const selectedSource =
    selectedSpec && selectedSpec.probe.kind === 'rollup'
      ? snap?.sources?.[selectedSpec.probe.source]
      : undefined;

  const counts = useMemo(() => {
    const c: Partial<Record<Health, number>> = {};
    for (const spec of ALL_NODES) {
      const h = snap?.states?.[spec.id]?.health ?? 'unknown';
      c[h] = (c[h] ?? 0) + 1;
    }
    return c;
  }, [snap]);

  return (
    <div className="shell">
      <div className="topbar">
        <h1>Retrospect pipeline</h1>
        <span className="sub">{ALL_NODES.length} steps</span>
        <div className="spacer" />
        <input
          className="search"
          placeholder="Find a step…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <span className="sub">
          {loading && !snap ? 'loading…' : snap ? `updated ${new Date(snap.takenAt).toLocaleTimeString()}` : ''}
        </span>
        <button className="btn" onClick={load}>Refresh</button>
        <form action="/api/logout" method="post" onSubmit={(e) => {
          e.preventDefault();
          fetch('/api/logout', { method: 'POST' }).then(() => window.location.reload());
        }}>
          <button className="btn" type="submit">Sign out</button>
        </form>
      </div>

      {error && (
        <div className="banner">
          Could not refresh: {error}. Nothing below is current — treat every colour as unverified.
        </div>
      )}

      <div className="legend">
        {LEGEND.map((h) => (
          <span className="item" key={h}>
            <Badge health={h} />
            {HEALTH_LABEL[h]}
            <span style={{ color: 'var(--text-faint)' }}>{counts[h] ?? 0}</span>
          </span>
        ))}
      </div>

      <div className="canvas-wrap">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          nodeTypes={nodeTypes}
          // Deliberately NOT fitView. The canvas is ~6800px wide, so fitting it
          // lands at ~0.2 zoom -- the glyph mosaic, where no card says what it is
          // for. Opening at the start of the pipeline at a readable zoom is the
          // more useful first screen; the Controls' fit button gives the mosaic
          // overview in one click.
          defaultViewport={{ x: 60, y: 40, zoom: 0.78 }}
          minZoom={0.12}
          maxZoom={1.6}
          // Trackpad behaviour: two fingers pan the canvas, pinch zooms. Scroll
          // wheel zooming a board this wide made it far too easy to fling
          // yourself off the graph with an ordinary two-finger gesture.
          panOnScroll
          panOnScrollMode={PanOnScrollMode.Free}
          zoomOnScroll={false}
          zoomOnPinch
          zoomOnDoubleClick={false}
          nodesDraggable={false}
          nodesConnectable={false}
          elementsSelectable
          proOptions={{ hideAttribution: true }}
          onNodeClick={(_, node) => {
            if (node.type === 'pipeline') setSelectedId(node.id);
          }}
          onPaneClick={() => setSelectedId(null)}
        >
          <Background variant={BackgroundVariant.Dots} gap={22} size={1} color="#242424" />
          <Controls showInteractive={false} />
        </ReactFlow>

        {selectedSpec && (
          <DetailPanel
            spec={selectedSpec}
            state={snap?.states?.[selectedSpec.id]}
            sourceMeta={selectedSource}
            onClose={() => setSelectedId(null)}
          />
        )}
      </div>
    </div>
  );
}

export function Canvas() {
  return (
    <ReactFlowProvider>
      <CanvasInner />
    </ReactFlowProvider>
  );
}
