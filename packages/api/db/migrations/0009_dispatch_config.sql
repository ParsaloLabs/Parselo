-- Single-row table that holds runtime-tunable dispatch parameters.
-- Two knobs only: initial search radius (metres) and offer TTL (seconds).
-- The radius ladder used during escalation is derived as [r, 2r, 3r, null]
-- so admins only need to set the starting point.

CREATE TABLE IF NOT EXISTS dispatch_config (
  id                INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  initial_radius_m  INT NOT NULL DEFAULT 5000  CHECK (initial_radius_m  BETWEEN 100 AND 200000),
  offer_ttl_seconds INT NOT NULL DEFAULT 30    CHECK (offer_ttl_seconds BETWEEN 5   AND 600),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by        UUID REFERENCES admins(id)
);

INSERT INTO dispatch_config (id) VALUES (1) ON CONFLICT DO NOTHING;
