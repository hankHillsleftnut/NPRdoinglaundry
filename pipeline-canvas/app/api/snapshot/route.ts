import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { buildSnapshot } from '@/lib/rollup';
import { resolveAll } from '@/lib/health';
import { ALL_NODES } from '@/lib/nodes';
import { COOKIE_NAME, verifyToken } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  const jar = await cookies();
  if (!verifyToken(jar.get(COOKIE_NAME)?.value)) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  }

  const url = new URL(req.url);
  const windowHours = Number(url.searchParams.get('window') ?? 24) || 24;

  try {
    const snap = await buildSnapshot(windowHours);
    const states = resolveAll(ALL_NODES, snap);
    return NextResponse.json({
      takenAt: snap.takenAt,
      windowHours,
      states,
      sources: snap.sources,
    });
  } catch (e) {
    // Surfaced to the UI as `unknown` on every node -- never as a healthy board.
    return NextResponse.json(
      { error: e instanceof Error ? e.message : 'snapshot failed' },
      { status: 500 },
    );
  }
}
