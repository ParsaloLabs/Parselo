-- Seed couriers + Thrissur branches + default pricing rules

INSERT INTO couriers (name, api_provider, is_active) VALUES
  ('DTDC', 'shiprocket', TRUE),
  ('Delhivery', 'shiprocket', TRUE),
  ('BlueDart', 'shiprocket', TRUE),
  ('India Post', 'manual', TRUE)
ON CONFLICT DO NOTHING;

-- Thrissur branches (representative addresses)
INSERT INTO courier_branches (courier_id, name, full_address, latitude, longitude, pincode, phone, opening_hours)
SELECT id, 'DTDC Thrissur Round', 'M.G. Road, Round North, Thrissur, Kerala 680001', 10.5276, 76.2144, '680001', '+914872331234', 'Mon-Sat 9:00-19:00'
FROM couriers WHERE name = 'DTDC' ON CONFLICT DO NOTHING;

INSERT INTO courier_branches (courier_id, name, full_address, latitude, longitude, pincode, phone, opening_hours)
SELECT id, 'Delhivery Thrissur Hub', 'Patturaikkal, Thrissur, Kerala 680022', 10.5167, 76.2102, '680022', '+914872445566', 'Mon-Sat 9:00-20:00'
FROM couriers WHERE name = 'Delhivery' ON CONFLICT DO NOTHING;

INSERT INTO courier_branches (courier_id, name, full_address, latitude, longitude, pincode, phone, opening_hours)
SELECT id, 'BlueDart Thrissur', 'Kuriachira, Thrissur, Kerala 680006', 10.5402, 76.2058, '680006', '+914872773344', 'Mon-Sat 9:30-18:30'
FROM couriers WHERE name = 'BlueDart' ON CONFLICT DO NOTHING;

INSERT INTO courier_branches (courier_id, name, full_address, latitude, longitude, pincode, phone, opening_hours)
SELECT id, 'India Post Thrissur Head Office', 'Head Post Office Road, Thrissur, Kerala 680001', 10.5252, 76.2156, '680001', '+914872331212', 'Mon-Sat 10:00-17:00'
FROM couriers WHERE name = 'India Post' ON CONFLICT DO NOTHING;

INSERT INTO pricing_rules (rule_name, service_type, base_fee, per_km_fee, weight_surcharge_per_kg, is_active) VALUES
  ('default-send', 'send', 4000, 500, 1000, TRUE),
  ('default-receive', 'receive', 9900, 0, 0, TRUE)
ON CONFLICT DO NOTHING;
