import { doorSuite } from './support/door-suite.js';

// BE0.2 acceptance: /v2/ping passes the door suite on the real app.
doorSuite({
  method: 'GET',
  path: '/v2/ping',
  bucket: 'read',
  invalid: { query: 'userId=22222222-2222-4222-8222-222222222222' },
  expect: (userId) => ({ userId }),
});
