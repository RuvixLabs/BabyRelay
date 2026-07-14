const association = {
  applinks: {
    details: [
      {
        appIDs: ['S399W94VV8.com.ruvixlabs.babyrelay'],
        components: [{ '/': '/join/*', comment: 'Caregiver invitation links' }],
      },
    ],
  },
};

export function GET() {
  return Response.json(association, {
    headers: {
      'Cache-Control': 'public, max-age=300, s-maxage=3600',
    },
  });
}
