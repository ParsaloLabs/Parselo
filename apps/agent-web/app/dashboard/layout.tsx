'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { api, getToken, setToken } from '../../lib/api';

type AgentProfile = {
  full_name: string;
  phone: string;
  vehicle_type?: string | null;
  rating?: number | null;
};

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [profile, setProfile] = useState<AgentProfile | null>(null);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    if (!getToken()) {
      router.replace('/login');
      return;
    }
    
    api<AgentProfile>('/agent/me')
      .then((u) => setProfile(u))
      .catch(() => {
        setToken(null);
        router.replace('/login');
      });
  }, [router]);

  const logout = () => {
    setToken(null);
    router.push('/login');
  };

  const initial = profile?.full_name ? profile.full_name.charAt(0).toUpperCase() : 'A';

  if (!mounted) {
    return (
      <div className="min-h-screen bg-slate-50 flex items-center justify-center">
        <div className="animate-pulse text-slate-400 font-semibold text-sm">Loading console...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      <header className="border-b border-slate-200/80 bg-white/80 backdrop-blur-md sticky top-0 z-30 shadow-sm">
        <div className="max-w-2xl mx-auto px-4 py-3 flex justify-between items-center">
          <Link href="/dashboard" className="flex items-center hover:opacity-90 transition-opacity">
            <img src="/logo.png" alt="Parsalo Agent" className="h-10 w-10 object-contain" style={{ height: '40px', width: '40px', minWidth: '40px', maxWidth: '40px' }} />
          </Link>
          <div className="flex items-center gap-3">
            <div className="flex flex-col items-end hidden xs:flex">
              <span className="text-sm font-semibold text-slate-800 leading-none">{profile?.full_name ?? 'Loading...'}</span>
              <span className="text-xs text-slate-500 mt-1">
                ⭐ {profile?.rating ? Number(profile.rating).toFixed(1) : '5.0'} · {profile?.vehicle_type ? profile.vehicle_type.toUpperCase() : 'Partner'}
              </span>
            </div>
            <div className="relative group">
              <button className="h-10 w-10 rounded-full bg-brand text-white flex items-center justify-center font-bold text-base shadow-sm ring-2 ring-brand/10 hover:opacity-95 transition-all">
                {initial}
              </button>
              <div className="absolute right-0 mt-2 w-48 bg-white border border-slate-200 rounded-xl shadow-xl py-1 hidden group-hover:block z-50">
                <div className="px-4 py-2 border-b border-slate-100 text-xs text-slate-500 truncate">
                  {profile?.phone}
                </div>
                <button onClick={logout} className="w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-slate-50 font-medium transition-colors">
                  Sign out
                </button>
              </div>
            </div>
          </div>
        </div>
      </header>
      <main className="flex-1 max-w-2xl mx-auto w-full px-4 py-6">{children}</main>
    </div>
  );
}
