'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api, setToken } from '../lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('admin@parsalo.in');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (typeof window !== 'undefined' && localStorage.getItem('pp.admin.token')) {
      router.replace('/dashboard');
    }
  }, [router]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const res = await api<{ token: string }>('/auth/admin/login', {
        method: 'POST', body: { email, password }, auth: false,
      });
      setToken(res.token);
      router.push('/dashboard');
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center px-4">
      <form onSubmit={submit} className="w-full max-w-sm bg-white rounded-2xl shadow-sm p-8">
        <h1 className="text-2xl font-bold mb-1">Parsalo Admin</h1>
        <p className="text-slate-500 text-sm mb-6">Sign in to operations dashboard</p>
        <label className="block text-sm font-medium mb-1">Email</label>
        <input
          type="email" value={email} onChange={(e) => setEmail(e.target.value)}
          className="w-full border border-slate-200 rounded-lg px-3 py-2 mb-3"
          required
        />
        <label className="block text-sm font-medium mb-1">Password</label>
        <input
          type="password" value={password} onChange={(e) => setPassword(e.target.value)}
          className="w-full border border-slate-200 rounded-lg px-3 py-2 mb-4"
          required
        />
        {error && <p className="text-red-600 text-sm mb-3">{error}</p>}
        <button
          type="submit"
          disabled={loading}
          className="w-full bg-brand text-white font-semibold py-2.5 rounded-lg hover:bg-brand-dark disabled:opacity-60"
        >
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  );
}
