'use client';

import { memo } from 'react';
import { Handle, Position, useStore } from '@xyflow/react';
import type { NodeSpec, NodeState } from '@/lib/types';
import { HEALTH_BADGE, glyph, pathGrey, pathFill } from '@/lib/colors';
import { Badge } from './Badge';
import { CornerTag } from './CornerTag';

export type PipelineNodeData = {
  spec: NodeSpec;
  state: NodeState | undefined;
  dimmed: boolean;
  selected: boolean;
  /** hops from the clicked card; null when nothing is selected, -1 when off the path */
  pathDepth: number | null;
};

// Level of detail. At fit-view zoom a card is far too small for body text, so
// rather than shrink the text into noise the card changes what it renders. The
// purpose line earns its place in the middle tier -- what a step is FOR is the
// thing worth reading, and it should not require zooming all the way in.
const FAR = 0.34;
const MID = 0.58;

function PipelineNodeInner({ data }: { data: PipelineNodeData }) {
  const zoom = useStore((s) => s.transform[2]);
  const { spec, state, dimmed, selected, pathDepth } = data;

  const health = state?.health ?? 'unknown';
  // Zoomed all the way out the board becomes a pass/fail map, so the initials
  // borrow the badge's colour rather than the grey ramp.
  const badge = HEALTH_BADGE[health];
  const mosaicColor = badge.bg === 'transparent' ? badge.fg : badge.bg;
  const tier = zoom < FAR ? 'far' : zoom < MID ? 'mid' : 'near';

  const offPath = pathDepth === -1;
  const onPath = pathDepth !== null && pathDepth >= 0;

  const cls = [
    'card',
    `lod-${tier}`,
    dimmed ? 'dim' : '',
    offPath ? 'off-path' : '',
    selected ? 'selected' : '',
    onPath && !selected ? 'on-path' : '',
    spec.isNew || spec.isLegacy ? 'is-new' : '',
  ]
    .filter(Boolean)
    .join(' ');

  // Health lives on the dot alone. It used to also colour the left edge, but in
  // a monochrome palette the brightest health state became a glaring white bar
  // down every failing card, which read as damage to the layout rather than
  // information. The frame is now free to carry the path ramp on its own.
  const style: React.CSSProperties = {};
  if (onPath) {
    style.borderColor = pathGrey(pathDepth);
    style.background = pathFill(pathDepth);
  }

  // The plain-English purpose is now the card's headline; the technical name is
  // demoted to a caption beside the badge. What a step is FOR is what someone
  // reading this board actually needs; "ing.verify" is only useful once you
  // already know.
  const head = (
    <div className="card-head">
      <Badge health={health} />
      <span className="card-name">{spec.title}</span>
    </div>
  );

  return (
    <div className={cls} style={style}>
      <Handle type="target" position={Position.Left} style={{ opacity: 0 }} />

      {tier !== 'far' && spec.isNew && <CornerTag letter="n" kind="new" />}
      {tier !== 'far' && spec.isLegacy && <CornerTag letter="o" kind="old" />}

      {tier === 'far' && (
        <div className="card-glyph" style={{ color: mosaicColor }}>
          {glyph(spec.title)}
          {spec.isNew && <span className="glyph-new" />}
          {spec.isLegacy && <span className="glyph-old" />}
        </div>
      )}

      {tier === 'mid' && (
        <>
          {head}
          <div className="card-purpose">{spec.purpose}</div>
        </>
      )}

      {tier === 'near' && (
        <>
          {head}
          <div className="card-purpose">{spec.purpose}</div>
          {spec.caveat && <div className="card-caveat">{spec.caveat}</div>}
          <div className="card-detail">{state?.detail ?? '—'}</div>
        </>
      )}

      <Handle type="source" position={Position.Right} style={{ opacity: 0 }} />
    </div>
  );
}

export const PipelineNode = memo(PipelineNodeInner);
