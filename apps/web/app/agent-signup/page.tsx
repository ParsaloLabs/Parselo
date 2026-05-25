'use client';
import Link from 'next/link';
import { useState } from 'react';
import { api } from '../../lib/api';

const FRIENDLY_ERRORS: Record<string, string> = {
  invalid_input: 'Please check your details and try again.',
  invalid_phone: 'Enter a valid mobile number (10 digits, with or without +91).',
  phone_in_use: 'This mobile number is already registered. Try logging in.',
};

function friendly(code: string | null): string | null {
  if (!code) return null;
  return FRIENDLY_ERRORS[code] ?? code;
}

type Form = {
  full_name: string;
  phone: string;
  email: string;
  password: string;
  vehicle_type: 'bike' | 'scooter';
  vehicle_number: string;
  dl_number: string;
  city: string;
};

const EMPTY: Form = {
  full_name: '',
  phone: '+91',
  email: '',
  password: '',
  vehicle_type: 'bike',
  vehicle_number: '',
  dl_number: '',
  city: 'Thrissur',
};

export default function AgentSignupPage() {
  const [form, setForm] = useState<Form>(EMPTY);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);

  const update = <K extends keyof Form>(k: K, v: Form[K]) => setForm((f) => ({ ...f, [k]: v }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await api('/auth/agent/register', { method: 'POST', body: form, auth: false });
      setSubmitted(true);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col bg-slate-50">
      <header className="border-b border-slate-200 bg-white">
        <div className="max-w-3xl mx-auto px-6 py-4 flex justify-between items-center">
          <Link href="/" className="flex items-center gap-2">
            <img src="/logo.png" alt="Parsalo" className="h-12 w-12" />
            <span className="font-semibold">Parsalo</span>
          </Link>
          <Link href="/" className="text-sm text-slate-600 hover:text-slate-900">Customer sign in</Link>
        </div>
      </header>

      <main className="flex-1 max-w-3xl w-full mx-auto px-6 py-8">
        {submitted ? (
          <div className="bg-white rounded-2xl shadow-lg border border-slate-200 p-8 text-center">
            <div className="text-5xl mb-4">📬</div>
            <h1 className="text-2xl font-bold mb-2">Application received</h1>
            <p className="text-slate-600 leading-relaxed">
              Thanks for applying to drive with Parsalo. Our team will review your details
              and get in touch within 1–2 business days. Once approved, you can log in to
              the agent app using the phone and password you set here.
            </p>
            <Link href="/" className="inline-block mt-6 text-brand font-semibold hover:underline">
              Back to home
            </Link>
          </div>
        ) : (
          <>
            <div className="mb-6">
              <h1 className="text-3xl font-bold">Drive with Parsalo</h1>
              <p className="text-slate-600 mt-2">
                Tell us about yourself and your vehicle. We'll review your application and
                activate your account within 1–2 business days.
              </p>
            </div>

            <form onSubmit={submit} className="bg-white rounded-2xl shadow-lg border border-slate-200 p-6 md:p-8 grid gap-4">
              <Section title="About you">
                <Field label="Full name" required>
                  <input
                    type="text" value={form.full_name} onChange={(e) => update('full_name', e.target.value)}
                    className="input" placeholder="As on your driving licence" required minLength={2}
                  />
                </Field>
                <Field label="Mobile number" required hint="We'll use this for app login.">
                  <input
                    type="tel" value={form.phone} onChange={(e) => update('phone', e.target.value)}
                    className="input" placeholder="+91XXXXXXXXXX" required
                  />
                </Field>
                <Field label="Email (optional)">
                  <input
                    type="email" value={form.email} onChange={(e) => update('email', e.target.value)}
                    className="input" placeholder="you@example.com"
                  />
                </Field>
                <Field label="Password" required hint="At least 6 characters. You'll use this to log in to the agent app.">
                  <input
                    type="password" value={form.password} onChange={(e) => update('password', e.target.value)}
                    className="input" minLength={6} required
                  />
                </Field>
                <Field label="City" required>
                  <input
                    type="text" value={form.city} onChange={(e) => update('city', e.target.value)}
                    className="input" required
                  />
                </Field>
              </Section>

              <div className="border-t border-slate-200 my-2" />

              <Section title="Your vehicle">
                <Field label="Vehicle type" required>
                  <select
                    value={form.vehicle_type} onChange={(e) => update('vehicle_type', e.target.value as Form['vehicle_type'])}
                    className="input"
                  >
                    <option value="bike">Bike</option>
                    <option value="scooter">Scooter</option>
                  </select>
                </Field>
                <Field label="Vehicle registration number" required>
                  <input
                    type="text" value={form.vehicle_number} onChange={(e) => update('vehicle_number', e.target.value.toUpperCase())}
                    className="input" placeholder="KL-08-AB-1234" required minLength={4}
                  />
                </Field>
                <Field label="Driving licence number" required>
                  <input
                    type="text" value={form.dl_number} onChange={(e) => update('dl_number', e.target.value.toUpperCase())}
                    className="input" required minLength={4}
                  />
                </Field>
              </Section>

              {error && (
                <div className="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">
                  {friendly(error)}
                </div>
              )}

              <button
                type="submit" disabled={loading}
                className="bg-brand text-white font-semibold py-3 rounded-lg hover:bg-brand-dark disabled:opacity-60 mt-2"
              >
                {loading ? 'Submitting…' : 'Submit application'}
              </button>

              <p className="text-xs text-slate-500 text-center">
                By submitting you agree to our Terms and Privacy Policy. We'll keep your
                details only to verify your application.
              </p>
            </form>
          </>
        )}
      </main>

      <footer className="border-t border-slate-200 py-6 text-center text-sm text-slate-500">
        Parsalo · Thrissur, Kerala
      </footer>

      <style jsx>{`
        :global(.input) {
          width: 100%;
          border: 1px solid #e2e8f0;
          border-radius: 0.5rem;
          padding: 0.625rem 0.75rem;
          font-size: 0.95rem;
          background: white;
        }
        :global(.input:focus) {
          outline: none;
          border-color: var(--tw-color-brand, #2563eb);
          box-shadow: 0 0 0 3px rgb(37 99 235 / 0.1);
        }
      `}</style>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="text-sm font-semibold text-slate-500 uppercase tracking-wide mb-3">{title}</h2>
      <div className="grid md:grid-cols-2 gap-4">{children}</div>
    </div>
  );
}

function Field({
  label, required, hint, children,
}: { label: string; required?: boolean; hint?: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="block text-sm font-medium mb-1">
        {label}{required && <span className="text-red-500 ml-0.5">*</span>}
      </span>
      {children}
      {hint && <span className="block text-xs text-slate-500 mt-1">{hint}</span>}
    </label>
  );
}
