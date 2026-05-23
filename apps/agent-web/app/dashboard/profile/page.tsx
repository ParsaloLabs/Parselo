'use client';
import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import { api, STATUS_LABEL } from '../../../lib/api';

type AgentProfile = {
  id: string;
  full_name: string;
  phone: string;
  email?: string | null;
  vehicle_type?: string | null;
  vehicle_number?: string | null;
  rating?: number | null;
  total_deliveries?: number | null;
  is_online?: boolean;
};

type HistoryOrder = {
  id: string;
  order_code: string;
  order_type: 'send' | 'receive';
  status: string;
  total_amount: number;
  service_fee?: number | null;
  recipient_name?: string | null;
  delivery_address?: string | null;
  parcel_description?: string | null;
  pickup_text?: string | null;
  drop_text?: string | null;
  pickup_completed_at?: string | null;
  delivery_completed_at?: string | null;
  failure_reason?: string | null;
  updated_at?: string | null;
  created_at?: string | null;
};

const STATUS_COLOR: Record<string, string> = {
  delivered: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  failed: 'bg-red-50 text-red-700 border-red-200',
  cancelled: 'bg-slate-100 text-slate-600 border-slate-200',
};

const STATUS_ICON: Record<string, string> = {
  delivered: '✅',
  failed: '❌',
  cancelled: '🚫',
};

function formatDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

function formatTime(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  return d.toLocaleTimeString('en-IN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
  });
}

function relativeTime(iso: string | null | undefined): string {
  if (!iso) return '';
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  if (days < 7) return `${days}d ago`;
  return formatDate(iso);
}

export default function ProfilePage() {
  const [profile, setProfile] = useState<AgentProfile | null>(null);
  const [orders, setOrders] = useState<HistoryOrder[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'all' | 'delivered' | 'failed'>('all');

  const loadProfile = useCallback(async () => {
    try {
      const [me, history] = await Promise.all([
        api<AgentProfile>('/agent/me'),
        api<{ orders: HistoryOrder[]; total: number }>('/agent/history?limit=30'),
      ]);
      setProfile(me);
      setOrders(history.orders);
      setTotal(history.total);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadProfile(); }, [loadProfile]);

  const loadMore = async () => {
    setLoadingMore(true);
    try {
      const res = await api<{ orders: HistoryOrder[]; total: number }>(
        `/agent/history?limit=30&offset=${orders.length}`,
      );
      setOrders((prev) => [...prev, ...res.orders]);
      setTotal(res.total);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoadingMore(false);
    }
  };

  const filtered = activeTab === 'all'
    ? orders
    : orders.filter((o) => o.status === activeTab);

  const deliveredCount = orders.filter((o) => o.status === 'delivered').length;
  const failedCount = orders.filter((o) => o.status === 'failed').length;

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-pulse text-slate-400 font-semibold text-sm">Loading profile…</div>
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* Back nav */}
      <Link href="/dashboard" className="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-900 font-medium transition-colors">
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 19l-7-7 7-7" /></svg>
        Dashboard
      </Link>

      {/* Profile Card */}
      {profile && (
        <div className="relative overflow-hidden bg-gradient-to-br from-brand-dark via-brand to-blue-500 rounded-2xl p-5 text-white shadow-lg">
          {/* Background decoration */}
          <div className="absolute -right-8 -top-8 w-40 h-40 bg-white/5 rounded-full" />
          <div className="absolute -left-6 -bottom-6 w-32 h-32 bg-white/5 rounded-full" />

          <div className="relative z-10">
            {/* Avatar + Name */}
            <div className="flex items-center gap-4 mb-5">
              <div className="h-16 w-16 rounded-2xl bg-white/15 backdrop-blur-sm border border-white/20 flex items-center justify-center text-2xl font-black shadow-inner">
                {profile.full_name.charAt(0).toUpperCase()}
              </div>
              <div className="flex-1 min-w-0">
                <h1 className="text-xl font-black leading-tight truncate">{profile.full_name}</h1>
                <p className="text-white/70 text-sm font-medium mt-0.5">Delivery Partner</p>
              </div>
              {profile.is_online && (
                <span className="px-2.5 py-1 rounded-full bg-emerald-400/20 border border-emerald-300/30 text-xs font-bold text-emerald-200 shrink-0">
                  🟢 Online
                </span>
              )}
            </div>

            {/* Stats grid */}
            <div className="grid grid-cols-3 gap-2.5">
              <div className="bg-white/10 backdrop-blur-sm rounded-xl p-3 border border-white/10">
                <span className="text-[10px] font-bold text-white/60 uppercase tracking-wider block">Rating</span>
                <span className="text-lg font-black block mt-0.5">
                  ⭐ {profile.rating ? Number(profile.rating).toFixed(1) : '5.0'}
                </span>
              </div>
              <div className="bg-white/10 backdrop-blur-sm rounded-xl p-3 border border-white/10">
                <span className="text-[10px] font-bold text-white/60 uppercase tracking-wider block">Deliveries</span>
                <span className="text-lg font-black block mt-0.5">
                  {profile.total_deliveries ?? 0}
                </span>
              </div>
              <div className="bg-white/10 backdrop-blur-sm rounded-xl p-3 border border-white/10">
                <span className="text-[10px] font-bold text-white/60 uppercase tracking-wider block">Vehicle</span>
                <span className="text-sm font-black block mt-1 truncate">
                  {profile.vehicle_type ? profile.vehicle_type.toUpperCase() : '—'}
                </span>
              </div>
            </div>

            {/* Contact Details */}
            <div className="mt-4 flex items-center gap-4 text-xs text-white/60">
              <span className="flex items-center gap-1.5">
                📱 {profile.phone}
              </span>
              {profile.vehicle_number && (
                <span className="flex items-center gap-1.5">
                  🏍️ {profile.vehicle_number}
                </span>
              )}
              {profile.email && (
                <span className="flex items-center gap-1.5 truncate">
                  ✉️ {profile.email}
                </span>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Job History Section */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-xs font-black text-slate-400 uppercase tracking-widest">
            Job History ({total})
          </h2>
        </div>

        {/* Filter Tabs */}
        <div className="flex gap-1.5 mb-4 bg-slate-100/80 rounded-xl p-1">
          {([
            { key: 'all' as const, label: 'All', count: orders.length },
            { key: 'delivered' as const, label: 'Delivered', count: deliveredCount },
            { key: 'failed' as const, label: 'Failed', count: failedCount },
          ]).map(({ key, label, count }) => (
            <button
              key={key}
              onClick={() => setActiveTab(key)}
              className={`flex-1 text-xs font-bold py-2 rounded-lg transition-all ${
                activeTab === key
                  ? 'bg-white text-slate-800 shadow-sm'
                  : 'text-slate-500 hover:text-slate-700'
              }`}
            >
              {label} <span className="text-[10px] opacity-60">({count})</span>
            </button>
          ))}
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl p-3.5 mb-3">
            ⚠️ {error}
          </div>
        )}

        {/* History list */}
        {filtered.length === 0 ? (
          <div className="bg-slate-50 border border-slate-200/60 rounded-2xl p-8 text-center">
            <span className="text-2xl block mb-2">📋</span>
            <span className="text-xs text-slate-500 font-medium">
              {activeTab === 'all'
                ? 'No completed jobs yet. Start accepting gigs!'
                : `No ${activeTab} jobs to display.`}
            </span>
          </div>
        ) : (
          <div className="space-y-2.5">
            {filtered.map((order) => {
              const earning = order.service_fee
                ? Math.round(Number(order.service_fee) / 100)
                : Math.round(Number(order.total_amount) / 100);
              const ts = order.delivery_completed_at || order.updated_at || order.created_at;

              return (
                <div
                  key={order.id}
                  className="bg-white border border-slate-200/80 rounded-2xl p-4 hover:shadow-sm transition-all group"
                >
                  {/* Top row: code + status */}
                  <div className="flex items-start justify-between gap-3 mb-2.5">
                    <div className="flex items-center gap-2.5 min-w-0">
                      <div className={`h-9 w-9 rounded-xl flex items-center justify-center text-base shrink-0 ${
                        order.order_type === 'send' ? 'bg-amber-50 text-amber-600' : 'bg-blue-50 text-blue-600'
                      }`}>
                        {order.order_type === 'send' ? '📤' : '📥'}
                      </div>
                      <div className="min-w-0">
                        <div className="font-mono text-sm font-extrabold text-slate-800 leading-none">{order.order_code}</div>
                        <div className="text-[10px] text-slate-400 mt-1 font-medium">
                          {relativeTime(ts)} · {formatTime(ts)}
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-2 shrink-0">
                      <span className="text-sm font-black text-emerald-600">
                        {order.status === 'delivered' ? `₹${earning}` : '—'}
                      </span>
                      <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold border ${STATUS_COLOR[order.status] ?? 'bg-slate-50 text-slate-600 border-slate-200'}`}>
                        {STATUS_ICON[order.status] ?? '•'} {STATUS_LABEL[order.status] ?? order.status}
                      </span>
                    </div>
                  </div>

                  {/* Route info */}
                  <div className="space-y-1 pl-[46px]">
                    {order.pickup_text && (
                      <div className="flex items-start gap-2 text-xs">
                        <span className="text-emerald-500 font-bold shrink-0 w-9">From</span>
                        <span className="text-slate-600 truncate">{order.pickup_text}</span>
                      </div>
                    )}
                    {order.drop_text && (
                      <div className="flex items-start gap-2 text-xs">
                        <span className="text-rose-500 font-bold shrink-0 w-9">To</span>
                        <span className="text-slate-600 truncate">{order.drop_text}</span>
                      </div>
                    )}
                    {order.parcel_description && (
                      <div className="flex items-start gap-2 text-xs mt-1">
                        <span className="text-slate-400 font-bold shrink-0 w-9">Item</span>
                        <span className="text-slate-500 truncate">{order.parcel_description}</span>
                      </div>
                    )}
                    {order.status === 'failed' && order.failure_reason && (
                      <div className="mt-1.5 text-[11px] text-red-600 bg-red-50 rounded-lg px-2.5 py-1.5 border border-red-100">
                        <strong>Reason:</strong> {order.failure_reason}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}

            {/* Load more button */}
            {orders.length < total && (
              <button
                onClick={loadMore}
                disabled={loadingMore}
                className="w-full py-3 text-xs font-bold text-brand bg-brand/5 hover:bg-brand/10 rounded-xl transition-colors disabled:opacity-50"
              >
                {loadingMore ? 'Loading…' : `Load more (${total - orders.length} remaining)`}
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
