-- service_area_radius_m — admin-editable radius (in metres) used when
-- service_area_radius_enabled is on. Kept as a separate flag so admin can
-- tune the radius once, then flip the on/off toggle without re-entering it.
-- Default mirrors the previous hard-coded SERVICE_RADIUS_M.

INSERT INTO feature_flags (key, value) VALUES
  ('service_area_radius_m', '15000'::jsonb)
ON CONFLICT (key) DO NOTHING;
