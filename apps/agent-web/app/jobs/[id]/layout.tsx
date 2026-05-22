'use client';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { getToken } from '../../../lib/api';

export default function JobLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  useEffect(() => {
    if (!getToken()) router.replace('/login');
  }, [router]);
  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b border-slate-200 bg-white sticky top-0 z-10">
        <div className="max-w-2xl mx-auto px-4 py-3 font-bold">🛵 ParcelPal Agent</div>
      </header>
      <main className="flex-1 max-w-2xl mx-auto w-full px-4 py-4">{children}</main>
    </div>
  );
}
