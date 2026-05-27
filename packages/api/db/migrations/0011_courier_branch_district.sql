-- District helps admins group branches by city and powers the customer-side
-- "nearby courier office" picker on send orders. Free-text on purpose so we
-- can onboard new cities without another seed step.

ALTER TABLE courier_branches
  ADD COLUMN IF NOT EXISTS district TEXT;

CREATE INDEX IF NOT EXISTS idx_courier_branches_district
  ON courier_branches (district);
