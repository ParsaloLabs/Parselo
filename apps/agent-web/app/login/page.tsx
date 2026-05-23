'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { api, setToken } from '../../lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState('+919999999999');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await api<{ token: string }>('/auth/agent/login', {
        method: 'POST', body: { phone, password }, auth: false,
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
    <div className="min-h-screen flex items-center justify-center px-6">
      <div className="w-full max-w-sm bg-white border border-slate-200 rounded-2xl shadow-lg p-8">
        <div className="text-center mb-6">
          <img src="/logo.png" alt="Parsalo" className="h-28 w-28 mx-auto mb-3" style={{ height: '112px', width: '112px', minWidth: '112px', maxWidth: '112px' }} />
          <h1 className="text-xl font-bold">Agent sign in</h1>
          <p className="text-sm text-slate-500 mt-1">Parsalo delivery partner</p>
        </div>
        <form onSubmit={submit} className="space-y-3">
          <div>
            <label className="block text-sm font-medium mb-1">Phone</label>
            <input value={phone} onChange={(e) => setPhone(e.target.value)}
              type="tel" required
              className="w-full border border-slate-200 rounded-lg px-3 py-2.5" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Password</label>
            <input value={password} onChange={(e) => setPassword(e.target.value)}
              type="password" required
              className="w-full border border-slate-200 rounded-lg px-3 py-2.5" />
          </div>
          {error && <p className="text-red-600 text-sm">{error}</p>}
          <button type="submit" disabled={loading}
            className="w-full bg-brand text-white font-semibold py-2.5 rounded-lg hover:bg-brand-dark disabled:opacity-60">
            {loading ? 'Signing in…' : 'Sign in'}
          </button>
        </form>
      </div>
    </div>
  );
}
