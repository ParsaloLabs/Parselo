'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { api, STATUS_LABEL } from '../../../lib/api';

type Order = {
  id: string; order_code: string; order_type: 'send' | 'receive';
  status: string; total_amount: number; created_at: string;
  recipient_name?: string | null; source_tracking_id?: string | null;
  payment_status?: string | null;
};

const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'active', label: 'Active' },
  { key: 'completed', label: 'Completed' },
] as const;

const TERMINAL = new Set(['delivered', 'cancelled', 'failed']);

export default function OrdersPage() {
  const [filter, setFilter] = useState<'all' | 'active' | 'completed'>('all');
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    api<Order[]>(`/orders?filter=${filter}`)
      .then(setOrders)
      .catch(() => setOrders([]))
      .finally(() => setLoading(false));
  }, [filter]);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">My orders</h1>
      <p className="text-slate-600 mb-6">Track all your sends and receives</p>

      <div className="flex gap-2 mb-6">
        {FILTERS.map((f) => (
          <button key={f.key} onClick={() => setFilter(f.key)}
            className={`px-4 py-2 rounded-full text-sm font-medium ${
              filter === f.key ? 'bg-brand text-white' : 'bg-white border border-slate-200 text-slate-700 hover:bg-slate-50'
            }`}>
            {f.label}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="text-center text-slate-500 py-12">Loading…</div>
      ) : orders.length === 0 ? (
        <div className="bg-slate-50 rounded-xl p-12 text-center text-slate-500 border border-slate-200">
          <div className="text-3xl mb-2">📦</div>
          No {filter !== 'all' ? filter : ''} orders yet.
          <div className="mt-3">
            <Link href="/home" className="text-brand font-medium hover:text-brand-dark">Book one →</Link>
          </div>
        </div>
      ) : (
        <div className="space-y-2">
          {orders.map((o) => {
            const needsAction = o.status === 'failed' && o.payment_status === 'paid';
            return (
              <Link key={o.id} href={`/home/orders/${o.id}`}
                className={`flex items-center border rounded-xl px-4 py-3 ${
                  needsAction
                    ? 'bg-red-50 border-red-200 hover:bg-red-100'
                    : 'bg-white border-slate-200 hover:bg-slate-50'
                }`}>
                <div className="text-2xl mr-3">{o.order_type === 'send' ? '📤' : '📥'}</div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-mono text-sm font-semibold">{o.order_code}</span>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${
                      o.status === 'failed' ? 'bg-red-100 text-red-700' :
                      TERMINAL.has(o.status) ? 'bg-slate-100 text-slate-600' :
                      'bg-blue-50 text-blue-700'
                    }`}>{STATUS_LABEL[o.status] ?? o.status}</span>
                    {needsAction && (
                      <span className="text-xs px-2 py-0.5 rounded-full bg-red-600 text-white font-medium">
                        Action needed
                      </span>
                    )}
                  </div>
                  <div className="text-sm text-slate-500 truncate">
                    {needsAction
                      ? 'Tap to choose retry or refund'
                      : (o.order_type === 'send'
                          ? `To ${o.recipient_name ?? '—'}`
                          : `Tracking ${o.source_tracking_id ?? '—'}`)}
                    {' · '}{new Date(o.created_at).toLocaleDateString()}
                  </div>
                </div>
                <div className="font-semibold">₹{(o.total_amount / 100).toFixed(0)}</div>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
