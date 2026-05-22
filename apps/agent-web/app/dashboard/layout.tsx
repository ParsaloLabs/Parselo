'use client';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { getToken, setToken } from '../../lib/api';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  useEffect(() => {
    if (!getToken()) router.replace('/login');
  }, [router]);

  const logout = () => { setToken(null); router.push('/login'); };

  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b border-slate-200 bg-white sticky top-0 z-10">
        <div className="max-w-2xl mx-auto px-4 py-3 flex justify-between items-center">
          <div className="font-bold">🛵 ParcelPal Agent</div>
          <button onClick={logout} className="text-sm text-slate-500 hover:text-slate-900">Sign out</button>
        </div>
      </header>
      <main className="flex-1 max-w-2xl mx-auto w-full px-4 py-4">{children}</main>
    </div>
  );
}
