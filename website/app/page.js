const privacyUrl = 'https://appstorecopilot.com/legal/3omln7px/privacy';
const termsUrl = 'https://appstorecopilot.com/legal/3omln7px/terms';

export default function HomePage() {
  return (
    <main className="home-shell">
      <section className="home-copy" aria-labelledby="home-title">
        <p className="eyebrow">BabyRelay</p>
        <h1 id="home-title">
          Every caregiver,
          <br />
          in the rhythm.
        </h1>
        <p className="lede">
          Sleep, feeds, handoffs, and the small details—shared without the
          midnight catch-up.
        </p>
        <a className="text-link" href="https://ruvixlabs.com">
          From Ruvix Labs
        </a>
      </section>
      <div className="night-sky" aria-hidden="true">
        <div className="moon" />
        <span className="star star-one" />
        <span className="star star-two" />
        <span className="star star-three" />
        <div className="horizon" />
      </div>
      <footer className="legal-links">
        <a href={privacyUrl}>Privacy</a>
        <a href={termsUrl}>Terms</a>
      </footer>
    </main>
  );
}
