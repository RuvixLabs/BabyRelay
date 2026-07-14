(() => {
  const codePattern = /^[A-Z0-9]{6}$/;
  const rawCode = window.location.pathname.split('/').filter(Boolean).at(-1);
  const code = (rawCode ?? '').trim().toUpperCase();
  const status = document.querySelector('#join-status');
  const detail = document.querySelector('#join-detail');
  const continueLink = document.querySelector('#continue-link');

  if (!codePattern.test(code)) {
    document.title = 'Invitation unavailable — BabyRelay';
    detail.textContent =
      'This invitation link is incomplete. Ask the family owner to share a new BabyRelay invitation.';
    status.textContent = 'No valid invitation code was found.';
    return;
  }

  const destination = new URL('https://apprefer.com/api/c/babyrelay-meta');
  destination.searchParams.set('invite_code', code);

  continueLink.href = destination.toString();
  continueLink.hidden = false;
  status.textContent = `Invitation ${code} is ready.`;

  window.setTimeout(() => {
    window.location.assign(destination.toString());
  }, 900);
})();
