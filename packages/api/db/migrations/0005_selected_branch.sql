-- For "send" orders the agent drops the parcel at a specific courier office
-- branch, not at the recipient's address. We pin the branch chosen at order
-- creation so the agent's map destination resolves to the office, while the
-- recipient address remains stored for hand-over to the courier counter.
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS selected_branch_id UUID REFERENCES courier_branches(id);

CREATE INDEX IF NOT EXISTS idx_orders_selected_branch ON orders(selected_branch_id);
