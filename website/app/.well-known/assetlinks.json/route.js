const fingerprintPattern = /^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$/;

export function GET() {
  const fingerprints = (
    process.env.ANDROID_SHA256_CERT_FINGERPRINTS ?? ''
  )
    .split(',')
    .map((value) => value.trim().toUpperCase())
    .filter((value) => fingerprintPattern.test(value));

  if (fingerprints.length === 0) {
    return Response.json(
      { error: 'Android app-link verification is not configured yet.' },
      { status: 503 },
    );
  }

  return Response.json(
    [
      {
        relation: ['delegate_permission/common.handle_all_urls'],
        target: {
          namespace: 'android_app',
          package_name: 'com.ruvixlabs.babyrelay',
          sha256_cert_fingerprints: fingerprints,
        },
      },
    ],
    {
      headers: {
        'Cache-Control': 'public, max-age=300, s-maxage=3600',
      },
    },
  );
}
