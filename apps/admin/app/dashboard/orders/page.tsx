'use client';
import { useCallback, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { api } from '../../../lib/api';

type Order = {
  id: string; order_code: string; order_type: 'send' | 'receive'; status: string;
  total_amount: number; created_at: string;
  user_name?: string | null; user_phone?: string | null; agent_name?: string | null;
  failure_reason?: string | null;
  payment_status?: string | null;
  refund_amount_paise?: number | null;
  retry_at?: string | null;
};
type Agent = { id: string; full_name: string; is_online: boolean; is_active: boolean };

export default function OrdersPage() {
  const searchParams = useSearchParams();
  const [orders, setOrders] = useState<Order[]>([]);
  const [agents, setAgents] = useState<Agent[]>([]);
  const [filter, setFilter] = useState<string>(searchParams.get('status') ?? '');

  const load = useCallback(async () => {
    const path = filter ? `/admin/orders?status=${filter}` : '/admin/orders';
    const [o, a] = await Promise.all([api<Order[]>(path), api<Agent[]>('/admin/agents')]);
    setOrders(o);
    setAgents(a);
  }, [filter]);

  useEffect(() => { load(); }, [load]);

  const assign = async (orderId: string, agentId: string) => {
    if (!agentId) return;
    try {
      await api(`/admin/orders/${orderId}/assign-agent`, { method: 'POST', body: { agent_id: agentId } });
      await load();
    } catch (e: any) {
      alert(e.message);
    }
  };

  const retry = async (o: Order, when: 'today' | 'tomorrow') => {
    const label = when === 'today' ? 'today (immediate)' : 'tomorrow morning';
    if (!confirm(`Re-queue ${o.order_code} for ${label}?`)) return;
    try {
      await api(`/admin/orders/${o.id}/retry`, { method: 'POST', body: { when } });
      await load();
    } catch (e: any) { alert(e.message); }
  };

  const refund = async (o: Order, partial: boolean) => {
    let amount_paise: number | undefined;
    if (partial) {
      const totalRupees = (o.total_amount / 100).toFixed(0);
      const input = prompt(`Partial refund — amount in rupees (max ₹${totalRupees})`, totalRupees);
      if (!input) return;
      const rupees = Number(input);
      if (!Number.isFinite(rupees) || rupees <= 0 || rupees * 100 > o.total_amount) {
        alert('Invalid amount'); return;
      }
      amount_paise = Math.round(rupees * 100);
    } else {
      if (!confirm(`Refund full ₹${(o.total_amount / 100).toFixed(0)} for ${o.order_code}?`)) return;
    }
    try {
      await api(`/admin/orders/${o.id}/refund`, {
        method: 'POST',
        body: amount_paise ? { amount_paise } : {},
      });
      await load();
    } catch (e: any) { alert(e.message); }
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-4">
        <h1 className="text-2xl font-bold">Orders</h1>
        <select
          value={filter} onChange={(e) => setFilter(e.target.value)}
          className="border border-slate-200 rounded-lg px-3 py-1.5 text-sm bg-white"
        >
          <option value="">All</option>
          <option value="pending">Pending</option>
          <option value="agent_assigned">Agent assigned</option>
          <option value="parcel_collected">Collected</option>
          <option value="shipped">Shipped</option>
          <option value="delivered">Delivered</option>
          <option value="failed">Failed</option>
          <option value="cancelled">Cancelled</option>
        </select>
      </div>
      <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-slate-600">
            <tr>
              <th className="px-4 py-3">Code</th>
              <th className="px-4 py-3">Type</th>
              <th className="px-4 py-3">Customer</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Amount</th>
              <th className="px-4 py-3">Agent</th>
              <th className="px-4 py-3">Resolve</th>
            </tr>
          </thead>
          <tbody>
            {orders.map((o) => (
              <tr key={o.id} className={`border-t border-slate-100 ${o.status === 'failed' ? 'bg-red-50' : ''}`}>
                <td className="px-4 py-3 font-mono text-xs">{o.order_code}</td>
                <td className="px-4 py-3 capitalize">{o.order_type}</td>
                <td className="px-4 py-3">{o.user_name ?? o.user_phone ?? '—'}</td>
                <td className="px-4 py-3">
                  <div className={o.status === 'failed' ? 'font-semibold text-red-700' : ''}>{o.status}</div>
                  {o.status === 'failed' && o.failure_reason && (
                    <div className="text-xs text-red-700 mt-0.5">{o.failure_reason}</div>
                  )}
                  {o.payment_status === 'refund_requested' && (
                    <div className="text-xs text-amber-700 mt-0.5 font-medium">
                      ⚠ refund requested by customer
                    </div>
                  )}
                  {o.payment_status === 'refunded' && (
                    <div className="text-xs text-amber-700 mt-0.5">
                      refunded ₹{((o.refund_amount_paise ?? 0) / 100).toFixed(0)}
                    </div>
                  )}
                  {o.status === 'pending' && o.retry_at && new Date(o.retry_at) > new Date() && (
                    <div className="text-xs text-blue-700 mt-0.5">
                      retry scheduled {new Date(o.retry_at).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}
                    </div>
                  )}
                </td>
                <td className="px-4 py-3">₹{(o.total_amount / 100).toFixed(0)}</td>
                <td className="px-4 py-3">
                  {o.agent_name ? (
                    o.agent_name
                  ) : o.status === 'pending' ? (
                    <select
                      defaultValue=""
                      onChange={(e) => assign(o.id, e.target.value)}
                      className="border border-slate-200 rounded px-2 py-1 text-xs"
                    >
                      <option value="">Assign…</option>
                      {agents.filter((a) => a.is_active).map((a) => (
                        <option key={a.id} value={a.id}>{a.full_name}{a.is_online ? ' · online' : ''}</option>
                      ))}
                    </select>
                  ) : (
                    '—'
                  )}
                </td>
                <td className="px-4 py-3">
                  {o.status === 'failed' && o.payment_status !== 'refunded' ? (
                    <div className="flex flex-col gap-1">
                      <div className="flex gap-1">
                        <button onClick={() => retry(o, 'today')}
                          className="flex-1 text-xs px-2 py-1 rounded border border-blue-300 text-blue-700 hover:bg-blue-50">
                          Retry today
                        </button>
                        <button onClick={() => retry(o, 'tomorrow')}
                          className="flex-1 text-xs px-2 py-1 rounded border border-blue-300 text-blue-700 hover:bg-blue-50">
                          Tomorrow
                        </button>
                      </div>
                      <button onClick={() => refund(o, false)}
                        className="text-xs px-2 py-1 rounded border border-red-300 text-red-700 hover:bg-red-50">
                        Refund full
                      </button>
                      <button onClick={() => refund(o, true)}
                        className="text-xs px-2 py-1 rounded border border-amber-300 text-amber-700 hover:bg-amber-50">
                        Refund partial
                      </button>
                    </div>
                  ) : (
                    <span className="text-slate-300">—</span>
                  )}
                </td>
              </tr>
            ))}
            {orders.length === 0 && (
              <tr><td className="px-4 py-8 text-center text-slate-500" colSpan={7}>No orders</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
