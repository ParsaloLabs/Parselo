-- ParcelPal initial schema (per SPEC.md section 4)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(15) UNIQUE NOT NULL,
  email VARCHAR(255),
  full_name VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  is_verified BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  label VARCHAR(50),
  full_address TEXT NOT NULL,
  latitude DECIMAL(10, 7),
  longitude DECIMAL(10, 7),
  pincode VARCHAR(10),
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS agents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(15) UNIQUE NOT NULL,
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  password_hash TEXT NOT NULL,
  vehicle_type VARCHAR(20),
  vehicle_number VARCHAR(20),
  id_proof_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  is_online BOOLEAN DEFAULT FALSE,
  current_lat DECIMAL(10, 7),
  current_lng DECIMAL(10, 7),
  rating DECIMAL(2, 1) DEFAULT 5.0,
  total_deliveries INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS admins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  full_name VARCHAR(255),
  role VARCHAR(20) DEFAULT 'ops',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS couriers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  logo_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  api_provider VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS courier_branches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id UUID REFERENCES couriers(id) ON DELETE CASCADE,
  name VARCHAR(255),
  full_address TEXT NOT NULL,
  latitude DECIMAL(10, 7),
  longitude DECIMAL(10, 7),
  pincode VARCHAR(10),
  phone VARCHAR(15),
  opening_hours TEXT
);

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_code VARCHAR(20) UNIQUE NOT NULL,
  user_id UUID REFERENCES users(id),
  agent_id UUID REFERENCES agents(id),
  order_type VARCHAR(20) NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'pending',

  parcel_type VARCHAR(50),
  parcel_weight_kg DECIMAL(5, 2),
  parcel_description TEXT,
  declared_value INTEGER,
  pickup_address_id UUID REFERENCES addresses(id),
  recipient_name VARCHAR(255),
  recipient_phone VARCHAR(15),
  delivery_address TEXT,
  selected_courier_id UUID REFERENCES couriers(id),
  courier_tracking_id VARCHAR(100),

  source_courier_id UUID REFERENCES couriers(id),
  source_tracking_id VARCHAR(100),
  source_branch_id UUID REFERENCES courier_branches(id),
  authorization_doc_url TEXT,
  user_id_proof_url TEXT,
  user_signature_url TEXT,
  delivery_address_id UUID REFERENCES addresses(id),

  scheduled_pickup_at TIMESTAMPTZ,
  pickup_completed_at TIMESTAMPTZ,
  delivery_completed_at TIMESTAMPTZ,
  pickup_proof_photo_url TEXT,
  delivery_proof_photo_url TEXT,

  courier_charge INTEGER,
  service_fee INTEGER,
  gst_amount INTEGER,
  total_amount INTEGER NOT NULL,
  payment_status VARCHAR(20) DEFAULT 'pending',
  payment_id VARCHAR(100),
  delivery_otp VARCHAR(6),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  status VARCHAR(30) NOT NULL,
  notes TEXT,
  changed_by_type VARCHAR(20),
  changed_by_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pricing_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_name VARCHAR(100),
  service_type VARCHAR(20),
  base_fee INTEGER NOT NULL,
  per_km_fee INTEGER DEFAULT 0,
  weight_surcharge_per_kg INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS otp_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(15) NOT NULL,
  code VARCHAR(6) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_agent ON orders(agent_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_agents_online ON agents(is_online) WHERE is_online = TRUE;
CREATE INDEX IF NOT EXISTS idx_otp_phone ON otp_codes(phone, consumed);
