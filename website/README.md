# BabyRelay web fallback

This is a small Next.js application for Firebase App Hosting. It owns the
marketing root, caregiver invitation fallback, and the Universal/App Link
association endpoints.

The canonical production domain is `ourbabyrelay.com`. It must be registered
to Ruvix Labs and attached to the `babyrelay-web` Firebase App Hosting backend
before a store build containing the mobile associated-domain declarations is
released.

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
