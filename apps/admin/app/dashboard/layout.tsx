'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { getToken, setToken } from '../../lib/api';

const links = [
  { href: '/dashboard', label: 'Overview' },
  { href: '/dashboard/orders', label: 'Orders' },
  { href: '/dashboard/agents', label: 'Agents' },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (!getToken()) router.replace('/');
  }, [router]);

  const logout = () => {
    setToken(null);
    router.push('/');
  };

  return (
    <div className="min-h-screen flex">
      <aside className="w-60 bg-white border-r border-slate-200 p-4">
        <div className="font-bold text-lg mb-6">ParcelPal</div>
        <nav className="flex flex-col gap-1">
          {links.map((l) => {
            const active = pathname === l.href;
            return (
              <Link
                key={l.href} href={l.href}
                className={`px-3 py-2 rounded-lg text-sm ${active ? 'bg-brand text-white' : 'text-slate-700 hover:bg-slate-100'}`}
              >
                {l.label}
              </Link>
            );
          })}
        </nav>
        <button onClick={logout} className="mt-8 text-sm text-slate-500 hover:text-slate-900">Log out</button>
      </aside>
      <main className="flex-1 p-8">{children}</main>
    </div>
  );
}
