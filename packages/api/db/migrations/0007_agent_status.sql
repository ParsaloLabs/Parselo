-- Agent self-registration → admin verification flow.
-- Existing rows backfill to 'approved' so the seeded test agent and any
-- admin-created agents keep working without manual intervention.

ALTER TABLE agents
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS dl_number TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES admins(id);

UPDATE agents SET status = 'approved' WHERE status = 'pending' AND created_at < NOW();

CREATE INDEX IF NOT EXISTS idx_agents_status ON agents(status);
