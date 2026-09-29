'use client';

import { memo } from 'react';
import type { RegionBox } from '@/lib/layout';
import { REGION_COLOR } from '@/lib/colors';

function RegionNodeInner({ data }: { data: { box: RegionBox } }) {
  const { box } = data;
  const color = REGION_COLOR[box.id];
  return (
    <div
      className="region-box"
      style={{ width: box.w, height: box.h, borderColor: `${'color-mix(in srgb, ' + color + ' 30%, transparent)'}` }}
    >
      <div className="region-label" style={{ color }}>{box.title}</div>
      <div className="region-blurb">{box.blurb}</div>
    </div>
  );
}

export const RegionNode = memo(RegionNodeInner);
