import { Router } from 'express';
import { z } from 'zod';
import { query } from '../db';
import { requireAuth } from '../auth';

const router = Router();

router.get('/', requireAuth(['user']), async (req, res) => {
  const userId = (req.principal as any).userId;
  const { rows } = await query(
    `SELECT * FROM addresses WHERE user_id = $1 ORDER BY is_default DESC, created_at DESC`,
    [userId],
  );
  res.json(rows);
});

router.post('/', requireAuth(['user']), async (req, res) => {
  const userId = (req.principal as any).userId;
  const schema = z.object({
    label: z.string().max(50).optional().nullable(),
    full_address: z.string().min(5),
    latitude: z.number().optional().nullable(),
    longitude: z.number().optional().nullable(),
    pincode: z.string().min(4).max(10).optional().nullable(),
    district: z.string().max(100).optional().nullable(),
    is_default: z.boolean().optional().nullable(),
  });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input', details: parsed.error.format() });
  const a = parsed.data;

  if (a.is_default) {
    await query(`UPDATE addresses SET is_default = FALSE WHERE user_id = $1`, [userId]);
  }
  const { rows } = await query(
    `INSERT INTO addresses (user_id, label, full_address, latitude, longitude, pincode, district, is_default)
       VALUES ($1, $2, $3, $4, $5, $6, $7, COALESCE($8, FALSE)) RETURNING *`,
    [userId, a.label ?? null, a.full_address, a.latitude ?? null, a.longitude ?? null, a.pincode ?? null, a.district ?? null, a.is_default ?? false],
  );
  res.status(201).json(rows[0]);
});

router.delete('/:id', requireAuth(['user']), async (req, res) => {
  const userId = (req.principal as any).userId;
  await query(`DELETE FROM addresses WHERE id = $1 AND user_id = $2`, [req.params.id, userId]);
  res.status(204).end();
});

export default router;
