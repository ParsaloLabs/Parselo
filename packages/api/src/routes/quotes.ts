import { Router } from 'express';
import { z } from 'zod';
import { query } from '../db';

const router = Router();

// MVP: hardcoded quotes per courier (replace with Shiprocket later)
// Returns price comparison for a Send order.
router.post('/', async (req, res) => {
  const schema = z.object({
    from_pincode: z.string().min(4).max(10),
    to_pincode: z.string().min(4).max(10),
    weight_kg: z.number().min(0.1).max(50),
    parcel_type: z.string().optional().nullable(),
  });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_input' });
  const { weight_kg } = parsed.data;

  const { rows: couriers } = await query<{ id: string; name: string }>(
    `SELECT id, name FROM couriers WHERE is_active = TRUE ORDER BY name`,
  );

  // Crude per-courier base prices (paise) for MVP
  const bases: Record<string, { base: number; perKg: number; eta: number; rating: number }> = {
    DTDC: { base: 7000, perKg: 2000, eta: 4, rating: 4.1 },
    Delhivery: { base: 6500, perKg: 2500, eta: 3, rating: 4.3 },
    BlueDart: { base: 9000, perKg: 3000, eta: 2, rating: 4.5 },
    'India Post': { base: 4500, perKg: 1500, eta: 6, rating: 3.8 },
  };

  const quotes = couriers.map((c) => {
    const b = bases[c.name] ?? { base: 6000, perKg: 2000, eta: 4, rating: 4.0 };
    const price_paise = b.base + Math.ceil(weight_kg) * b.perKg;
    return {
      courier_id: c.id,
      courier_name: c.name,
      price_paise,
      eta_days: b.eta,
      rating: b.rating,
    };
  });

  res.json({ quotes });
});

export default router;
