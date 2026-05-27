import { Router } from 'express';
import { listServiceAreas } from '../serviceArea';

const router = Router();

// Canonical fee defaults — kept in sync with pricing.ts so clients show the
// same numbers the backend will actually charge at order create.
router.get('/pricing', (_req, res) => {
  res.json({
    send_base_service_fee_paise: 4000,
    send_per_km_fee_paise: 500,
    send_free_distance_km: 5,
    receive_pickup_fee_paise: 9900,
    same_day_delivery_fee_paise: 3000,
    gst_rate: 0.18,
  });
});

// Active service areas — mobile app pre-validates pin drops against this list
// so the out-of-zone sheet appears instantly without a round-trip.
router.get('/service-areas', async (_req, res) => {
  const areas = await listServiceAreas();
  res.json({ areas });
});

export default router;
