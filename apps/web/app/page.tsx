'use client';
import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { RecaptchaVerifier, signInWithPhoneNumber, type ConfirmationResult } from 'firebase/auth';
import { firebaseAuth } from '../lib/firebase';
import { api, getToken, setToken } from '../lib/api';

const FRIENDLY_ERRORS: Record<string, string> = {
  invalid_phone: 'Enter a valid mobile number (10 digits, with or without +91).',
  invalid_input: 'Please check your input and try again.',
  invalid_id_token: 'Verification expired. Please try again.',
  firebase_not_configured: 'Sign-in is temporarily unavailable. Contact support.',
  'auth/invalid-phone-number': 'Enter a valid mobile number.',
  'auth/too-many-requests': 'Too many attempts. Try again in a few minutes.',
  'auth/code-expired': 'OTP expired. Request a new one.',
  'auth/invalid-verification-code': 'OTP is incorrect.',
  'auth/operation-not-allowed': 'Phone sign-in is not enabled. Contact support.',
  'auth/billing-not-enabled': 'SMS service is being activated. Please try again shortly.',
  'auth/captcha-check-failed': 'Verification check failed. Refresh the page and try again.',
  'auth/quota-exceeded': 'Too many sign-ins right now. Try again in a few minutes.',
};

function friendly(code: string | null): string | null {
  if (!code) return null;
  return FRIENDLY_ERRORS[code] ?? code;
}

export default function LandingPage() {
  const router = useRouter();
  const [phone, setPhone] = useState('+91');
  const [otp, setOtp] = useState('');
  const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const confirmationRef = useRef<ConfirmationResult | null>(null);
  const recaptchaRef = useRef<RecaptchaVerifier | null>(null);

  useEffect(() => {
    if (getToken()) router.replace('/home');
  }, [router]);

  useEffect(() => {
    return () => {
      try { recaptchaRef.current?.clear(); } catch {}
      recaptchaRef.current = null;
    };
  }, []);

  const resetRecaptcha = () => {
    try { recaptchaRef.current?.clear(); } catch {}
    recaptchaRef.current = null;
    const container = document.getElementById('recaptcha-container');
    if (container) container.innerHTML = '';
  };

  const sendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      resetRecaptcha();
      const verifier = new RecaptchaVerifier(firebaseAuth, 'recaptcha-container', {
        size: 'invisible',
      });
      recaptchaRef.current = verifier;
      const confirmation = await signInWithPhoneNumber(firebaseAuth, phone, verifier);
      confirmationRef.current = confirmation;
      setStep('otp');
    } catch (e: any) {
      setError(e?.code ?? e?.message ?? 'send_failed');
      resetRecaptcha();
    } finally {
      setLoading(false);
    }
  };

  const verify = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      if (!confirmationRef.current) throw new Error('no_confirmation');
      const cred = await confirmationRef.current.confirm(otp);
      const idToken = await cred.user.getIdToken();
      const res = await api<{ token: string }>('/auth/firebase-login', {
        method: 'POST', body: { id_token: idToken }, auth: false,
      });
      setToken(res.token);
      router.push('/home');
    } catch (e: any) {
      setError(e?.code ?? e?.message ?? 'verify_failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b border-slate-200 bg-white">
        <div className="max-w-6xl mx-auto px-6 py-4 flex justify-between items-center">
          <img src="/logo.png" alt="Parsalo" className="h-16 w-16" style={{ height: '64px', width: '64px', minWidth: '64px', maxWidth: '64px' }} />
          <Link href="/" className="text-sm text-slate-600 hover:text-slate-900">Sign in</Link>
        </div>
      </header>

      <main className="flex-1 max-w-6xl mx-auto px-6 py-6 md:py-16 grid md:grid-cols-2 gap-8 md:gap-12 items-center">
        <div className="order-2 md:order-1">
          <h1 className="text-3xl md:text-5xl font-bold leading-tight">
            Skip the courier queue.
          </h1>
          <p className="text-base md:text-lg text-slate-600 mt-4 leading-relaxed">
            Book a pickup from your office or home — our agent collects your parcel,
            ships it through the courier you choose, and sends you a tracking ID.
            Or use us to <span className="text-brand font-semibold">collect a parcel</span> stuck
            at a courier office. No standing in line.
          </p>
          <ul className="mt-6 space-y-2 text-slate-700">
            <li>📤 Send parcels via DTDC, Delhivery, BlueDart or India Post</li>
            <li>📥 Receive parcels from any courier office on your behalf</li>
            <li>📍 Real-time tracking — see exactly where your agent is</li>
          </ul>
        </div>

        <div className="order-1 md:order-2 bg-white rounded-2xl shadow-lg border border-slate-200 p-6 md:p-8">
          <h2 className="text-xl font-semibold mb-1">
            {step === 'phone' ? 'Sign in to book' : 'Enter the OTP'}
          </h2>
          <p className="text-sm text-slate-500 mb-6">
            {step === 'phone'
              ? "We'll text you a 6-digit code"
              : `Sent to ${phone}`}
          </p>

          {step === 'phone' ? (
            <form onSubmit={sendOtp}>
              <label className="block text-sm font-medium mb-1">Mobile number</label>
              <input
                type="tel" value={phone} onChange={(e) => setPhone(e.target.value)}
                className={`w-full border rounded-lg px-3 py-2.5 ${error ? 'border-red-400' : 'border-slate-200'}`}
                placeholder="+91XXXXXXXXXX" required
              />
              {error && <span className="block text-red-600 text-sm mt-1">{friendly(error)}</span>}
              <div className="mb-4" />
              <button
                type="submit" disabled={loading}
                className="w-full bg-brand text-white font-semibold py-2.5 rounded-lg hover:bg-brand-dark disabled:opacity-60"
              >
                {loading ? 'Sending…' : 'Send OTP'}
              </button>
              <p className="text-xs text-slate-500 mt-3 text-center">
                By continuing you agree to our Terms and Privacy Policy.
              </p>
            </form>
          ) : (
            <form onSubmit={verify}>
              <label className="block text-sm font-medium mb-1">6-digit OTP</label>
              <input
                type="text" inputMode="numeric" maxLength={6}
                value={otp} onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                className={`w-full border rounded-lg px-3 py-2.5 text-center tracking-widest text-lg ${error ? 'border-red-400' : 'border-slate-200'}`}
                placeholder="123456" required
              />
              {error && <span className="block text-red-600 text-sm mt-1">{friendly(error)}</span>}
              <div className="mb-4" />
              <button
                type="submit" disabled={loading}
                className="w-full bg-brand text-white font-semibold py-2.5 rounded-lg hover:bg-brand-dark disabled:opacity-60"
              >
                {loading ? 'Verifying…' : 'Verify & continue'}
              </button>
              <button
                type="button" onClick={() => { setStep('phone'); setOtp(''); setError(null); confirmationRef.current = null; }}
                className="w-full text-sm text-slate-500 mt-3 hover:text-slate-900"
              >
                Use a different number
              </button>
            </form>
          )}

          <div id="recaptcha-container" />
        </div>
      </main>

      <footer className="border-t border-slate-200 py-6 text-center text-sm text-slate-500">
        Parsalo · Thrissur, Kerala
        <span className="mx-2">·</span>
        <Link href="/agent-signup" className="text-brand hover:underline">Drive with us</Link>
      </footer>
    </div>
  );
}
