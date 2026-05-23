import { Router } from 'express';
import { z } from 'zod';
import { query } from '../db';
import { requireAuth } from '../auth';
import { notifyOrderEvent } from '../notifications';

const router = Router();

// Surface unified pickup/drop coordinates per order so the agent app
// can render both on one map regardless of order_type.
//   send:    pickup = pickup_address (addresses table)
//            drop   = orders.delivery_lat/lng + orders.delivery_address (free text)
//   receive: pickup = source courier branch (courier_branches)
//            drop   = delivery_address (addresses table)
const JOBS_SELECT = `
  SELECT o.*,
         COALESCE(pa.latitude, cb.latitude)                AS pickup_lat,
         COALESCE(pa.longitude, cb.longitude)              AS pickup_lng,
         COALESCE(pa.full_address, cb.full_address)        AS pickup_text,
         COALESCE(da.latitude, o.delivery_lat)             AS drop_lat,
         COALESCE(da.longitude, o.delivery_lng)            AS drop_lng,
         COALESCE(da.full_address, o.delivery_address)     AS drop_text
    FROM orders o
    LEFT JOIN addresses pa ON pa.id = o.pickup_address_id
    LEFT JOIN addresses da ON da.id = o.delivery_address_id
    LEFT JOIN courier_branches cb ON cb.id = o.source_branch_id
`;

router.get('/jobs', requireAuth(['agent']), async (req, res) => {
  const agentId = (req.principal as any).agentId;
  const { rows: assigned } = await query(
    `${JOBS_SELECT}
      WHERE o.agent_id = $1 AND o.status NOT IN ('delivered','cancelled','failed')
      ORDER BY o.created_at DESC`,
    [agentId],
  );

  const { rows: agentRows } = await query<{ is_online: boolean }>(
    `SELECT is_online FROM agents WHERE id = $1`,
    [agentId],
  );
  const isOnline = agentRows[0]?.is_online ?? false;

  const available = isOnline
    ? (await query(
        `${JOBS_SELECT}
          WHERE o.agent_id IS NULL AND o.status = 'pending' AND o.payment_status = 'paid'
            AND (o.retry_at IS NULL OR o.retry_at <= NOW())
          ORDER BY o.created_at ASC LIMIT 20`,
      )).rows
    : [];

  res.json({ assigned, available });
});

router.post('/jobs/:id/accept', requireAuth(['agent']), async (req, res) => {
  const agentId = (req.principal as any).agentId;
  const { rows } = await query(
    `UPDATE orders SET agent_id = $1, status = 'agent_assigned', updated_at = NOW()
       WHERE id = $2 AND agent_id IS NULL AND status = 'pending'
       RETURNING *`,
    [agentId, req.params.id],
  );
  if (rows.length === 0) return res.status(409).json({ error: 'job_unavailable' });
  await query(
    `INSERT INTO order_status_history (order_id, status, changed_by_type, changed_by_id) VALUES ($1, 'agent_assigned', 'agent', $2)`,
    [req.params.id, agentId],
  );
  notifyOrderEvent(req.params.id, 'agent_assigned');
  res.json(rows[0]);
});

const ALLOWED_TRANSITIONS: Record<string, string[]> = {
  agent_assigned: ['agent_en_route_pickup', 'failed'],
  agent_en_route_pickup: ['parcel_collected', 'failed'],
  parcel_collected: ['out_for_delivery', 'failed'],
  out_for_delivery: ['delivered', 'failed'],
};

router.post('/jobs/:id/update-status', requireAuth(['agent']), async (req, res) => {
  const agentId = (req.principal as any).agentId;
  const schema = z.object({
    status: z.string(),
    notes: z.string().optional(),
    photo_url: z.string().url().optional(),
    location: z.object({ lat: z.number(), lng: z.number() }).optional(),
    delivery_otp: z.string().length(4).optional(),
    failure_reason: z.string().min(1).max(500).optional(),
  });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input' });
  const { status, notes, photo_url, delivery_otp, failure_reason } = parsed.data;

  if (status === 'failed' && !failure_reason) {
    return res.status(400).json({ error: 'failure_reason_required' });
  }

  const { rows: orderRows } = await query<{ status: string; delivery_otp: string; order_type: string }>(
    `SELECT status, delivery_otp, order_type FROM orders WHERE id = $1 AND agent_id = $2`,
    [req.params.id, agentId],
  );
  if (orderRows.length === 0) return res.status(404).json({ error: 'not_found' });
  const current = orderRows[0].status;
  const allowed = ALLOWED_TRANSITIONS[current] ?? [];
  if (!allowed.includes(status)) {
    return res.status(400).json({ error: 'invalid_transition', from: current, to: status });
  }

  // OTP gate: customer holds the OTP at the parcel-handover moment.
  // Send: handover is at pickup (parcel_collected). Receive: at delivery (delivered).
  const otpRequired =
    (orderRows[0].order_type === 'send' && status === 'parcel_collected') ||
    (orderRows[0].order_type === 'receive' && status === 'delivered');
  if (otpRequired) {
    if (!delivery_otp || delivery_otp !== orderRows[0].delivery_otp) {
      return res.status(401).json({ error: 'otp_mismatch' });
    }
  }

  const photoColumn =
    status === 'parcel_collected' ? 'pickup_proof_photo_url' :
    status === 'delivered' ? 'delivery_proof_photo_url' : null;

  const sets: string[] = ['status = $1', 'updated_at = NOW()'];
  const params: any[] = [status];
  if (photoColumn && photo_url) {
    params.push(photo_url);
    sets.push(`${photoColumn} = $${params.length}`);
  }
  if (status === 'parcel_collected') sets.push(`pickup_completed_at = NOW()`);
  if (status === 'delivered') sets.push(`delivery_completed_at = NOW()`);
  if (status === 'failed' && failure_reason) {
    params.push(failure_reason);
    sets.push(`failure_reason = $${params.length}`);
  }

  params.push(req.params.id);
  await query(`UPDATE orders SET ${sets.join(', ')} WHERE id = $${params.length}`, params);

  await query(
    `INSERT INTO order_status_history (order_id, status, notes, changed_by_type, changed_by_id) VALUES ($1, $2, $3, 'agent', $4)`,
    [req.params.id, status, notes ?? failure_reason ?? null, agentId],
  );

  if (status === 'delivered') {
    await query(
      `UPDATE agents SET total_deliveries = total_deliveries + 1 WHERE id = $1`,
      [agentId],
    );
  }

  notifyOrderEvent(req.params.id, status as any);
  res.json({ ok: true, status });
});

router.post('/location', requireAuth(['agent']), async (req, res) => {
  const agentId = (req.principal as any).agentId;
  const parsed = z.object({ lat: z.number(), lng: z.number() }).safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input' });
  await query(
    `UPDATE agents SET current_lat = $1, current_lng = $2 WHERE id = $3`,
    [parsed.data.lat, parsed.data.lng, agentId],
  );
  res.json({ ok: true });
});

router.post('/online-status', requireAuth(['agent']), async (req, res) => {
  const agentId = (req.principal as any).agentId;
  const parsed = z.object({ is_online: z.boolean() }).safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input' });
  await query(`UPDATE agents SET is_online = $1 WHERE id = $2`, [parsed.data.is_online, agentId]);
  res.json({ ok: true });
});

export default router;
