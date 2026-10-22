import { test } from 'node:test';
import assert from 'node:assert/strict';
import { classifyTokenError, authFailureFor, failureBody, tokenErrorSummary } from '../src/services/auth-errors.js';
import { errors } from 'jose';

/**
 * Every sign-in failure is said in plain words. The 19 October case: an old
 * copy of the app signed in under a different app ID, and the person saw
 * "Server error: HTTP 500".
 */

test('a token for a different app ID means the app is out of date', () => {
  const f = classifyTokenError({ code: 'ERR_JWT_CLAIM_VALIDATION_FAILED', claim: 'aud' });
  assert.equal(f.code, 'app_out_of_date');
  assert.equal(f.status, 401);
  assert.match(f.message, /install the latest version/);
});

test('an expired token asks them to try again', () => {
  assert.equal(classifyTokenError({ code: 'ERR_JWT_EXPIRED' }).code, 'sign_in_expired');
});

test('a bad signature is "could not confirm", naming the provider', () => {
  const f = classifyTokenError({ code: 'ERR_JWS_SIGNATURE_VERIFICATION_FAILED' }, 'Google');
  assert.equal(f.code, 'sign_in_not_confirmed');
  assert.match(f.message, /Google/);
});

test('a network failure is the provider being unavailable, not bad credentials', () => {
  const f = classifyTokenError(new TypeError('fetch failed'));
  assert.equal(f.code, 'provider_unavailable');
  assert.equal(f.status, 503);
});

test('a credential already on another account says so', () => {
  const err = Object.assign(new Error('linked elsewhere'), { name: 'IdentityLinkConflictError' });
  assert.equal(classifyTokenError(err).code, 'account_in_use');
});

test('anything unknown is our fault, said plainly, never raw output', () => {
  const f = classifyTokenError(new Error('relation "users" does not exist'));
  assert.equal(f.code, 'server_error');
  assert.doesNotMatch(f.message, /relation|HTTP|500|\{/);
});

test('the body keeps a readable error for older app builds, plus a code', () => {
  assert.deepEqual(Object.keys(failureBody(authFailureFor('session_ended'))).sort(), ['code', 'error', 'success']);
});

test('no message contains an em dash or raw JSON', () => {
  for (const code of ['app_out_of_date', 'sign_in_expired', 'sign_in_not_confirmed', 'provider_unavailable', 'session_ended', 'account_in_use', 'bad_request', 'server_error'] as const) {
    const m = authFailureFor(code).message;
    assert.equal(m.includes('—'), false, code);
    assert.equal(m.includes('{'), false, code);
  }
});

test('token diagnostics omit the jose payload and arbitrary error details', () => {
  const error = new errors.JWTClaimValidationFailed('unexpected audience', {
    sub: 'private-subject', email: 'private@example.com',
  }, 'aud', 'check_failed');
  assert.deepEqual(tokenErrorSummary(error), {
    code: 'ERR_JWT_CLAIM_VALIDATION_FAILED', claim: 'aud', reason: 'check_failed',
  });
  assert.deepEqual(tokenErrorSummary({ code: { payload: 'private' }, claim: ['private'], reason: new Error('private') }), {});
  for (const value of [null, undefined, 'private', new Error('private')]) {
    assert.deepEqual(tokenErrorSummary(value), {});
  }
});
