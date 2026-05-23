'use client';
import { useEffect } from 'react';
import Link from 'next/link';
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
        <div className="max-w-2xl mx-auto px-4 py-3 flex items-center gap-3">
          <Link href="/dashboard" className="flex items-center hover:opacity-90 transition-opacity">
            <img
              src="/logo.png"
              alt="Parsalo Agent"
              className="h-10 w-10 object-contain"
              style={{ height: '40px', width: '40px', minWidth: '40px', maxWidth: '40px' }}
            />
          </Link>
          <span className="font-bold text-slate-900">Parsalo Agent</span>
        </div>
      </header>
      <main className="flex-1 max-w-2xl mx-auto w-full px-4 py-4">{children}</main>
    </div>
  );
}
