-- FCM / APNs device tokens for the agent mobile app. One agent can hold
-- multiple devices (phone + tablet, reinstalls, etc) so the FK is many-to-one.
-- token is globally unique because FCM never reissues the same token to two
-- devices — when a user logs out and back in on the same handset we just
-- update agent_id on conflict.
CREATE TABLE IF NOT EXISTS agent_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agent_devices_agent_id ON agent_devices (agent_id);
