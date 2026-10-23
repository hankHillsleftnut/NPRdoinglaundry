/**
 * A legacy episode's script as spoken lines (BE3.x.ep; contract 03 §3 "Legacy
 * episodes"): split on blank lines into paragraphs, then each paragraph into
 * sentences. Pure; never logs.
 *
 * When unsure, keep words together: a missed split only makes one line
 * longer, a wrong split puts half a sentence on screen. So a full stop after
 * a known abbreviation ("dr.", "mrs."), a dotted short form ("e.g.", "i.e.",
 * "a.m.", "u.s.") or a single initial ("j.") never ends a sentence, and a
 * stop inside a number ("3.5") never does either (no space follows it).
 * Case is not used: the writer's scripts can be all lowercase.
 */

/** Short words that end in a full stop without ending the sentence. */
const ABBREVIATIONS: ReadonlySet<string> = new Set([
  'mr', 'mrs', 'ms', 'mx', 'dr', 'prof', 'st', 'jr', 'sr', 'vs', 'mt', 'ft', 'approx', 'cf', 'etc',
]);

/** A sentence end: terminators, then any closing quotes or brackets, then a space. */
const END = /[.!?…]+["'”’)\]]*(?=\s)/g;

function keepsGoing(paragraph: string, stopAt: number): boolean {
  if (paragraph[stopAt] !== '.') return false;
  // The word the full stop is attached to (from the last space), without opening punctuation.
  const start = paragraph.lastIndexOf(' ', stopAt - 1) + 1;
  const word = paragraph.slice(start, stopAt).replace(/^["'“‘(\[]+/, '').toLowerCase();
  if (ABBREVIATIONS.has(word)) return true;
  if (/^\p{L}$/u.test(word)) return true; // an initial: "j. smith"
  return /^(\p{L}\.)+\p{L}$/u.test(word); // "e.g", "i.e", "a.m", "u.s"
}

/** One paragraph (whitespace already collapsed) as sentences. */
export function sentences(paragraph: string): string[] {
  const out: string[] = [];
  let from = 0;
  for (const m of paragraph.matchAll(END)) {
    const stopAt = m.index;
    // A run like "..." or "?!" decides on its first character; only a lone "." can be an abbreviation.
    if (m[0].startsWith('.') && !m[0].startsWith('..') && keepsGoing(paragraph, stopAt)) continue;
    const end = stopAt + m[0].length;
    const s = paragraph.slice(from, end).trim();
    if (s) out.push(s);
    from = end;
  }
  const rest = paragraph.slice(from).trim();
  if (rest) out.push(rest);
  return out;
}

/** The script as spoken lines, in order: paragraphs, then sentences. Empty or blank → []. */
export function scriptLines(script: string): string[] {
  return script
    .replace(/\r\n?/g, '\n')
    .split(/\n[ \t]*\n/)
    .map((p) => p.replace(/\s+/g, ' ').trim())
    .filter(Boolean)
    .flatMap(sentences);
}
