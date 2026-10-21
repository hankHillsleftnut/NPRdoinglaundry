// A tiny MCP client for Paper's stdio relay (~/.paper/bin/paper mcp), so sync scripts can read and
// write the file themselves instead of a person (or an agent) pasting node ids into tool calls.
import { spawn } from 'node:child_process';
import { homedir } from 'node:os';

export async function connect() {
  const proc = spawn(`${homedir()}/.paper/bin/paper`, ['mcp'], { stdio: ['pipe', 'pipe', 'inherit'] });
  let buf = '', id = 0;
  const waiting = new Map();
  proc.stdout.on('data', (d) => {
    buf += d;
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i); buf = buf.slice(i + 1);
      if (!line.trim()) continue;
      const msg = JSON.parse(line);
      if (msg.id !== undefined && waiting.has(msg.id)) { waiting.get(msg.id)(msg); waiting.delete(msg.id); }
    }
  });
  const rpc = (method, params) => new Promise((res, rej) => {
    const n = ++id;
    waiting.set(n, (m) => (m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result)));
    proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: n, method, params }) + '\n');
  });
  await rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'retrospect-sync', version: '1' } });
  proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
  // returns the tool's text parts: [header, body] → body parsed as JSON when it is JSON
  const call = async (name, args) => {
    const r = await rpc('tools/call', { name, arguments: args });
    const texts = (r.content ?? []).filter((c) => c.type === 'text').map((c) => c.text);
    if (r.isError) throw new Error(`${name}: ${texts.join(' ')}`);
    const body = texts[texts.length - 1] ?? '';
    try { return JSON.parse(body); } catch { return body; }
  };
  return { call, rpc, close: () => proc.kill() };
}
