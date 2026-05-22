import { Router } from 'express';
import { query } from '../db';

const router = Router();

router.get('/', async (_req, res) => {
  const { rows } = await query(
    `SELECT id, name, logo_url, api_provider FROM couriers WHERE is_active = TRUE ORDER BY name`,
  );
  res.json(rows);
});

router.get('/:id/branches', async (req, res) => {
  const { rows } = await query(
    `SELECT * FROM courier_branches WHERE courier_id = $1 ORDER BY name`,
    [req.params.id],
  );
  res.json(rows);
});

export default router;
