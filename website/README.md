# BabyRelay web fallback

This is a small Next.js application for Firebase App Hosting. It owns the
marketing root, caregiver invitation fallback, and the Universal/App Link
association endpoints.

The production domain is intentionally not encoded here. Choose and register
the Ruvix-owned domain before attaching it to the App Hosting backend and
before changing the mobile associated-domain declarations.

## Local verification

```sh
npm install
npm test
npm run build
npm start
```

Set `ANDROID_SHA256_CERT_FINGERPRINTS` to a comma-separated list of Play App
Signing SHA-256 fingerprints. Until configured, `/.well-known/assetlinks.json`
fails closed with HTTP 503.

Installed iOS/Android apps intercept `/join/<code>` through Universal Links /
App Links. Browser visitors are validated and forwarded to the `babyrelay-meta`
AppRefer capture page with the code preserved for deferred-install attribution.
The association routes must return directly from the final production host
without an apex-to-`www` redirect.
