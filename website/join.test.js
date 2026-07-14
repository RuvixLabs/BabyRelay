import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildInviteDestination,
  normalizeInviteCode,
} from './app/lib/invite.js';

test('normalizes and validates six-character invitation codes', () => {
  assert.equal(normalizeInviteCode(' ab12cd '), 'AB12CD');
  assert.equal(normalizeInviteCode('ABC-12'), null);
  assert.equal(normalizeInviteCode('ABC12'), null);
});

test('join fallback preserves the validated invite code for AppRefer', () => {
  const destination = new URL(buildInviteDestination('ab12cd'));
  assert.equal(destination.origin, 'https://apprefer.com');
  assert.equal(destination.pathname, '/api/c/babyrelay-meta');
  assert.equal(destination.searchParams.get('invite_code'), 'AB12CD');
  assert.equal(buildInviteDestination('invalid'), null);
});
