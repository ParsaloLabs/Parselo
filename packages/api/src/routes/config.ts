import { Router } from 'express';
import { findNearbyOffices, listCourierOffices, listServiceableDistricts, SERVICE_RADIUS_M } from '../serviceArea';
import { getBoolFlag, FLAG_RADIUS_ENABLED } from '../flags';

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

// All active courier offices with coords. Clients cache this list and run a
// local Haversine on every pin drop, so the "out-of-zone" sheet appears
// instantly without a server round-trip.
router.get('/courier-offices', async (_req, res) => {
  const [offices, districts, radiusEnabled] = await Promise.all([
    listCourierOffices(),
    listServiceableDistricts(),
    getBoolFlag(FLAG_RADIUS_ENABLED, false),
  ]);
  res.json({
    radius_m: SERVICE_RADIUS_M,
    radius_gate_enabled: radiusEnabled,
    serviceable_districts: districts,
    offices,
  });
});

// Server-ranked nearby list. The customer-side picker can call this with the
// pin coords to render "drop-off office — sorted nearest first" without
// shipping the math to every client. ?lat=&lng=&radius_m=15000
router.get('/nearby-courier-offices', async (req, res) => {
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return res.status(400).json({ error: 'invalid_coords' });
  }
  const radiusRaw = Number(req.query.radius_m);
  const radiusM = Number.isFinite(radiusRaw) && radiusRaw > 0 ? radiusRaw : SERVICE_RADIUS_M;
  const offices = await findNearbyOffices(lat, lng, radiusM);
  res.json({ radius_m: radiusM, offices });
});

export default router;
