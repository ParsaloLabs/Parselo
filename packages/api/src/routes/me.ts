import { Router } from 'express';
import { z } from 'zod';
import { query } from '../db';
import { requireAuth } from '../auth';

const router = Router();

router.get('/me', requireAuth(['user']), async (req, res) => {
  const userId = (req.principal as any).userId;
  const { rows } = await query(
    `SELECT id, phone, email, full_name, is_verified, created_at FROM users WHERE id = $1`,
    [userId],
  );
  if (rows.length === 0) return res.status(404).json({ error: 'not_found' });
  return res.json(rows[0]);
});

router.put('/me', requireAuth(['user']), async (req, res) => {
  const userId = (req.principal as any).userId;
  const parsed = z
    .object({ email: z.string().email().optional(), full_name: z.string().min(1).optional() })
    .safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input' });
  const { email, full_name } = parsed.data;
  const { rows } = await query(
    `UPDATE users SET email = COALESCE($2, email), full_name = COALESCE($3, full_name)
       WHERE id = $1 RETURNING id, phone, email, full_name, is_verified`,
    [userId, email ?? null, full_name ?? null],
  );
  return res.json(rows[0]);
});

export default router;
