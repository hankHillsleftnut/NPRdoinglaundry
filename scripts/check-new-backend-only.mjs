#!/usr/bin/env node
// "New backend only" (founder rule, context/rules.md): the new app talks to the backend through
// Backend.Client -> a /v2 door in Backend.PathTemplate -> the new Session token. This fails when code under
// Platform/ (except Bridges.swift), Features/ or DesignSystemV2/:
//   1. mentions RetrospectAPIClient (the old client) outside a comment;
//   2. builds a URLRequest or uses any URLSession (shared, configured or injected) to reach a server (only Platform/Backend/ may, and
//      Platform/Media/MediaSource.swift for the signed audio link, which is not the backend);
//   3. writes a string literal that looks like a backend path ("/v2/...", "/api/...", "/auth/...",
//      "/public/...") that is not one of Backend.PathTemplate's values (the route lists in
//      Backend/Endpoint.swift and Diagnostics/Diagnostics.swift are where paths are written).
// Usage: node scripts/check-new-backend-only.mjs [appRoot]   (default Retrospect/Retrospect)
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const FOLDERS = ['Platform', 'Features', 'DesignSystemV2'];
const OLD_CLIENT_OK = new Set(['Platform/Bridges.swift']);
const NETWORK_OK = (rel) => rel.startsWith('Platform/Backend/') || rel === 'Platform/Media/MediaSource.swift';
const PATHS_WRITTEN_HERE = new Set(['Platform/Backend/Endpoint.swift', 'Platform/Diagnostics/Diagnostics.swift']);
// A path on its own ("/v2/x") or at the end of a written-out address ("https://host/auth/signin").
const PATH_LITERAL = /"(?:https?:\/\/[^"\/\s]+)?(\/(?:v2|api|auth|public)(?:\/[^"\s]*)?)"/g;

/** Every .swift file under dir. A guard must fail loudly: a missing folder, an unreadable entry or a dangling
 * symlink throws (nothing is skipped), so a partial scan can never report "clean". */
function swiftFiles(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...swiftFiles(full));
    else if (name.endsWith('.swift')) out.push(full);
  }
  return out;
}

// The text with line comments and block comments removed (string literals containing a double slash are kept:
// URLs). Block comments keep their line breaks so line numbers stay right.
export function withoutComments(text) {
  const out = [];
  let inBlock = false;
  for (const line of text.split('\n')) {
    let result = '';
    let inString = false;
    for (let i = 0; i < line.length; i++) {
      if (inBlock) {
        if (line[i] === '*' && line[i + 1] === '/') {
          inBlock = false;
          i++;
        }
        continue;
      }
      if (inString) {
        if (line[i] === '\\') {
          result += line[i] + (line[i + 1] ?? '');
          i++;
          continue;
        }
        if (line[i] === '"') inString = false;
      } else if (line[i] === '"') {
        inString = true;
      } else if (line[i] === '/' && line[i + 1] === '/') {
        break;
      } else if (line[i] === '/' && line[i + 1] === '*') {
        inBlock = true;
        i++;
        continue;
      }
      result += line[i];
    }
    out.push(result);
  }
  return out.join('\n');
}

/** A line with the inside of its string literals blanked (the quotes stay): a message that merely says "URLSession failed" is not a use. */
export function maskStrings(line) {
  let out = '';
  let inString = false;
  for (let i = 0; i < line.length; i++) {
    if (inString && line[i] === '\\') {
      out += '  ';
      i++;
    } else if (line[i] === '"') {
      inString = !inString;
      out += '"';
    } else {
      out += inString ? ' ' : line[i];
    }
  }
  return out;
}

export function pathTemplates(appRoot) {
  const text = readFileSync(join(appRoot, 'Platform/Backend/Endpoint.swift'), 'utf8');
  const start = text.indexOf('enum PathTemplate');
  const block = text.slice(start, text.indexOf('\n    }\n', start));
  return new Set([...block.matchAll(/case \w+ = "([^"]+)"/g)].map((m) => m[1]));
}

export function scan(appRoot) {
  const templates = pathTemplates(appRoot);
  const problems = [];
  for (const folder of FOLDERS) {
    const dir = join(appRoot, folder);
    if (!existsSync(dir) || !statSync(dir).isDirectory()) throw new Error(`New backend only: ${dir} is missing, so the scan would be partial`);
    const files = swiftFiles(dir);
    for (const file of files) {
      const rel = relative(appRoot, file).split(sep).join('/');
      const lines = withoutComments(readFileSync(file, 'utf8')).split('\n');
      lines.forEach((line, index) => {
        const where = `${rel}:${index + 1}`;
        const code = maskStrings(line);
        if (code.includes('RetrospectAPIClient') && !OLD_CLIENT_OK.has(rel)) {
          problems.push(`${where}: uses RetrospectAPIClient (the old client); only Platform/Bridges.swift may`);
        }
        if (!NETWORK_OK(rel) && /\b(URLRequest|URLSession)\b/.test(code)) {
          problems.push(`${where}: talks to a server outside Backend.Client (URLRequest / URLSession)`);
        }
        if (!PATHS_WRITTEN_HERE.has(rel)) {
          for (const match of line.matchAll(PATH_LITERAL)) {
            if (!templates.has(match[1])) problems.push(`${where}: backend path ${match[1]} is not a Backend.PathTemplate`);
            else problems.push(`${where}: backend path ${match[1]} written out; use the Endpoint`);
          }
        }
      });
    }
  }
  return problems;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const root = process.argv[2] ?? 'Retrospect/Retrospect';
  const problems = scan(root);
  if (problems.length) {
    console.error(`New backend only: ${problems.length} problem(s)\n` + problems.map((p) => `  ${p}`).join('\n'));
    process.exit(1);
  }
  console.log('New backend only: clean');
}
