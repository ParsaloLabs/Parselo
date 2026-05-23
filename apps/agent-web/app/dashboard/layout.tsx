'use client';
import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import Link from 'next/link';
import { api, getToken, setToken } from '../../lib/api';

type AgentProfile = {
  full_name: string;
  phone: string;
  vehicle_type?: string | null;
  rating?: number | null;
  total_deliveries?: number | null;
};

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [profile, setProfile] = useState<AgentProfile | null>(null);
  const [mounted, setMounted] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

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

  // Close menu when clicking outside
  useEffect(() => {
    if (!menuOpen) return;
    const close = () => setMenuOpen(false);
    document.addEventListener('click', close);
    return () => document.removeEventListener('click', close);
  }, [menuOpen]);

  // Close menu on navigation
  useEffect(() => { setMenuOpen(false); }, [pathname]);

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
            <div className="relative">
              <button
                onClick={(e) => { e.stopPropagation(); setMenuOpen((p) => !p); }}
                className={`h-10 w-10 rounded-full bg-brand text-white flex items-center justify-center font-bold text-base shadow-sm ring-2 transition-all ${
                  menuOpen ? 'ring-brand/40 scale-95' : 'ring-brand/10 hover:ring-brand/25'
                }`}
              >
                {initial}
              </button>
              {menuOpen && (
                <div
                  className="absolute right-0 mt-2 w-56 bg-white border border-slate-200 rounded-2xl shadow-2xl py-1.5 z-50 animate-[fadein_120ms_ease-out]"
                  onClick={(e) => e.stopPropagation()}
                >
                  {/* Agent info header */}
                  <div className="px-4 py-3 border-b border-slate-100">
                    <div className="font-semibold text-sm text-slate-800 truncate">{profile?.full_name}</div>
                    <div className="text-xs text-slate-400 mt-0.5">{profile?.phone}</div>
                    <div className="flex items-center gap-3 mt-2 text-[10px] text-slate-500">
                      <span>⭐ {profile?.rating ? Number(profile.rating).toFixed(1) : '5.0'}</span>
                      <span>📦 {profile?.total_deliveries ?? 0} deliveries</span>
                    </div>
                  </div>

                  {/* Profile link */}
                  <Link
                    href="/dashboard/profile"
                    className="flex items-center gap-2.5 px-4 py-2.5 text-sm text-slate-700 hover:bg-slate-50 font-medium transition-colors"
                  >
                    <svg className="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                    Profile & Job History
                  </Link>

                  {/* Divider + Sign out */}
                  <div className="border-t border-slate-100 mt-1 pt-1">
                    <button
                      onClick={logout}
                      className="flex items-center gap-2.5 w-full text-left px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 font-medium transition-colors"
                    >
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                      </svg>
                      Sign out
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </header>
      <main className="flex-1 max-w-2xl mx-auto w-full px-4 py-6">{children}</main>
    </div>
  );
}

