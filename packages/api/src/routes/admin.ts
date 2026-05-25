import { Router } from 'express';
import bcrypt from 'bcryptjs';
import Razorpay from 'razorpay';
import { z } from 'zod';
import { query } from '../db';
import { requireAuth } from '../auth';
import { env } from '../env';
import { notifyOrderEvent } from '../notifications';

const router = Router();

const razorpay = env.RAZORPAY_KEY_ID && env.RAZORPAY_KEY_SECRET
  ? new Razorpay({ key_id: env.RAZORPAY_KEY_ID, key_secret: env.RAZORPAY_KEY_SECRET })
  : null;

router.get('/orders', requireAuth(['admin']), async (req, res) => {
  const status = req.query.status as string | undefined;
  const limit = Math.min(Number(req.query.limit ?? 50), 200);
  const params: any[] = [];
  let where = '';
  if (status) {
    params.push(status);
    where = `WHERE status = $${params.length}`;
  }
  params.push(limit);
  const { rows } = await query(
    `SELECT o.*, u.phone AS user_phone, u.full_name AS user_name, a.full_name AS agent_name
       FROM orders o
       LEFT JOIN users u ON u.id = o.user_id
       LEFT JOIN agents a ON a.id = o.agent_id
       ${where}
       ORDER BY o.created_at DESC LIMIT $${params.length}`,
    params,
  );
  res.json(rows);
});

router.post('/orders/:id/assign-agent', requireAuth(['admin']), async (req, res) => {
  const adminId = (req.principal as any).adminId;
  const parsed = z.object({ agent_id: z.string().uuid() }).safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input' });
  const { rows } = await query(
    `UPDATE orders SET agent_id = $1, status = 'agent_assigned', updated_at = NOW()
       WHERE id = $2 AND status = 'pending'
       RETURNING *`,
    [parsed.data.agent_id, req.params.id],
  );
  if (rows.length === 0) return res.status(409).json({ error: 'cannot_assign' });
  await query(
    `INSERT INTO order_status_history (order_id, status, changed_by_type, changed_by_id) VALUES ($1, 'agent_assigned', 'admin', $2)`,
    [req.params.id, adminId],
  );
  res.json(rows[0]);
});

router.get('/agents', requireAuth(['admin']), async (_req, res) => {
  const { rows } = await query(
    `SELECT id, phone, full_name, vehicle_type, vehicle_number, status, is_online, is_active, rating, total_deliveries, current_lat, current_lng
       FROM agents WHERE status = 'approved' ORDER BY created_at DESC`,
  );
  res.json(rows);
});

router.post('/agents', requireAuth(['admin']), async (req, res) => {
  const schema = z.object({
    phone: z.string().min(10),
    full_name: z.string().min(1),
    email: z.string().email().optional(),
    password: z.string().min(6),
    vehicle_type: z.enum(['bike', 'scooter']).optional(),
    vehicle_number: z.string().optional(),
  });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input' });
  const a = parsed.data;
  const hash = await bcrypt.hash(a.password, 10);
  const { rows } = await query(
    `INSERT INTO agents (phone, full_name, email, password_hash, vehicle_type, vehicle_number, status, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, 'approved', TRUE) RETURNING id, phone, full_name`,
    [a.phone, a.full_name, a.email ?? null, hash, a.vehicle_type ?? null, a.vehicle_number ?? null],
  );
  res.status(201).json(rows[0]);
});

router.get('/agents/pending', requireAuth(['admin']), async (_req, res) => {
  const { rows } = await query(
    `SELECT id, phone, full_name, email, vehicle_type, vehicle_number, dl_number, city, status, rejection_reason, created_at
       FROM agents WHERE status IN ('pending', 'rejected') ORDER BY created_at DESC`,
  );
  res.json(rows);
});

router.post('/agents/:id/approve', requireAuth(['admin']), async (req, res) => {
  const adminId = (req.principal as any).adminId;
  const { rows } = await query(
    `UPDATE agents
        SET status = 'approved', is_active = TRUE, rejection_reason = NULL,
            reviewed_at = NOW(), reviewed_by = $1
      WHERE id = $2 AND status IN ('pending', 'rejected')
      RETURNING id, status`,
    [adminId, req.params.id],
  );
  if (rows.length === 0) return res.status(409).json({ error: 'cannot_approve' });
  res.json(rows[0]);
});

router.post('/agents/:id/reject', requireAuth(['admin']), async (req, res) => {
  const adminId = (req.principal as any).adminId;
  const parsed = z.object({ reason: z.string().trim().min(1).max(500) }).safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input' });
  const { rows } = await query(
    `UPDATE agents
        SET status = 'rejected', is_active = FALSE, rejection_reason = $1,
            reviewed_at = NOW(), reviewed_by = $2
      WHERE id = $3 AND status = 'pending'
      RETURNING id, status`,
    [parsed.data.reason, adminId, req.params.id],
  );
  if (rows.length === 0) return res.status(409).json({ error: 'cannot_reject' });
  res.json(rows[0]);
});

// Re-queue a failed order. `when='today'` makes it immediately available again;
// `when='tomorrow'` schedules for next morning IST.
router.post('/orders/:id/retry', requireAuth(['admin']), async (req, res) => {
  const adminId = (req.principal as any).adminId;
  const parsed = z.object({ when: z.enum(['today', 'tomorrow']) }).safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input' });
  const retryAtSql = parsed.data.when === 'today'
    ? 'NULL'
    : `(DATE_TRUNC('day', (NOW() AT TIME ZONE 'Asia/Kolkata')) + INTERVAL '1 day 9 hours') AT TIME ZONE 'Asia/Kolkata'`;
  const { rows } = await query(
    `UPDATE orders
        SET status = 'pending', agent_id = NULL,
            retry_at = ${retryAtSql},
            failure_reason = NULL,
            updated_at = NOW()
      WHERE id = $1 AND status = 'failed'
      RETURNING id, retry_at`,
    [req.params.id],
  );
  if (rows.length === 0) return res.status(409).json({ error: 'not_failed' });
  await query(
    `INSERT INTO order_status_history (order_id, status, notes, changed_by_type, changed_by_id)
       VALUES ($1, 'pending', $2, 'admin', $3)`,
    [req.params.id, `admin re-queued (${parsed.data.when})`, adminId],
  );
  res.json({ ok: true, retry_at: rows[0].retry_at });
});

// Refund a failed order — full or partial. Razorpay refund in prod, short-circuit in dev.
router.post('/orders/:id/refund', requireAuth(['admin']), async (req, res) => {
  const adminId = (req.principal as any).adminId;
  const parsed = z.object({ amount_paise: z.number().int().positive().optional() }).safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input' });

  const { rows } = await query<{
    id: string; total_amount: number; payment_id: string | null; payment_status: string; status: string;
  }>(
    `SELECT id, total_amount, payment_id, payment_status, status FROM orders WHERE id = $1`,
    [req.params.id],
  );
  if (rows.length === 0) return res.status(404).json({ error: 'not_found' });
  const order = rows[0];
  if (order.status !== 'failed') return res.status(409).json({ error: 'not_failed' });
  if (order.payment_status === 'refunded') return res.status(409).json({ error: 'already_refunded' });

  const amount = parsed.data.amount_paise ?? order.total_amount;
  if (amount > order.total_amount) return res.status(400).json({ error: 'amount_exceeds_total' });

  if (razorpay && order.payment_status === 'paid' && order.payment_id && order.payment_id !== 'dev_mock_payment') {
    try {
      await razorpay.payments.refund(order.payment_id, { amount, speed: 'normal' });
    } catch (e: any) {
      return res.status(502).json({ error: 'razorpay_refund_failed', message: e?.message });
    }
  }

  await query(
    `UPDATE orders SET payment_status = 'refunded', refund_amount_paise = $1, updated_at = NOW() WHERE id = $2`,
    [amount, order.id],
  );
  await query(
    `INSERT INTO order_status_history (order_id, status, notes, changed_by_type, changed_by_id)
       VALUES ($1, 'failed', $2, 'admin', $3)`,
    [order.id, `refunded ${amount} paise${amount === order.total_amount ? ' (full)' : ' (partial)'}`, adminId],
  );
  notifyOrderEvent(order.id, 'cancelled');
  res.json({ ok: true, refund_amount_paise: amount });
});

router.get('/dashboard-stats', requireAuth(['admin']), async (_req, res) => {
  const today = `DATE_TRUNC('day', NOW())`;
  const { rows } = await query<{
    orders_today: number; active_orders: number; agents_online: number;
    revenue_today_paise: number; failed_count: number; refund_requested_count: number;
  }>(
    `SELECT
      (SELECT COUNT(*)::int FROM orders WHERE created_at >= ${today}) AS orders_today,
      (SELECT COUNT(*)::int FROM orders WHERE status NOT IN ('delivered','cancelled','failed')) AS active_orders,
      (SELECT COUNT(*)::int FROM agents WHERE is_online = TRUE) AS agents_online,
      (SELECT COALESCE(SUM(total_amount), 0)::int FROM orders WHERE created_at >= ${today} AND payment_status = 'paid') AS revenue_today_paise,
      (SELECT COUNT(*)::int FROM orders WHERE status = 'failed' AND (payment_status IS NULL OR payment_status NOT IN ('refunded','refund_requested'))) AS failed_count,
      (SELECT COUNT(*)::int FROM orders WHERE payment_status = 'refund_requested') AS refund_requested_count
    `,
  );
  res.json(rows[0]);
});

export default router;
