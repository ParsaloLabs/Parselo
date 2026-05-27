-- Service-area gate: customer addresses (pickup for send, delivery for receive)
-- must fall within an active service area. Row-per-city so multi-city expansion
-- is just an INSERT. Check uses center+radius (Haversine) — cheap, fast, and
-- good enough for hyperlocal launch. Admin tunes radius from the UI.

CREATE TABLE IF NOT EXISTS service_areas (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  center_lat  DECIMAL(10, 7) NOT NULL CHECK (center_lat  BETWEEN -90  AND 90),
  center_lng  DECIMAL(10, 7) NOT NULL CHECK (center_lng  BETWEEN -180 AND 180),
  radius_m    INT NOT NULL CHECK (radius_m BETWEEN 500 AND 200000),
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by  UUID REFERENCES admins(id)
);

CREATE INDEX IF NOT EXISTS service_areas_active_idx ON service_areas (is_active);

INSERT INTO service_areas (name, center_lat, center_lng, radius_m)
SELECT 'Thrissur', 10.5276, 76.2144, 15000
WHERE NOT EXISTS (SELECT 1 FROM service_areas);
