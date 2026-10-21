import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { COOKIE_NAME, verifyToken } from '@/lib/auth';
import { Canvas } from '@/components/Canvas';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const jar = await cookies();
  if (!verifyToken(jar.get(COOKIE_NAME)?.value)) redirect('/login');
  return <Canvas />;
}
