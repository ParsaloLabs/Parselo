'use client';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { getToken } from '../lib/api';

export default function Index() {
  const router = useRouter();
  useEffect(() => {
    router.replace(getToken() ? '/dashboard' : '/login');
  }, [router]);
  return <div className="p-8 text-slate-500">Loading…</div>;
}
