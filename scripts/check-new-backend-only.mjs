#!/usr/bin/env node
// "New backend only" (founder rule, context/rules.md): the new app talks to the backend through
// Backend.Client -> a /v2 door in Backend.PathTemplate -> the new Session token. This fails when code under
// Platform/ (except Bridges.swift), Features/ or DesignSystemV2/:
//   1. mentions RetrospectAPIClient (the old client) outside a comment;
//   2. builds a URLRequest or uses URLSession.shared to reach a server (only Platform/Backend/ may, and
//      Platform/Media/MediaSource.swift for the signed audio link, which is not the backend);
//   3. writes a string literal that looks like a backend path ("/v2/...", "/api/...", "/auth/...",
//      "/public/...") that is not one of Backend.PathTemplate's values (the route lists in
//      Backend/Endpoint.swift and Diagnostics/Diagnostics.swift are where paths are written).
// Usage: node scripts/check-new-backend-only.mjs [appRoot]   (default Retrospect/Retrospect)
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const FOLDERS = ['Platform', 'Features', 'DesignSystemV2'];
// TEMPORARY: AppEnvironment.bindSessionLifecycle(to: RetrospectAPIClient) goes in PR 159 (the session
// drives the stack, no old-client callbacks). Remove the second entry when 159 has merged.
const OLD_CLIENT_OK = new Set(['Platform/Bridges.swift', 'Platform/AppEnvironment.swift']);
const NETWORK_OK = (rel) => rel.startsWith('Platform/Backend/') || rel === 'Platform/Media/MediaSource.swift';
const PATHS_WRITTEN_HERE = new Set(['Platform/Backend/Endpoint.swift', 'Platform/Diagnostics/Diagnostics.swift']);
const PATH_LITERAL = /"(\/(?:v2|api|auth|public)(?:\/[^"\s]*)?)"/g;

function swiftFiles(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...swiftFiles(full));
    else if (name.endsWith('.swift')) out.push(full);
  }
  return out;
}

/** The text with `//` comments removed (string literals containing `//` are kept: URLs). */
export function withoutComments(text) {
  return text
    .split('\n')
    .map((line) => {
      let inString = false;
      for (let i = 0; i < line.length; i++) {
        if (line[i] === '"' && line[i - 1] !== '\\') inString = !inString;
        if (!inString && line[i] === '/' && line[i + 1] === '/') return line.slice(0, i);
      }
      return line;
    })
    .join('\n');
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
    let files = [];
    try {
      files = swiftFiles(dir);
    } catch {
      continue;
    }
    for (const file of files) {
      const rel = relative(appRoot, file).split(sep).join('/');
      const lines = withoutComments(readFileSync(file, 'utf8')).split('\n');
      lines.forEach((line, index) => {
        const where = `${rel}:${index + 1}`;
        if (line.includes('RetrospectAPIClient') && !OLD_CLIENT_OK.has(rel)) {
          problems.push(`${where}: uses RetrospectAPIClient (the old client); only Platform/Bridges.swift may`);
        }
        if (!NETWORK_OK(rel) && (/\bURLRequest\s*\(/.test(line) || line.includes('URLSession.shared'))) {
          problems.push(`${where}: talks to a server outside Backend.Client (URLRequest / URLSession.shared)`);
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
