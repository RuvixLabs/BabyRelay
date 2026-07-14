const codePattern = /^[A-Z0-9]{6}$/;

export function normalizeInviteCode(rawCode) {
  const code = String(rawCode ?? '').trim().toUpperCase();
  return codePattern.test(code) ? code : null;
}

export function buildInviteDestination(code) {
  const normalizedCode = normalizeInviteCode(code);
  if (!normalizedCode) return null;

  const destination = new URL('https://apprefer.com/api/c/babyrelay-meta');
  destination.searchParams.set('invite_code', normalizedCode);
  return destination.toString();
}
