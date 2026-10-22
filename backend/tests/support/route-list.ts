import type { Express } from 'express';

interface Layer {
  name: string;
  regexp: RegExp;
  route?: { path: string; methods: Record<string, boolean> };
}

/** Express 4 keeps a mount's path only as a regexp; this turns it back into `/content`. */
function mountPath(re: RegExp): string {
  const src = re.source;
  if (src === '^\\/?(?=\\/|$)') return '*';
  return src.replace('^\\', '').replace('\\/?(?=\\/|$)', '').replace(/\\\//g, '/');
}

/** The app's top-level stack, in order, as readable lines: `use /content router`, `GET /health`. */
export function routeList(app: Express): string[] {
  const stack = (app as unknown as { _router: { stack: Layer[] } })._router.stack;
  return stack.map((layer) => (layer.route
    ? `${Object.keys(layer.route.methods).map((m) => m.toUpperCase()).join(',')} ${layer.route.path}`
    : `use ${mountPath(layer.regexp)} ${layer.name}`));
}
