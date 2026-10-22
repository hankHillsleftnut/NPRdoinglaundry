import { createCipheriv, createDecipheriv, createHash, hkdfSync, randomBytes } from 'node:crypto';

/**
 * Invite codes (BE0.12, contract 00 §4).
 *
 * A code is 13 Crockford base32 characters from 65 random bits; the link is
 * `<base>/i/<code>`, and the code and the link are the same secret. Only
 * `sha256(normalised code)` is stored; while an invite is unused its code is
 * also kept sealed (AES-256-GCM, key from INVITE_CODE_KEY) so "your invites"
 * can show the link again. Never log a code, a link or a hash.
 *
 * Pure: randomness and the key are passed in.
 */
export const CODE_LENGTH = 13;
const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/** 13 characters × 5 bits = 65 bits, read from 9 random bytes (72 bits). */
export function newCode(random: (n: number) => Buffer = randomBytes): string {
  const bytes = random(9);
  let bits = 0n;
  for (const b of bytes) bits = (bits << 8n) | BigInt(b);
  let out = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    out += CROCKFORD[Number(bits & 31n)];
    bits >>= 5n;
  }
  return out;
}

/**
 * What a person typed or a link carried, as the code it names, or null if it
 * can't be one: case-insensitive, dashes and spaces ignored, and Crockford's
 * look-alikes read as digits (O → 0, I and L → 1).
 */
export function normaliseCode(input: string): string | null {
  if (input.length > 64) return null;
  const s = input.toUpperCase().replace(/[\s-]/g, '').replace(/O/g, '0').replace(/[IL]/g, '1');
  if (s.length !== CODE_LENGTH) return null;
  for (const ch of s) if (!CROCKFORD.includes(ch)) return null;
  return s;
}

export function hashCode(normalised: string): string {
  return createHash('sha256').update(normalised, 'utf8').digest('hex');
}

/** `7KQ2-M9XD-4RTA-B`: the code as people read it. */
export function displayCode(code: string): string {
  return code.match(/.{1,4}/g)!.join('-');
}

export function inviteLink(baseUrl: string, code: string): string {
  return `${baseUrl.replace(/\/+$/, '')}/i/${code}`;
}

function sealKey(key: string): Buffer {
  return Buffer.from(hkdfSync('sha256', key, 'retrospect-invite-codes', 'aes-256-gcm', 32));
}

export function sealCode(code: string, key: string, random: (n: number) => Buffer = randomBytes): string {
  const iv = random(12);
  const cipher = createCipheriv('aes-256-gcm', sealKey(key), iv);
  const body = Buffer.concat([cipher.update(code, 'utf8'), cipher.final()]);
  return [iv, cipher.getAuthTag(), body].map((b) => b.toString('base64url')).join('.');
}

export function openCode(sealed: string, key: string): string {
  const [iv, tag, body] = sealed.split('.').map((p) => Buffer.from(p, 'base64url'));
  if (!iv || !tag || !body) throw new Error('openCode: malformed');
  const decipher = createDecipheriv('aes-256-gcm', sealKey(key), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(body), decipher.final()]).toString('utf8');
}

/** n fresh invites: the plain codes (shown once, by whoever made them), their hashes and sealed copies. */
export function mintCodes(n: number, key: string, random: (n: number) => Buffer = randomBytes) {
  const codes = Array.from({ length: n }, () => newCode(random));
  return { codes, hashes: codes.map(hashCode), sealed: codes.map((c) => sealCode(c, key, random)) };
}
