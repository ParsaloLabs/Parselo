export type OrderType = 'send' | 'receive';

export type OrderStatus =
  | 'pending'
  | 'agent_assigned'
  | 'agent_en_route_pickup'
  | 'parcel_collected'
  | 'at_courier_office'
  | 'shipped'
  | 'out_for_delivery'
  | 'delivered'
  | 'cancelled'
  | 'failed';

export type PaymentStatus = 'pending' | 'paid' | 'refunded';

export interface User {
  id: string;
  phone: string;
  email?: string | null;
  full_name?: string | null;
  is_verified: boolean;
  created_at: string;
}

export interface Address {
  id: string;
  user_id: string;
  label?: string | null;
  full_address: string;
  latitude?: number | null;
  longitude?: number | null;
  pincode?: string | null;
  is_default: boolean;
}

export interface Courier {
  id: string;
  name: string;
  logo_url?: string | null;
  is_active: boolean;
  api_provider?: string | null;
}

export interface Quote {
  courier_id: string;
  courier_name: string;
  price_paise: number;
  eta_days: number;
  rating: number;
}

export interface Order {
  id: string;
  order_code: string;
  user_id: string;
  agent_id?: string | null;
  order_type: OrderType;
  status: OrderStatus;
  parcel_type?: string | null;
  parcel_weight_kg?: number | null;
  parcel_description?: string | null;
  declared_value?: number | null;
  pickup_address_id?: string | null;
  recipient_name?: string | null;
  recipient_phone?: string | null;
  delivery_address?: string | null;
  selected_courier_id?: string | null;
  courier_tracking_id?: string | null;
  source_courier_id?: string | null;
  source_tracking_id?: string | null;
  source_branch_id?: string | null;
  authorization_doc_url?: string | null;
  user_id_proof_url?: string | null;
  user_signature_url?: string | null;
  delivery_address_id?: string | null;
  scheduled_pickup_at?: string | null;
  pickup_completed_at?: string | null;
  delivery_completed_at?: string | null;
  pickup_proof_photo_url?: string | null;
  delivery_proof_photo_url?: string | null;
  courier_charge?: number | null;
  service_fee?: number | null;
  gst_amount?: number | null;
  total_amount: number;
  payment_status: PaymentStatus;
  payment_id?: string | null;
  created_at: string;
  updated_at: string;
}

export const ORDER_CODE_PREFIX = 'PP';
export const PAISE_PER_RUPEE = 100;
