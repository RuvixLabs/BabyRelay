import JoinRedirect from './redirect';

export const metadata = {
  title: 'Join a family in BabyRelay',
  robots: { index: false, follow: false },
};

export default async function JoinPage({ params }) {
  const { code } = await params;
  return <JoinRedirect rawCode={code} />;
}
