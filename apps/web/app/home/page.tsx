'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { api, STATUS_LABEL } from '../../lib/api';

type Order = {
  id: string; order_code: string; order_type: 'send' | 'receive';
  status: string; total_amount: number; created_at: string;
  payment_status?: string | null;
};

export default function HomePage() {
  const [orders, setOrders] = useState<Order[]>([]);
  useEffect(() => { api<Order[]>('/orders?limit=5').then(setOrders).catch(() => {}); }, []);
  const needsAction = orders.find((o) => o.status === 'failed' && o.payment_status === 'paid');

  const greeting = (() => {
    const h = new Date().getHours();
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  })();

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">{greeting} 👋</h1>
      <p className="text-slate-600 mb-8">What do you need to do today?</p>

      {needsAction && (
        <Link href={`/home/orders/${needsAction.id}`}
          className="block bg-red-50 border border-red-200 rounded-xl p-4 mb-6 hover:bg-red-100">
          <div className="flex items-center justify-between">
            <div>
              <div className="font-semibold text-red-900">
                {needsAction.order_code} couldn't be completed
              </div>
              <div className="text-sm text-red-800 mt-0.5">
                Tap to choose: retry today, retry tomorrow, or request a refund.
              </div>
            </div>
            <div className="text-2xl text-red-700">→</div>
          </div>
        </Link>
      )}

      <div className="grid md:grid-cols-2 gap-4 mb-10">
        <Link
          href="/home/send"
          className="bg-brand text-white rounded-2xl p-8 hover:bg-brand-dark transition-colors"
        >
          <div className="text-4xl mb-3">📤</div>
          <div className="text-xl font-bold mb-1">Send a parcel</div>
          <div className="text-sm text-blue-100">We pick up from you and ship via the courier you choose</div>
        </Link>
        <Link
          href="/home/receive"
          className="bg-amber-500 text-white rounded-2xl p-8 hover:bg-amber-600 transition-colors"
        >
          <div className="text-4xl mb-3">📥</div>
          <div className="text-xl font-bold mb-1">Receive a parcel</div>
          <div className="text-sm text-amber-100">Collect a parcel stuck at a courier office on your behalf</div>
        </Link>
      </div>

      <div className="flex justify-between items-center mb-3">
        <h2 className="text-lg font-semibold">Recent orders</h2>
        <Link href="/home/orders" className="text-sm text-brand hover:text-brand-dark">View all →</Link>
      </div>

      {orders.length === 0 ? (
        <div className="bg-slate-50 rounded-xl p-8 text-center text-slate-500 border border-slate-200">
          No orders yet. Tap Send or Receive to start.
        </div>
      ) : (
        <div className="space-y-2">
          {orders.map((o) => (
            <Link
              key={o.id} href={`/home/orders/${o.id}`}
              className="flex items-center bg-white border border-slate-200 rounded-xl px-4 py-3 hover:bg-slate-50"
            >
              <div className="flex-1">
                <div className="font-mono text-sm font-semibold">{o.order_code}</div>
                <div className="text-sm text-slate-500">
                  {o.order_type === 'send' ? 'Send' : 'Receive'} · {STATUS_LABEL[o.status] ?? o.status}
                </div>
              </div>
              <div className="font-semibold">₹{(o.total_amount / 100).toFixed(0)}</div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
