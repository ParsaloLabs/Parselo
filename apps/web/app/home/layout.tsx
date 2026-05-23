'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { api, getToken, setToken } from '../../lib/api';

const links = [
  { href: '/home', label: 'Home' },
  { href: '/home/orders', label: 'My orders' },
];

export default function CustomerLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [name, setName] = useState<string | null>(null);

  useEffect(() => {
    if (!getToken()) {
      router.replace('/');
      return;
    }
    api<{ phone: string; full_name?: string | null }>('/me')
      .then((u) => setName(u.full_name ?? u.phone))
      .catch(() => {
        setToken(null);
        router.replace('/');
      });
  }, [router]);

  const logout = () => { setToken(null); router.push('/'); };

  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b border-slate-200 bg-white sticky top-0 z-10">
        <div className="max-w-5xl mx-auto px-6 py-3 flex justify-between items-center">
          <Link href="/home" className="flex items-center">
            <img src="/logo.png" alt="Parsalo" className="h-8 w-auto" />
          </Link>
          <nav className="flex items-center gap-4">
            {links.map((l) => (
              <Link
                key={l.href} href={l.href}
                className={`text-sm ${pathname === l.href ? 'text-brand font-semibold' : 'text-slate-600 hover:text-slate-900'}`}
              >
                {l.label}
              </Link>
            ))}
            <span className="text-sm text-slate-500 hidden md:inline">{name ?? '…'}</span>
            <button onClick={logout} className="text-sm text-slate-500 hover:text-slate-900">Sign out</button>
          </nav>
        </div>
      </header>
      <main className="flex-1 max-w-5xl mx-auto w-full px-6 py-8">{children}</main>
    </div>
  );
}
