'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { api, downloadFile, STATUS_LABEL } from '../../../../lib/api';
import AgentMap from '../../../../components/AgentMap';
import Pusher from 'pusher-js';

const PUSHER_KEY = process.env.NEXT_PUBLIC_PUSHER_KEY ?? 'your_pusher_key';
const PUSHER_CLUSTER = process.env.NEXT_PUBLIC_PUSHER_CLUSTER ?? 'ap2';

type HistoryEntry = { status: string; notes?: string | null; changed_by_type: string; created_at: string };
type AgentInfo = { name: string; phone: string; lat: number | null; lng: number | null };
type Order = {
  id: string; order_code: string; order_type: 'send' | 'receive'; status: string;
  parcel_type?: string | null; parcel_weight_kg?: string | null; parcel_description?: string | null;
  recipient_name?: string | null; recipient_phone?: string | null; delivery_address?: string | null;
  source_tracking_id?: string | null;
  courier_charge: number; service_fee: number; gst_amount: number; total_amount: number;
  delivery_otp?: string | null; payment_status: string;
  failure_reason?: string | null;
  refund_amount_paise?: number | null;
  created_at: string;
  history: HistoryEntry[];
  agent?: AgentInfo | null;
};

const TRACKING_STATES = new Set([
  'agent_assigned',
  'agent_en_route_pickup',
  'parcel_collected',
  'out_for_delivery',
]);

const STEPS = ['pending', 'agent_assigned', 'agent_en_route_pickup', 'parcel_collected', 'out_for_delivery', 'delivered'];
const TERMINAL = new Set(['delivered', 'cancelled', 'failed']);

export default function OrderDetailPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const [order, setOrder] = useState<Order | null>(null);
  const [liveLocation, setLiveLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [cancelling, setCancelling] = useState(false);
  const [actionBusy, setActionBusy] = useState(false);

  const load = () => {
    api<Order>(`/orders/${params.id}`).then(setOrder).catch((e) => setError(e.message));
  };
  useEffect(() => { load(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, [params.id]);
  useEffect(() => {
    if (!order || TERMINAL.has(order.status)) return;
    const t = setInterval(load, 10000);
    return () => clearInterval(t);
    /* eslint-disable-next-line react-hooks/exhaustive-deps */
  }, [order?.status]);

  useEffect(() => {
    if (!order || TERMINAL.has(order.status)) return;

    console.log(`[pusher] Connecting to order-${order.id} using key: ${PUSHER_KEY}`);
    const pusher = new Pusher(PUSHER_KEY, {
      cluster: PUSHER_CLUSTER,
    });

    const channel = pusher.subscribe(`order-${order.id}`);
    
    channel.bind('location_received', (data: { lat: number; lng: number }) => {
      console.log('[pusher] location_received', data);
      setLiveLocation({ lat: data.lat, lng: data.lng });
    });

    channel.bind('status_changed', (data: { status: string }) => {
      console.log('[pusher] status_changed', data);
      load();
    });

    return () => {
      channel.unbind_all();
      pusher.unsubscribe(`order-${order.id}`);
      pusher.disconnect();
    };
  }, [order?.id, order?.status]);

  if (error) return <div className="text-red-600">{error}</div>;
  if (!order) return <div className="text-slate-500">Loading…</div>;

  const retry = async (when: 'today' | 'tomorrow') => {
    setActionBusy(true);
    try {
      await api(`/orders/${order!.id}/retry`, { method: 'POST', body: { when } });
      load();
    } catch (e: any) { alert(e.message); }
    finally { setActionBusy(false); }
  };

  const requestRefund = async () => {
    if (!confirm('Request a refund? Admin will review and process it.')) return;
    setActionBusy(true);
    try {
      await api(`/orders/${order!.id}/request-refund`, { method: 'POST', body: {} });
      load();
    } catch (e: any) { alert(e.message); }
    finally { setActionBusy(false); }
  };

  const cancel = async () => {
    if (!confirm('Cancel this order?')) return;
    setCancelling(true);
    try {
      await api(`/orders/${order.id}/cancel`, { method: 'POST', body: { reason: 'user requested' } });
      load();
    } catch (e: any) {
      alert(e.message);
    } finally {
      setCancelling(false);
    }
  };

  const steps = STEPS;
  const currentIdx = steps.indexOf(order.status);
  const cancelled = order.status === 'cancelled';

  return (
    <div className="max-w-2xl mx-auto">
      <div className="flex items-center gap-2 mb-6 text-sm text-slate-500">
        <Link href="/home/orders" className="hover:text-slate-900">← My orders</Link>
      </div>

      <div className="bg-white border border-slate-200 rounded-xl p-5 mb-4">
        <div className="flex items-start justify-between mb-2">
          <div>
            <div className="font-mono text-lg font-bold">{order.order_code}</div>
            <div className="text-sm text-slate-500">
              {order.order_type === 'send' ? '📤 Send' : '📥 Receive'} ·
              Booked {new Date(order.created_at).toLocaleString()}
            </div>
          </div>
          <span className={`text-xs font-medium px-3 py-1 rounded-full ${
            cancelled ? 'bg-red-50 text-red-700' :
            order.status === 'delivered' ? 'bg-green-50 text-green-700' :
            'bg-blue-50 text-blue-700'
          }`}>
            {STATUS_LABEL[order.status] ?? order.status}
          </span>
        </div>
      </div>

      {order.status === 'failed' && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-5 mb-4">
          <div className="font-semibold text-red-900">Order couldn't be completed</div>
          {order.failure_reason && (
            <div className="text-sm text-red-800 mt-1">Reason: {order.failure_reason}</div>
          )}

          {order.payment_status === 'paid' && (
            <>
              <div className="text-sm text-red-800 mt-3">What would you like to do?</div>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 mt-3">
                <button onClick={() => retry('today')} disabled={actionBusy}
                  className="bg-brand text-white rounded-lg py-2.5 font-medium hover:bg-brand-dark disabled:opacity-60">
                  Retry today
                </button>
                <button onClick={() => retry('tomorrow')} disabled={actionBusy}
                  className="bg-brand text-white rounded-lg py-2.5 font-medium hover:bg-brand-dark disabled:opacity-60">
                  Retry tomorrow
                </button>
                <button onClick={requestRefund} disabled={actionBusy}
                  className="border border-red-300 text-red-700 rounded-lg py-2.5 font-medium hover:bg-red-100 disabled:opacity-60">
                  Request refund
                </button>
              </div>
            </>
          )}

          {order.payment_status === 'refund_requested' && (
            <div className="mt-3 text-sm text-amber-800 bg-amber-50 border border-amber-200 rounded-lg p-3">
              Refund requested — our team is reviewing and will process it shortly.
            </div>
          )}

          {order.payment_status === 'refunded' && (
            <div className="mt-3 text-sm text-green-800 bg-green-50 border border-green-200 rounded-lg p-3">
              Refunded ₹{((order.refund_amount_paise ?? 0) / 100).toFixed(0)} to your original payment method.
            </div>
          )}
        </div>
      )}

      {TRACKING_STATES.has(order.status) && order.agent?.lat != null && order.agent.lng != null && (
        <AgentMap
          agent={{
            name: order.agent.name,
            lat: liveLocation?.lat ?? Number(order.agent.lat),
            lng: liveLocation?.lng ?? Number(order.agent.lng),
          }}
        />
      )}

      {!cancelled && order.payment_status !== 'paid' && (
        <Link href={`/home/orders/${order.id}/pay`}
          className="block bg-brand text-white rounded-xl p-5 mb-4 hover:bg-brand-dark">
          <div className="flex items-center justify-between">
            <div>
              <div className="font-semibold">Payment pending</div>
              <div className="text-sm text-blue-100 mt-0.5">
                Pay ₹{(order.total_amount / 100).toFixed(0)} to dispatch this order
              </div>
            </div>
            <div className="text-2xl">→</div>
          </div>
        </Link>
      )}

      {!TERMINAL.has(order.status) && (
        <div className="bg-white border border-slate-200 rounded-xl p-5 mb-4">
          <h3 className="font-semibold mb-4">Progress</h3>
          <div className="space-y-3">
            {steps.map((s, i) => {
              const done = i <= currentIdx;
              const active = i === currentIdx;
              return (
                <div key={s} className="flex items-center gap-3">
                  <div className={`h-7 w-7 rounded-full flex items-center justify-center text-xs ${
                    done ? 'bg-brand text-white' : 'bg-slate-100 text-slate-400'
                  } ${active ? 'ring-4 ring-blue-100' : ''}`}>
                    {done ? '✓' : i + 1}
                  </div>
                  <div className={done ? 'text-slate-900 font-medium' : 'text-slate-400'}>
                    {STATUS_LABEL[s] ?? s}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {!TERMINAL.has(order.status) && order.delivery_otp && (() => {
        // Send: customer hands parcel + OTP to agent at pickup. Show until pickup is done.
        // Receive: customer reads OTP to agent at delivery. Show once it's en route.
        const showOtp = order.order_type === 'send'
          ? !['parcel_collected', 'out_for_delivery'].includes(order.status)
          : order.status === 'out_for_delivery';
        if (!showOtp) return null;
        return (
          <div className="bg-amber-50 border border-amber-200 rounded-xl p-5 mb-4">
            <div className="text-sm text-amber-900 font-medium mb-1">Handover OTP</div>
            <div className="text-3xl font-bold tracking-widest font-mono text-amber-900">{order.delivery_otp}</div>
            <div className="text-xs text-amber-800 mt-2">
              {order.order_type === 'send'
                ? 'Read this code to the agent at pickup to confirm handover.'
                : 'Read this code to the agent at delivery to confirm handover.'}
            </div>
          </div>
        );
      })()}

      <div className="bg-white border border-slate-200 rounded-xl p-5 mb-4 text-sm">
        <h3 className="font-semibold mb-3">Details</h3>
        <div className="space-y-2">
          {order.order_type === 'send' ? (
            <>
              <Row label="Parcel">
                {order.parcel_type} · {order.parcel_weight_kg} kg
                {order.parcel_description ? ` · ${order.parcel_description}` : ''}
              </Row>
              <Row label="Recipient">{order.recipient_name} ({order.recipient_phone})</Row>
              <Row label="Delivery">{order.delivery_address}</Row>
            </>
          ) : (
            <>
              <Row label="Tracking ID"><span className="font-mono">{order.source_tracking_id}</span></Row>
              <button
                onClick={() => downloadFile(`/orders/${order.id}/authorization.pdf`, `authorization-${order.order_code}.pdf`).catch((e) => alert(e.message))}
                className="mt-3 w-full border border-slate-300 rounded-lg py-2 text-sm font-medium hover:bg-slate-50"
              >
                📄 Download authorization letter (PDF)
              </button>
            </>
          )}
        </div>
      </div>

      <div className="bg-white border border-slate-200 rounded-xl p-5 mb-4 text-sm">
        <h3 className="font-semibold mb-3">Payment</h3>
        <div className="space-y-1">
          {order.courier_charge > 0 && (
            <div className="flex justify-between"><span className="text-slate-600">Courier charge</span><span>₹{(order.courier_charge / 100).toFixed(0)}</span></div>
          )}
          <div className="flex justify-between"><span className="text-slate-600">Service fee</span><span>₹{(order.service_fee / 100).toFixed(0)}</span></div>
          <div className="flex justify-between"><span className="text-slate-600">GST</span><span>₹{(order.gst_amount / 100).toFixed(0)}</span></div>
          <div className="border-t border-slate-200 pt-2 mt-2 flex justify-between font-bold">
            <span>Total</span><span>₹{(order.total_amount / 100).toFixed(0)}</span>
          </div>
          <div className="text-xs text-slate-500 mt-1">Payment status: {order.payment_status}</div>
        </div>
      </div>

      {order.history.length > 0 && (
        <div className="bg-white border border-slate-200 rounded-xl p-5 mb-4">
          <h3 className="font-semibold mb-3">Activity</h3>
          <div className="space-y-3">
            {order.history.slice().reverse().map((h, i) => (
              <div key={i} className="flex gap-3 text-sm">
                <div className="text-slate-400 text-xs w-24 shrink-0 pt-0.5">
                  {new Date(h.created_at).toLocaleString()}
                </div>
                <div>
                  <div className="font-medium">{STATUS_LABEL[h.status] ?? h.status}</div>
                  {h.notes && <div className="text-xs text-slate-500">{h.notes}</div>}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {!TERMINAL.has(order.status) && (
        <button onClick={cancel} disabled={cancelling}
          className="w-full border border-red-300 text-red-700 rounded-lg py-2.5 font-medium hover:bg-red-50 disabled:opacity-60">
          {cancelling ? 'Cancelling…' : 'Cancel order'}
        </button>
      )}
    </div>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex justify-between gap-4">
      <span className="text-slate-500">{label}</span>
      <span className="text-right">{children}</span>
    </div>
  );
}
