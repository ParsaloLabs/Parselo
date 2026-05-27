-- Reverse-geocoded district stored alongside lat/lng so the service-area
-- gate can do a fast district-membership check at order create time without
-- re-geocoding server-side.

ALTER TABLE addresses ADD COLUMN IF NOT EXISTS district TEXT;
CREATE INDEX IF NOT EXISTS idx_addresses_district ON addresses (district);
