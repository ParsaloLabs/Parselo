-- Targeted dispatch: instead of broadcasting every new paid order to every
-- online agent, the API records explicit offer rows per (order, agent) with
-- a 30s TTL. The dispatcher picks the top-3 nearest eligible agents inside a
-- widening radius ladder (5km → 10km → 15km → all-online) and the agent app
-- only sees orders that have a live offer addressed to them.

CREATE TABLE IF NOT EXISTS job_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  distance_m INT NOT NULL,
  rank INT NOT NULL,
  attempt INT NOT NULL DEFAULT 1,
  offered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'offered'
    CHECK (status IN ('offered', 'accepted', 'declined', 'expired', 'cancelled')),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_job_offers_agent_status
  ON job_offers (agent_id, status) WHERE status = 'offered';

CREATE INDEX IF NOT EXISTS idx_job_offers_order_status
  ON job_offers (order_id, status);

-- A given agent can only have one live offer for a given order at a time.
-- Re-dispatch of the same order to the same agent after expiry creates a new
-- row, but the PARTIAL unique index keeps the live set clean.
CREATE UNIQUE INDEX IF NOT EXISTS idx_job_offers_active_unique
  ON job_offers (order_id, agent_id) WHERE status = 'offered';

ALTER TABLE agents
  ADD COLUMN IF NOT EXISTS last_location_at TIMESTAMPTZ;

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS dispatch_attempts INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS dispatch_last_at  TIMESTAMPTZ;
