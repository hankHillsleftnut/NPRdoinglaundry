import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { scan, withoutComments } from './check-new-backend-only.mjs';

const ENDPOINT = `
extension Backend {
    enum PathTemplate: String, Sendable, CaseIterable {
        case meta = "/v2/meta"
        case authApple = "/v2/auth/apple"
    }

    struct NoBody {}
}
`;

function app(files) {
  const root = mkdtempSync(join(tmpdir(), 'nbo-'));
  for (const folder of ['Platform', 'Features', 'DesignSystemV2']) mkdirSync(join(root, folder), { recursive: true });
  const all = { 'Platform/Backend/Endpoint.swift': ENDPOINT, ...files };
  for (const [path, text] of Object.entries(all)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), text);
  }
  return root;
}

test('a clean tree has no problems', () => {
  const root = app({
    'Platform/Backend/Client.swift': 'let r = URLRequest(url: u)\n',
    'Platform/Bridges.swift': 'let c = RetrospectAPIClient.shared\n',
    'Platform/Media/MediaSource.swift': 'let (f, r) = try await URLSession.shared.download(from: url)\n',
    'Features/Journal/Page.swift': '// RetrospectAPIClient is mentioned in a comment only\nlet x = 1\n',
  });
  assert.deepEqual(scan(root), []);
});

test('the old client outside Bridges.swift fails, in Platform, Features and the design system', () => {
  for (const path of ['Platform/Session/X.swift', 'Features/Journal/X.swift', 'DesignSystemV2/Components/X.swift']) {
    const problems = scan(app({ [path]: 'let c = RetrospectAPIClient.shared\n' }));
    assert.equal(problems.length, 1, path);
    assert.match(problems[0], /RetrospectAPIClient/);
  }
});

test('a raw URLRequest or URLSession.shared outside Backend fails', () => {
  assert.equal(scan(app({ 'Features/A.swift': 'let r = URLRequest(url: u)\n' })).length, 1);
  assert.equal(scan(app({ 'Platform/Store/A.swift': 'try await URLSession.shared.data(from: u)\n' })).length, 1);
});

test('a path that is not a PathTemplate fails, and so does writing a real one out', () => {
  const old = scan(app({ 'Platform/Session/A.swift': 'let p = "/auth/signin"\n' }));
  assert.match(old[0], /not a Backend.PathTemplate/);
  assert.equal(scan(app({ 'Features/A.swift': 'let p = "/api/entries"\n' })).length, 1);
  assert.match(scan(app({ 'Features/A.swift': 'let p = "/v2/meta"\n' }))[0], /written out/);
});

test('the route lists may write paths, and a path in a comment is fine', () => {
  const root = app({
    'Platform/Diagnostics/Diagnostics.swift': 'case authGoogle = "/v2/auth/google"\n',
    'Features/A.swift': '// the old door was "/auth/signin"\nlet x = 1\n',
  });
  assert.deepEqual(scan(root), []);
});

test('comments are removed but a URL in a string is kept', () => {
  assert.equal(withoutComments('let a = 1 // note'), 'let a = 1 ');
  assert.equal(withoutComments('let u = "https://x.test/a"'), 'let u = "https://x.test/a"');
});

test('the real tree is clean', () => {
  assert.deepEqual(scan('Retrospect/Retrospect'), []);
});

test('a configured, injected or split-line URLSession outside Backend fails, not only URLSession.shared', () => {
  assert.equal(scan(app({ 'Platform/Store/A.swift': 'let s = URLSession(configuration: .default)\n' })).length, 1);
  assert.equal(scan(app({ 'Features/A.swift': 'func load(using session: URLSession) {}\n' })).length, 1);
  assert.equal(scan(app({ 'Platform/Store/A.swift': 'let s = URLSession\n    .shared\n' })).length, 1);
});

test('a missing folder fails loudly instead of reporting a partial scan clean', () => {
  const root = app({ 'Features/A.swift': 'let x = 1\n', 'Platform/Session/S.swift': 'let y = 1\n', 'DesignSystemV2/B.swift': 'let z = 1\n' });
  assert.deepEqual(scan(root), []);
  rmSync(join(root, 'Features'), { recursive: true });
  assert.throws(() => scan(root), /missing/);
});

test('a dangling symlink fails loudly instead of being skipped', () => {
  const root = app({ 'Features/A.swift': 'let x = 1\n', 'DesignSystemV2/B.swift': 'let z = 1\n' });
  symlinkSync(join(root, 'nowhere.swift'), join(root, 'Platform/Dangling.swift'));
  assert.throws(() => scan(root));
});

test('there is no exemption for AppEnvironment: the old client there fails', () => {
  assert.equal(scan(app({ 'Platform/AppEnvironment.swift': 'func bind(to client: RetrospectAPIClient) {}\n' })).length, 1);
});
