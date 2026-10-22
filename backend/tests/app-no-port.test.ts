import assert from 'node:assert/strict';
import net from 'node:net';
import test from 'node:test';

// No static import of src/ in this file: the spy must be installed before the
// app's modules load, or a listen at import time would go unseen.

// BE0.2: tests can build the app without it binding a port or reaching a service.
test('importing the app opens no port', async () => {
  const original = net.Server.prototype.listen;
  let listened = 0;
  net.Server.prototype.listen = function (this: net.Server, ...args: unknown[]) {
    listened++;
    return (original as (...a: unknown[]) => net.Server).apply(this, args);
  } as typeof original;
  try {
    const { createApp } = await import('../src/app.js');
    createApp({ agent: {} as never, now: () => 0, users: async () => null, diagnostics: {} as never });
    assert.equal(listened, 0);
  } finally {
    net.Server.prototype.listen = original;
  }
});
