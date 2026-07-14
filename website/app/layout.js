import './styles.css';

export const metadata = {
  title: 'BabyRelay — shared baby care',
  description:
    'BabyRelay keeps sleep, feeds, handoffs, and care notes in sync for every caregiver.',
};

export const viewport = {
  themeColor: '#101c38',
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
