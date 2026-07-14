import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('./', import.meta.url);

test('Apple association file targets only caregiver join routes', async () => {
  const source = await readFile(
    new URL('.well-known/apple-app-site-association', root),
    'utf8',
  );
  const association = JSON.parse(source);
  assert.deepEqual(association.applinks.details[0].appIDs, [
    'S399W94VV8.com.ruvixlabs.babyrelay',
  ]);
  assert.equal(association.applinks.details[0].components[0]['/'], '/join/*');
});

test('join fallback preserves the validated invite code for AppRefer', async () => {
  const source = await readFile(new URL('join.js', root), 'utf8');
  assert.match(source, /\^\[A-Z0-9\]\{6\}\$/);
  assert.match(source, /apprefer\.com\/api\/c\/babyrelay-meta/);
  assert.match(source, /searchParams\.set\('invite_code', code\)/);
});
