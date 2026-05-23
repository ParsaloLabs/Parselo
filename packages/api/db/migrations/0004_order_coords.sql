-- Add coordinates for the recipient location on "send" orders.
-- Pickup coords for both flows and delivery coords for "receive" already live on the addresses table.
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_lat DECIMAL(10, 7),
  ADD COLUMN IF NOT EXISTS delivery_lng DECIMAL(10, 7);
