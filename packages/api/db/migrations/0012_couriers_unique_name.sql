-- Dedupe couriers and enforce uniqueness on name.
--
-- Background: the original seed used `INSERT … ON CONFLICT DO NOTHING` without
-- a conflict target, so Postgres defaulted to the PK (a freshly-generated UUID
-- every run). With no UNIQUE constraint on couriers.name, every `npm run seed`
-- re-inserted the same four brands.
--
-- This migration:
--   1) Picks a keeper row per name (lowest id::text).
--   2) Re-points all FK references — courier_branches, orders.selected_courier_id,
--      orders.source_courier_id — to the keeper.
--   3) Deletes the duplicate courier rows.
--   4) Adds UNIQUE(name) so future seed runs are truly idempotent.

WITH keepers AS (
  SELECT name, MIN(id::text)::uuid AS keeper_id
    FROM couriers
   GROUP BY name
)
UPDATE courier_branches b
   SET courier_id = k.keeper_id
  FROM keepers k, couriers c
 WHERE b.courier_id = c.id
   AND c.name = k.name
   AND b.courier_id <> k.keeper_id;

WITH keepers AS (
  SELECT name, MIN(id::text)::uuid AS keeper_id
    FROM couriers
   GROUP BY name
)
UPDATE orders o
   SET selected_courier_id = k.keeper_id
  FROM keepers k, couriers c
 WHERE o.selected_courier_id = c.id
   AND c.name = k.name
   AND o.selected_courier_id <> k.keeper_id;

WITH keepers AS (
  SELECT name, MIN(id::text)::uuid AS keeper_id
    FROM couriers
   GROUP BY name
)
UPDATE orders o
   SET source_courier_id = k.keeper_id
  FROM keepers k, couriers c
 WHERE o.source_courier_id = c.id
   AND c.name = k.name
   AND o.source_courier_id <> k.keeper_id;

DELETE FROM couriers
 WHERE id NOT IN (
   SELECT MIN(id::text)::uuid FROM couriers GROUP BY name
 );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'couriers_name_unique'
  ) THEN
    ALTER TABLE couriers ADD CONSTRAINT couriers_name_unique UNIQUE (name);
  END IF;
END$$;
