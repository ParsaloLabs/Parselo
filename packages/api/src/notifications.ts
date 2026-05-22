import { env } from './env';
import { query } from './db';

const DEV = !env.MSG91_AUTH_KEY;

// Generic transactional SMS via MSG91 Flow API.
// In dev mode (no auth key) we log to stdout so the full flow is visible without a paid integration.
export async function sendSms(phone: string, message: string) {
  if (DEV) {
    console.log(`[sms:dev] → ${phone}\n  ${message}`);
    return;
  }
  // MSG91 Flow API requires a DLT-registered template. The message is templated server-side
  // by Flow ID + variable bindings; we send the body verbatim as the single VAR1 substitution.
  // Operator should configure a generic "{{var}}" template and put its flow_id in MSG91_TXN_TEMPLATE_ID.
  const body = {
    flow_id: env.MSG91_TXN_TEMPLATE_ID,
    sender: env.MSG91_SENDER_ID,
    short_url: '0',
    mobiles: phone.replace(/^\+?/, ''),
    VAR1: message,
  };
  try {
    await fetch('https://control.msg91.com/api/v5/flow/', {
      method: 'POST',
      headers: { authkey: env.MSG91_AUTH_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  } catch (e) {
    console.warn('[sms] send failed', e);
  }
}

type OrderEvent =
  | 'paid'
  | 'agent_assigned'
  | 'agent_en_route_pickup'
  | 'parcel_collected'
  | 'out_for_delivery'
  | 'delivered'
  | 'cancelled'
  | 'failed';

type OrderRow = {
  id: string; order_code: string; order_type: 'send' | 'receive';
  total_amount: number; delivery_otp: string;
  user_phone: string; agent_phone?: string | null; agent_name?: string | null;
};

async function loadOrder(orderId: string): Promise<OrderRow | null> {
  const { rows } = await query<OrderRow>(
    `SELECT o.id, o.order_code, o.order_type, o.total_amount, o.delivery_otp,
            u.phone AS user_phone,
            a.phone AS agent_phone, a.full_name AS agent_name
       FROM orders o
       JOIN users u ON u.id = o.user_id
       LEFT JOIN agents a ON a.id = o.agent_id
      WHERE o.id = $1`,
    [orderId],
  );
  return rows[0] ?? null;
}

const RECEIVE = 'receive';

function customerMessage(o: OrderRow, event: OrderEvent): string | null {
  const code = o.order_code;
  switch (event) {
    case 'paid':
      return `ParcelPal: ${code} booked. We're finding an agent. Track at parcelpal.in`;
    case 'agent_assigned':
      return `ParcelPal: ${o.agent_name ?? 'Agent'} (${o.agent_phone ?? '—'}) is assigned to ${code}. ` +
        (o.order_type === RECEIVE
          ? `They'll pick up your parcel from the courier office.`
          : `Keep your parcel + OTP ${o.delivery_otp} ready for pickup.`);
    case 'agent_en_route_pickup':
      return `ParcelPal: Agent on the way for ${code}. ` +
        (o.order_type === RECEIVE ? `Heading to the courier office.` : `Share OTP ${o.delivery_otp} at pickup.`);
    case 'parcel_collected':
      return `ParcelPal: Parcel collected for ${code}. ` +
        (o.order_type === RECEIVE ? `Heading to your address now.` : `It's on the way to the courier office.`);
    case 'out_for_delivery':
      return o.order_type === RECEIVE
        ? `ParcelPal: Agent is on the way to deliver ${code}. Share OTP ${o.delivery_otp} at handover.`
        : `ParcelPal: ${code} is on the way to the courier office.`;
    case 'delivered':
      return o.order_type === RECEIVE
        ? `ParcelPal: ${code} delivered. Hope to serve you again!`
        : `ParcelPal: ${code} dropped at the courier office. Tracking ID will follow on courier SMS.`;
    case 'cancelled':
      return `ParcelPal: ${code} was cancelled. Refund (if applicable) is processing.`;
    case 'failed':
      return `ParcelPal: ${code} could not be completed. Open the app to retry today, retry tomorrow, or request a refund.`;
    default:
      return null;
  }
}

function agentMessage(o: OrderRow, event: OrderEvent): string | null {
  if (event === 'agent_assigned') {
    return `ParcelPal: You're assigned to ${o.order_code} (${o.order_type}). Open the agent app for details.`;
  }
  return null;
}

export async function notifyOrderEvent(orderId: string, event: OrderEvent) {
  try {
    const o = await loadOrder(orderId);
    if (!o) return;
    const cust = customerMessage(o, event);
    if (cust) await sendSms(o.user_phone, cust);
    const agt = agentMessage(o, event);
    if (agt && o.agent_phone) await sendSms(o.agent_phone, agt);
  } catch (e) {
    console.warn('[notify] failed', e);
  }
}

// Broadcast a "new job available" ping to all currently-online agents.
// Used when an order becomes paid + dispatchable.
export async function notifyAgentsNewJob(orderId: string) {
  try {
    const { rows: orderRows } = await query<{ order_code: string; order_type: string }>(
      `SELECT order_code, order_type FROM orders WHERE id = $1`, [orderId],
    );
    if (orderRows.length === 0) return;
    const o = orderRows[0];
    const { rows: agents } = await query<{ phone: string }>(
      `SELECT phone FROM agents WHERE is_online = TRUE AND is_active = TRUE`,
    );
    const msg = `ParcelPal: New ${o.order_type} job ${o.order_code} available. Open the app to accept.`;
    await Promise.all(agents.map((a) => sendSms(a.phone, msg)));
  } catch (e) {
    console.warn('[notify:broadcast] failed', e);
  }
}
