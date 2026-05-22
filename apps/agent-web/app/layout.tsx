import './globals.css';
import type { ReactNode } from 'react';
import PWA from '../components/PWA';

export const metadata = {
  title: 'ParcelPal Agent',
  description: 'Pickup and delivery for ParcelPal agents',
  manifest: '/manifest.webmanifest',
  themeColor: '#0E5BFF',
  appleWebApp: { capable: true, statusBarStyle: 'default', title: 'PP Agent' },
};

export const viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: '#0E5BFF',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link rel="apple-touch-icon" href="/icons/icon-192.png" />
      </head>
      <body className="min-h-screen">
        {children}
        <PWA />
      </body>
    </html>
  );
}
