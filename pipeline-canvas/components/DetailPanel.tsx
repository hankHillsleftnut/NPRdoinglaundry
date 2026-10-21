'use client';

import type { NodeSpec, NodeState, SourceMeta } from '@/lib/types';
import { HEALTH_COLOR, HEALTH_LABEL, HEALTH_BLURB } from '@/lib/colors';
import { Badge } from './Badge';
import { ago } from '@/lib/health';

export function DetailPanel({
  spec,
  state,
  sourceMeta,
  onClose,
}: {
  spec: NodeSpec;
  state: NodeState | undefined;
  sourceMeta: SourceMeta | undefined;
  onClose: () => void;
}) {
  const health = state?.health ?? 'unknown';
  const color = HEALTH_COLOR[health];

  return (
    <aside className="drawer">
      <button className="close" onClick={onClose} aria-label="Close">×</button>
      <h2>{spec.title}</h2>

      <div className="status-line">
        <Badge health={health} />
        <strong style={{ color }}>{HEALTH_LABEL[health]}</strong>
      </div>

      <section>
        <h3>What this is for</h3>
        <p>{spec.purpose}</p>
      </section>

      <section>
        <h3>What this colour means</h3>
        <p>{HEALTH_BLURB[health]}</p>
      </section>

      {spec.caveat && (
        <section>
          <h3>Worth knowing</h3>
          <p className="warn">{spec.caveat}</p>
        </section>
      )}

      {spec.probe.kind === 'notInstrumented' ? (
        <>
          <section>
            <h3>Why it is not recorded</h3>
            <p>{spec.probe.reason}</p>
          </section>
          <section>
            <h3>What would light it up</h3>
            <p>{spec.probe.wouldNeed}</p>
          </section>
        </>
      ) : (
        <section>
          <h3>Measurements</h3>
          <div className="kv"><span>rows</span><span>{state?.total ?? 0}</span></div>
          <div className="kv"><span>failed</span><span>{state?.failed ?? 0}</span></div>
          <div className="kv"><span>last activity</span><span>{ago(state?.lastAt ?? null)}</span></div>
          <div className="kv"><span>table</span><span>{spec.probe.source}</span></div>
          {spec.probe.bucket && (
            <div className="kv">
              <span>bucket</span>
              <span>{Array.isArray(spec.probe.bucket) ? spec.probe.bucket.join(', ') : spec.probe.bucket}</span>
            </div>
          )}
          {sourceMeta?.truncated && (
            <p className="warn" style={{ marginTop: 10 }}>
              Row cap reached. These counts are a floor, not a total.
            </p>
          )}
          {sourceMeta?.error && (
            <p className="warn" style={{ marginTop: 10 }}>Read failed: {sourceMeta.error}</p>
          )}
        </section>
      )}

      {state?.lastLabel && (
        <section>
          <h3>Most recent message</h3>
          <code>{state.lastLabel}</code>
        </section>
      )}

      {spec.source && (
        <section>
          <h3>In the code</h3>
          <code>{spec.source}</code>
        </section>
      )}
    </aside>
  );
}
