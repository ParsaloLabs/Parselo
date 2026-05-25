import { Router } from 'express';
import crypto from 'crypto';
import express from 'express';
import Razorpay from 'razorpay';
import { z } from 'zod';
import { query } from '../db';
import { requireAuth } from '../auth';
import { env } from '../env';
import { notifyOrderEvent } from '../notifications';
import { dispatchOrder } from '../dispatch';

const router = Router();

const razorpay = env.RAZORPAY_KEY_ID && env.RAZORPAY_KEY_SECRET
  ? new Razorpay({ key_id: env.RAZORPAY_KEY_ID, key_secret: env.RAZORPAY_KEY_SECRET })
  : null;

const DEV_MODE = !razorpay;

// Create a Razorpay order against an existing Parsalo order.
// Returns { key_id, razorpay_order_id, amount, currency, dev_mode }.
router.post('/orders/:id/create', requireAuth(['user']), async (req, res) => {
  const userId = (req.principal as any).userId;
  const { rows } = await query<{
    id: string; order_code: string; total_amount: number;
    payment_status: string; razorpay_order_id?: string | null;
  }>(
    `SELECT id, order_code, total_amount, payment_status, payment_id AS razorpay_order_id
       FROM orders WHERE id = $1 AND user_id = $2`,
    [req.params.id, userId],
  );
  if (rows.length === 0) return res.status(404).json({ error: 'not_found' });
  const order = rows[0];
  if (order.payment_status === 'paid') {
    return res.status(400).json({ error: 'already_paid' });
  }

  if (DEV_MODE) {
    return res.json({
      dev_mode: true,
      amount: order.total_amount,
      currency: 'INR',
      order_code: order.order_code,
    });
  }

  try {
    const rp = await razorpay!.orders.create({
      amount: order.total_amount,
      currency: 'INR',
      receipt: order.order_code,
      notes: { parsalo_order_id: order.id, user_id: userId },
    });
    await query(`UPDATE orders SET payment_id = $1, updated_at = NOW() WHERE id = $2`, [rp.id, order.id]);
    return res.json({
      dev_mode: false,
      key_id: env.RAZORPAY_KEY_ID,
      razorpay_order_id: rp.id,
      amount: order.total_amount,
      currency: 'INR',
      order_code: order.order_code,
    });
  } catch (e: any) {
    return res.status(502).json({ error: 'razorpay_failed', message: e?.message });
  }
});

// Verify the signature returned by Razorpay Checkout and mark the order paid.
const verifySchema = z.object({
  parsalo_order_id: z.string().uuid(),
  razorpay_order_id: z.string().optional().nullable(),
  razorpay_payment_id: z.string().optional().nullable(),
  razorpay_signature: z.string().optional().nullable(),
});

router.post('/verify', requireAuth(['user']), async (req, res) => {
  const userId = (req.principal as any).userId;
  const parsed = verifySchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input' });
  const { parsalo_order_id, razorpay_order_id, razorpay_payment_id, razorpay_signature } = parsed.data;

  const { rows } = await query<{ id: string; payment_status: string }>(
    `SELECT id, payment_status FROM orders WHERE id = $1 AND user_id = $2`,
    [parsalo_order_id, userId],
  );
  if (rows.length === 0) return res.status(404).json({ error: 'not_found' });

  if (DEV_MODE) {
    await query(
      `UPDATE orders SET payment_status = 'paid', payment_id = 'dev_mock_payment', updated_at = NOW() WHERE id = $1`,
      [parsalo_order_id],
    );
    notifyOrderEvent(parsalo_order_id, 'paid');
    void dispatchOrder(parsalo_order_id);
    return res.json({ ok: true, dev_mode: true });
  }

  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    return res.status(400).json({ error: 'missing_signature' });
  }
  const expected = crypto
    .createHmac('sha256', env.RAZORPAY_KEY_SECRET)
    .update(`${razorpay_order_id}|${razorpay_payment_id}`)
    .digest('hex');
  if (expected !== razorpay_signature) {
    return res.status(401).json({ error: 'signature_mismatch' });
  }

  await query(
    `UPDATE orders SET payment_status = 'paid', payment_id = $1, updated_at = NOW() WHERE id = $2`,
    [razorpay_payment_id, parsalo_order_id],
  );
  notifyOrderEvent(parsalo_order_id, 'paid');
  void dispatchOrder(parsalo_order_id);
  res.json({ ok: true });
});

// Webhook — independent confirmation for cases where the user closes the page after paying.
// Mounted with raw body to verify the HMAC.
export const webhookHandler = [
  express.raw({ type: 'application/json' }),
  async (req: express.Request, res: express.Response) => {
    if (DEV_MODE) return res.json({ ok: true, dev_mode: true });
    const sig = String(req.headers['x-razorpay-signature'] ?? '');
    const expected = crypto
      .createHmac('sha256', env.RAZORPAY_WEBHOOK_SECRET)
      .update(req.body)
      .digest('hex');
    if (expected !== sig) return res.status(401).json({ error: 'signature_mismatch' });

    let payload: any;
    try { payload = JSON.parse(req.body.toString('utf8')); }
    catch { return res.status(400).json({ error: 'invalid_json' }); }

    const event = payload.event;
    const entity = payload.payload?.payment?.entity ?? payload.payload?.order?.entity;
    const ppOrderId = entity?.notes?.parsalo_order_id;
    if (!ppOrderId) return res.json({ ok: true, ignored: true });

    if (event === 'payment.captured' || event === 'order.paid') {
      const { rowCount } = await query(
        `UPDATE orders SET payment_status = 'paid', payment_id = $1, updated_at = NOW()
           WHERE id = $2 AND payment_status <> 'paid'`,
        [entity.id, ppOrderId],
      );
      if ((rowCount ?? 0) > 0) {
        notifyOrderEvent(ppOrderId, 'paid');
        void dispatchOrder(ppOrderId);
      }
    } else if (event === 'payment.failed') {
      await query(
        `UPDATE orders SET payment_status = 'failed', updated_at = NOW()
           WHERE id = $1 AND payment_status <> 'paid'`,
        [ppOrderId],
      );
    }
    res.json({ ok: true });
  },
];

export default router;
