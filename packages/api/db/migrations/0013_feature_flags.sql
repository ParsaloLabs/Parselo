-- Feature flags table. Single global key/value store for runtime-tunable
-- behavior that admin should be able to flip without a redeploy.
--
-- service_area_radius_enabled — when true, a pin must also lie within
-- SERVICE_RADIUS_M (15 km) of a courier office on top of the district check.
-- When false, district-only gating applies (any pin in a district where we
-- have ≥1 active office is in-zone).

CREATE TABLE IF NOT EXISTS feature_flags (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO feature_flags (key, value) VALUES
  ('service_area_radius_enabled', 'false'::jsonb)
ON CONFLICT (key) DO NOTHING;
