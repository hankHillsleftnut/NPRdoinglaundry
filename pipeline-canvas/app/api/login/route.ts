import { NextResponse } from 'next/server';
import { checkPassword, issueToken, cookieOptions, COOKIE_NAME } from '@/lib/auth';

export async function POST(req: Request) {
  let password = '';
  try {
    const body = await req.json();
    password = typeof body?.password === 'string' ? body.password : '';
  } catch {
    return NextResponse.json({ error: 'bad request' }, { status: 400 });
  }

  if (!checkPassword(password)) {
    return NextResponse.json({ error: 'incorrect password' }, { status: 401 });
  }

  const res = NextResponse.json({ ok: true });
  res.cookies.set(COOKIE_NAME, issueToken(), cookieOptions);
  return res;
}
