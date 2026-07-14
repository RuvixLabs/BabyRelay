'use client';

import { useEffect } from 'react';
import { buildInviteDestination, normalizeInviteCode } from '../../lib/invite';

const privacyUrl = 'https://appstorecopilot.com/legal/3omln7px/privacy';
const termsUrl = 'https://appstorecopilot.com/legal/3omln7px/terms';

export default function JoinRedirect({ rawCode }) {
  const code = normalizeInviteCode(rawCode);
  const destination = code ? buildInviteDestination(code) : null;

  useEffect(() => {
    if (!destination) return undefined;

    const timer = window.setTimeout(() => {
      window.location.assign(destination);
    }, 900);
    return () => window.clearTimeout(timer);
  }, [destination]);

  return (
    <main className="join-shell">
      <section className="join-copy" aria-labelledby="join-title">
        <div className="brand-mark" aria-hidden="true">
          <span className="brand-moon" />
        </div>
        <p className="eyebrow">BabyRelay invitation</p>
        <h1 id="join-title">
          {destination
            ? 'You’ve been invited into the care circle.'
            : 'This invitation is unavailable.'}
        </h1>
        <p className="lede">
          {destination
            ? 'Opening BabyRelay so you can join the family and pick up where they left off.'
            : 'Ask the family owner to share a new BabyRelay invitation.'}
        </p>
        {destination ? (
          <a className="primary-action" href={destination}>
            Continue to BabyRelay
          </a>
        ) : null}
        <p className="status" role="status" aria-live="polite">
          {destination
            ? `Invitation ${code} is ready.`
            : 'No valid invitation code was found.'}
        </p>
      </section>
      <div className="care-orbit" aria-hidden="true">
        <span className="orbit-child">B</span>
        <span className="orbit-dot orbit-one" />
        <span className="orbit-dot orbit-two" />
        <span className="orbit-dot orbit-three" />
      </div>
      <footer className="legal-links">
        <a href={privacyUrl}>Privacy</a>
        <a href={termsUrl}>Terms</a>
      </footer>
    </main>
  );
}
