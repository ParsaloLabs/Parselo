'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { api } from '../../lib/api';

type Stats = {
  orders_today: number; active_orders: number; agents_online: number;
  revenue_today_paise: number; failed_count: number; refund_requested_count: number;
};

export default function OverviewPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  useEffect(() => {
    api<Stats>('/admin/dashboard-stats').then(setStats).catch(() => {});
  }, []);

  const cards = [
    { label: 'Orders today', value: stats?.orders_today ?? '—' },
    { label: 'Active orders', value: stats?.active_orders ?? '—' },
    { label: 'Agents online', value: stats?.agents_online ?? '—' },
    { label: 'Revenue today', value: stats ? `₹${(stats.revenue_today_paise / 100).toFixed(0)}` : '—' },
  ];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Overview</h1>

      {stats && stats.refund_requested_count > 0 && (
        <Link href="/dashboard/orders?status=failed"
          className="block bg-amber-50 border border-amber-300 rounded-xl p-4 mb-3 hover:bg-amber-100">
          <div className="flex items-center justify-between">
            <div>
              <div className="font-semibold text-amber-900">
                {stats.refund_requested_count} refund request{stats.refund_requested_count === 1 ? '' : 's'} from customers
              </div>
              <div className="text-sm text-amber-800 mt-0.5">
                Customer asked for a refund — pick full or partial. Click to review.
              </div>
            </div>
            <div className="text-2xl text-amber-700">→</div>
          </div>
        </Link>
      )}

      {stats && stats.failed_count > 0 && (
        <Link href="/dashboard/orders?status=failed"
          className="block bg-red-50 border border-red-200 rounded-xl p-4 mb-6 hover:bg-red-100">
          <div className="flex items-center justify-between">
            <div>
              <div className="font-semibold text-red-900">
                {stats.failed_count} failed order{stats.failed_count === 1 ? '' : 's'} awaiting customer choice
              </div>
              <div className="text-sm text-red-700 mt-0.5">
                Customer hasn't picked retry or refund yet. Click to review.
              </div>
            </div>
            <div className="text-2xl text-red-700">→</div>
          </div>
        </Link>
      )}

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {cards.map((c) => (
          <div key={c.label} className="bg-white rounded-xl p-5 border border-slate-200">
            <div className="text-sm text-slate-500">{c.label}</div>
            <div className="text-3xl font-bold mt-2">{c.value}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
