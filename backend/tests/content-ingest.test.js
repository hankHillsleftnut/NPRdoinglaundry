jest.mock('../dist/utils/supabase.js', () => ({
  supabaseAdmin: { rpc: jest.fn(), from: jest.fn() },
  Tables: { RAW_CONTENT: 'raw_content', DATA_SOURCES: 'data_sources' },
}));
jest.mock('../dist/services/agent-client.js', () => ({ runAgentIngest: jest.fn() }));

const { supabaseAdmin } = require('../dist/utils/supabase.js');
const { runAgentIngest } = require('../dist/services/agent-client.js');
const { contentRouter } = require('../dist/routes/content.js');

const userId = '00000000-0000-4000-8000-000000000001';
const rawContentId = '00000000-0000-4000-8000-000000000002';
const clientUuid = '00000000-0000-4000-8000-000000000003';
let background;
let claimResult;
let staleRows;

function response() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}

function post(path, res = response()) {
  const handler = contentRouter.stack.find((layer) => layer.route?.path === path && layer.route.methods.post)
    .route.stack[0].handle;
  return {
    res,
    done: handler({ user: { id: userId }, params: { id: rawContentId },
      body: { contentType: 'text_entry', content: 'Captured note', clientUuid } }, res),
  };
}

beforeEach(() => {
  jest.resetAllMocks();
  background = [];
  staleRows = [];
  claimResult = { data: true, error: null };
  jest.spyOn(global, 'setImmediate').mockImplementation((callback) => { background.push(callback); });
  jest.spyOn(console, 'error').mockImplementation(() => {});
  jest.spyOn(console, 'warn').mockImplementation(() => {});
  supabaseAdmin.rpc.mockImplementation((name) => {
    if (name === 'upsert_raw_content') {
      return { single: async () => ({ data: { raw_content_id: rawContentId, was_inserted: false }, error: null }) };
    }
    if (name === 'stale_raw_content_ingests') return Promise.resolve({ data: staleRows, error: null });
    return Promise.resolve(claimResult);
  });
  supabaseAdmin.from.mockImplementation(() => {
    const query = {};
    for (const name of ['select', 'eq', 'update']) query[name] = jest.fn(() => query);
    query.single = async () => ({ data: { id: rawContentId }, error: null });
    return query;
  });
  runAgentIngest.mockResolvedValue({ insights_created: 0, observations_created: 0, goal_candidates_created: 0 });
});

afterEach(() => jest.restoreAllMocks());

test('upload waits for the claim before acknowledging and ingests only once', async () => {
  let resolveClaim;
  const pendingClaim = new Promise((resolve) => { resolveClaim = resolve; });
  const defaultRpc = supabaseAdmin.rpc.getMockImplementation();
  supabaseAdmin.rpc.mockImplementation((name, args) => name === 'claim_raw_content_ingest'
    ? pendingClaim : defaultRpc(name, args));
  const { res, done } = post('/');
  // Wait until the handler reaches the pending RPC, without resolving it.
  for (let turn = 0; turn < 10; turn++) await Promise.resolve();
  expect(supabaseAdmin.rpc).toHaveBeenCalledWith('claim_raw_content_ingest', expect.any(Object));
  expect(res.json).not.toHaveBeenCalled();
  expect(background).toHaveLength(0);
  resolveClaim({ data: true, error: null });
  await done;
  expect(res.status).toHaveBeenCalledWith(202);
  expect(runAgentIngest).not.toHaveBeenCalled();
  await background[0]();
  expect(runAgentIngest).toHaveBeenCalledTimes(1);
  expect(supabaseAdmin.rpc.mock.calls.filter(([name]) => name === 'claim_raw_content_ingest')).toHaveLength(1);
});

test.each(['PGRST202', '42501', '08006'])('claim error %s is retryable on upload and reprocess', async (code) => {
  claimResult = { data: null, error: { code, message: 'RPC unavailable' } };
  for (const path of ['/', '/:id/reprocess']) {
    const { res, done } = post(path);
    await done;
    expect(res.status).toHaveBeenCalledWith(503);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: false }));
  }
  expect(background).toHaveLength(0);
  expect(runAgentIngest).not.toHaveBeenCalled();
});

test('a denied claim acknowledges upload without ingesting and returns 409 on reprocess', async () => {
  claimResult = { data: false, error: null };
  const upload = post('/');
  await upload.done;
  expect(upload.res.status).toHaveBeenCalledWith(202);
  await background[0]();
  const reprocess = post('/:id/reprocess');
  await reprocess.done;
  expect(reprocess.res.status).toHaveBeenCalledWith(409);
  expect(runAgentIngest).not.toHaveBeenCalled();
});

test('only the missing-function code enables legacy ingestion on both routes', async () => {
  claimResult = { data: null, error: { code: '42883', message: 'function does not exist' } };
  const upload = post('/');
  await upload.done;
  expect(upload.res.status).toHaveBeenCalledWith(202);
  await background[0]();
  const reprocess = post('/:id/reprocess');
  await reprocess.done;
  expect(reprocess.res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  expect(runAgentIngest).toHaveBeenCalledTimes(2);
});

test('recovery claims stale rows and catches a recovery RPC error after acknowledgement', async () => {
  claimResult = { data: false, error: null };
  staleRows = [{ raw_content_id: 'stale-pending-row' }];
  const upload = post('/');
  await upload.done;
  claimResult = { data: true, error: null };
  await background[0]();
  expect(runAgentIngest).toHaveBeenCalledWith(expect.objectContaining({ rawContentIds: ['stale-pending-row'] }));

  claimResult = { data: null, error: { code: '08006', message: 'connection lost' } };
  await expect(background[0]()).resolves.toBeUndefined();
  expect(runAgentIngest).toHaveBeenCalledTimes(1);
  expect(upload.res.status).toHaveBeenCalledTimes(1);
});
