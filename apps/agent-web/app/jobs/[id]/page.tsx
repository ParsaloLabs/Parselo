'use client';
import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { api, downloadFile, STATUS_LABEL } from '../../../lib/api';
import JobMap from '../../../components/JobMap';

type Order = {
  id: string; order_code: string; order_type: 'send' | 'receive'; status: string;
  recipient_name?: string | null; recipient_phone?: string | null;
  delivery_address?: string | null;
  source_tracking_id?: string | null;
  pickup_address_id?: string | null;
  courier_tracking_id?: string | null;
  total_amount: number;
  pickup_lat?: number | string | null;
  pickup_lng?: number | string | null;
  pickup_text?: string | null;
  drop_lat?: number | string | null;
  drop_lng?: number | string | null;
  drop_text?: string | null;
  drop_branch_name?: string | null;
  drop_branch_phone?: string | null;
  drop_branch_hours?: string | null;
  selected_courier_name?: string | null;
};

const PICKED_STATUSES = new Set(['parcel_collected', 'at_courier_office', 'out_for_delivery']);
function toNum(v: number | string | null | undefined): number | null {
  if (v === null || v === undefined || v === '') return null;
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

function nextStepsFor(orderType: 'send' | 'receive', status: string): { label: string; status: string }[] {
  const dropLabel = orderType === 'send' ? 'Drop at courier office' : 'Hand over to customer';
  const map: Record<string, { label: string; status: string }[]> = {
    agent_assigned: [{ label: 'Start trip to pickup', status: 'agent_en_route_pickup' }],
    agent_en_route_pickup: [{ label: 'Parcel collected', status: 'parcel_collected' }],
    parcel_collected: [{ label: 'Start drop trip', status: 'out_for_delivery' }],
    out_for_delivery: [{ label: dropLabel, status: 'delivered' }],
  };
  return map[status] ?? [];
}

const FAILURE_REASONS = [
  'Customer not reachable / no-show',
  'Wrong address',
  'Parcel rejected by courier office',
  'Parcel damaged or unsafe to handle',
  'Other',
];

export default function JobPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const [order, setOrder] = useState<Order | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [otp, setOtp] = useState('');
  const [busy, setBusy] = useState(false);
  const [failOpen, setFailOpen] = useState(false);
  const [failReason, setFailReason] = useState(FAILURE_REASONS[0]);
  const [failNotes, setFailNotes] = useState('');

  const load = useCallback(async () => {
    try {
      const res = await api<{ assigned: Order[] }>('/agent/jobs');
      const found = res.assigned.find((o) => o.id === params.id);
      if (!found) {
        setError('Job not in your active list');
        return;
      }
      setOrder(found);
    } catch (e: any) {
      setError(e.message);
    }
  }, [params.id]);

  useEffect(() => { load(); }, [load]);

  const update = async (status: string, extra: Record<string, any> = {}) => {
    if (!order) return;
    const body: any = { status, ...extra };
    const otpNeeded =
      (order.order_type === 'send' && status === 'parcel_collected') ||
      (order.order_type === 'receive' && status === 'delivered');
    if (otpNeeded) {
      if (otp.length !== 4) { setError('Enter the 4-digit OTP from the customer'); return; }
      body.delivery_otp = otp;
    }
    setError(null);
    setBusy(true);
    try {
      await api(`/agent/jobs/${order.id}/update-status`, { method: 'POST', body });
      if (status === 'delivered' || status === 'failed') {
        router.push('/dashboard');
      } else {
        await load();
      }
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const submitFailure = () => {
    const reason = failReason === 'Other'
      ? (failNotes.trim() || 'Other')
      : (failNotes.trim() ? `${failReason} — ${failNotes.trim()}` : failReason);
    setFailOpen(false);
    update('failed', { failure_reason: reason });
  };

  if (error && !order) {
    return (
      <div>
        <p className="text-red-600 mb-3">{error}</p>
        <Link href="/dashboard" className="text-brand">← Back to dashboard</Link>
      </div>
    );
  }
  if (!order) return <div className="text-slate-500">Loading…</div>;

  const next = nextStepsFor(order.order_type, order.status);

  return (
    <div>
      <Link href="/dashboard" className="text-sm text-slate-500 hover:text-slate-900">← Dashboard</Link>

      <div className="bg-white border border-slate-200 rounded-xl p-5 my-4">
        <div className="flex items-start justify-between">
          <div>
            <div className="font-mono text-lg font-bold">{order.order_code}</div>
            <div className="text-sm text-slate-500">
              {order.order_type === 'send' ? '📤 Send' : '📥 Receive'} · ₹{(order.total_amount / 100).toFixed(0)}
            </div>
          </div>
          <span className="text-xs font-medium px-3 py-1 rounded-full bg-blue-50 text-blue-700">
            {STATUS_LABEL[order.status] ?? order.status}
          </span>
        </div>
      </div>

      <JobMap
        pickup={{
          lat: toNum(order.pickup_lat),
          lng: toNum(order.pickup_lng),
          label: order.pickup_text ?? 'Pickup',
        }}
        drop={{
          lat: toNum(order.drop_lat),
          lng: toNum(order.drop_lng),
          label: order.order_type === 'send'
            ? (order.drop_branch_name ?? order.selected_courier_name ?? 'Courier office')
            : (order.drop_text ?? 'Drop'),
        }}
        activeLeg={PICKED_STATUSES.has(order.status) ? 'drop' : 'pickup'}
      />

      {order.order_type === 'send' && (
        <div className="bg-white border border-slate-200 rounded-xl p-5 mb-4 text-sm">
          <div className="text-xs uppercase text-slate-500 font-semibold mb-2">
            Drop at courier office
          </div>
          <div className="font-medium">
            {order.drop_branch_name ?? order.selected_courier_name ?? 'Courier office'}
          </div>
          {order.drop_text && (
            <div className="text-slate-600 mt-1">{order.drop_text}</div>
          )}
          {order.drop_branch_hours && (
            <div className="text-xs text-slate-500 mt-1">Hours: {order.drop_branch_hours}</div>
          )}
          {order.drop_branch_phone && (
            <a href={`tel:${order.drop_branch_phone}`}
              className="inline-block mt-3 text-brand text-sm font-medium">📞 Call office</a>
          )}
        </div>
      )}

      {order.order_type === 'send' && order.recipient_name && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-5 mb-4 text-sm">
          <div className="text-xs uppercase text-amber-900 font-semibold mb-2">
            Hand-over details — read out at the counter
          </div>
          <div className="font-medium text-slate-900">{order.recipient_name}</div>
          <div className="text-slate-700">{order.recipient_phone}</div>
          <div className="text-slate-700 mt-2 whitespace-pre-line">{order.delivery_address}</div>
          <p className="text-xs text-amber-900 mt-3">
            Give these recipient details to the courier office so they can print the shipping label.
          </p>
          {order.recipient_phone && (
            <a href={`tel:${order.recipient_phone}`}
              className="inline-block mt-3 text-brand text-sm font-medium">📞 Call recipient</a>
          )}
        </div>
      )}

      {order.order_type === 'receive' && order.source_tracking_id && (
        <div className="bg-white border border-slate-200 rounded-xl p-5 mb-4 text-sm">
          <div className="text-xs uppercase text-slate-500 font-semibold mb-2">Pickup tracking</div>
          <div className="font-mono text-base font-medium">{order.source_tracking_id}</div>
          <button
            onClick={() => downloadFile(`/orders/${order.id}/authorization.pdf`, `authorization-${order.order_code}.pdf`).catch((e) => setError(e.message))}
            className="mt-3 w-full border border-slate-300 rounded-lg py-2 text-sm font-medium hover:bg-slate-50"
          >
            📄 Download authorization letter
          </button>
        </div>
      )}

      {((order.order_type === 'send' && order.status === 'agent_en_route_pickup') ||
        (order.order_type === 'receive' && order.status === 'out_for_delivery')) && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-5 mb-4">
          <label className="block text-xs uppercase text-amber-900 font-semibold mb-2">
            4-digit OTP from customer
          </label>
          <input value={otp} inputMode="numeric" maxLength={4}
            onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 4))}
            placeholder="0000"
            className="w-full border border-amber-300 bg-white rounded-lg px-3 py-3 text-center text-2xl tracking-widest font-mono" />
          <p className="text-xs text-amber-800 mt-2">
            {order.order_type === 'send'
              ? 'Ask the customer for their OTP at pickup — required to confirm the parcel has changed hands.'
              : 'Ask the customer for their OTP at delivery — required to mark the parcel handed over.'}
          </p>
        </div>
      )}

      {error && <p className="text-red-600 text-sm mb-3">{error}</p>}

      <div className="space-y-2">
        {next.map((n) => (
          <button key={n.status} onClick={() => update(n.status)} disabled={busy}
            className="w-full bg-brand text-white font-semibold py-3 rounded-lg hover:bg-brand-dark disabled:opacity-60">
            {busy ? 'Updating…' : n.label}
          </button>
        ))}
      </div>

      {order.status !== 'agent_assigned' && (
        <button onClick={() => setFailOpen(true)} disabled={busy}
          className="w-full mt-6 border border-red-300 text-red-700 rounded-lg py-2.5 font-medium hover:bg-red-50 disabled:opacity-60">
          Mark failed
        </button>
      )}

      {failOpen && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 md:items-center">
          <div className="w-full md:max-w-md bg-white rounded-t-3xl md:rounded-3xl shadow-2xl">
            <div className="px-6 py-4 border-b border-slate-200">
              <div className="font-semibold text-lg">Why did this fail?</div>
              <div className="text-xs text-slate-500 mt-0.5">Admin will review failed orders.</div>
            </div>
            <div className="px-6 py-4 space-y-2">
              {FAILURE_REASONS.map((r) => (
                <label key={r} className={`flex items-center gap-3 p-3 rounded-lg border cursor-pointer ${
                  failReason === r ? 'border-red-400 bg-red-50' : 'border-slate-200'
                }`}>
                  <input type="radio" name="reason" checked={failReason === r}
                    onChange={() => setFailReason(r)} />
                  <span className="text-sm">{r}</span>
                </label>
              ))}
              <textarea value={failNotes} onChange={(e) => setFailNotes(e.target.value)}
                placeholder={failReason === 'Other' ? 'Required: describe what happened' : 'Optional details'}
                rows={2}
                className="w-full mt-2 border border-slate-200 rounded-lg px-3 py-2 text-sm" />
            </div>
            <div className="px-6 py-4 grid grid-cols-2 gap-2 border-t border-slate-200">
              <button onClick={() => setFailOpen(false)} disabled={busy}
                className="border border-slate-300 rounded-lg py-2.5 font-medium hover:bg-slate-50">
                Cancel
              </button>
              <button onClick={submitFailure} disabled={busy || (failReason === 'Other' && !failNotes.trim())}
                className="bg-red-600 text-white rounded-lg py-2.5 font-semibold hover:bg-red-700 disabled:opacity-60">
                {busy ? 'Submitting…' : 'Mark failed'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
