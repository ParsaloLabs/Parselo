'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Script from 'next/script';
import { api } from '../../../../../lib/api';

type CreateRes = {
  dev_mode: boolean;
  amount: number;
  currency: string;
  order_code: string;
  key_id?: string;
  razorpay_order_id?: string;
};

declare global {
  interface Window { Razorpay: any }
}

export default function PayPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const [info, setInfo] = useState<CreateRes | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api<CreateRes>(`/payments/orders/${params.id}/create`, { method: 'POST' })
      .then(setInfo)
      .catch((e) => setError(e.message));
  }, [params.id]);

  const payDev = async () => {
    setBusy(true);
    try {
      await api('/payments/verify', {
        method: 'POST',
        body: { parcelpal_order_id: params.id },
      });
      router.replace(`/home/orders/${params.id}`);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const payReal = () => {
    if (!info?.key_id || !info.razorpay_order_id) return;
    const rp = new window.Razorpay({
      key: info.key_id,
      amount: info.amount,
      currency: info.currency,
      order_id: info.razorpay_order_id,
      name: 'ParcelPal',
      description: info.order_code,
      handler: async (resp: any) => {
        try {
          await api('/payments/verify', {
            method: 'POST',
            body: {
              parcelpal_order_id: params.id,
              razorpay_order_id: resp.razorpay_order_id,
              razorpay_payment_id: resp.razorpay_payment_id,
              razorpay_signature: resp.razorpay_signature,
            },
          });
          router.replace(`/home/orders/${params.id}`);
        } catch (e: any) {
          setError(e.message);
        }
      },
      modal: { ondismiss: () => setBusy(false) },
      theme: { color: '#0E5BFF' },
    });
    setBusy(true);
    rp.open();
  };

  if (error) {
    return (
      <div className="max-w-md mx-auto">
        <p className="text-red-600 mb-4">{error}</p>
        <Link href={`/home/orders/${params.id}`} className="text-brand">← Back to order</Link>
      </div>
    );
  }
  if (!info) return <div className="text-slate-500">Preparing payment…</div>;

  return (
    <div className="max-w-md mx-auto">
      {!info.dev_mode && <Script src="https://checkout.razorpay.com/v1/checkout.js" strategy="afterInteractive" />}

      <div className="bg-white border border-slate-200 rounded-2xl p-8 text-center">
        <div className="text-4xl mb-2">💳</div>
        <h1 className="text-xl font-bold mb-1">Confirm payment</h1>
        <p className="text-sm text-slate-500 mb-6">{info.order_code}</p>

        <div className="text-4xl font-bold mb-1">₹{(info.amount / 100).toFixed(0)}</div>
        <div className="text-xs text-slate-500 mb-6">incl. GST</div>

        {info.dev_mode ? (
          <>
            <div className="bg-amber-50 border border-amber-200 text-amber-900 text-sm rounded-lg px-3 py-2 mb-4">
              Dev mode — Razorpay not configured. Tapping below marks the order paid for testing.
            </div>
            <button onClick={payDev} disabled={busy}
              className="w-full bg-brand text-white font-semibold py-3 rounded-lg hover:bg-brand-dark disabled:opacity-60">
              {busy ? 'Marking paid…' : 'Mark paid (dev)'}
            </button>
          </>
        ) : (
          <button onClick={payReal} disabled={busy}
            className="w-full bg-brand text-white font-semibold py-3 rounded-lg hover:bg-brand-dark disabled:opacity-60">
            {busy ? 'Opening checkout…' : 'Pay with Razorpay'}
          </button>
        )}

        <Link href={`/home/orders/${params.id}`}
          className="block mt-3 text-sm text-slate-500 hover:text-slate-900">
          Pay later →
        </Link>
      </div>
    </div>
  );
}
