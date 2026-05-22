// Pricing logic per SPEC.md section 9.3. All amounts in paise (integers).

export interface SendPricingInput {
  courier_charge_paise: number;
  distance_km?: number; // pickup -> courier office
  base_fee_paise?: number;
  per_km_fee_paise?: number;
}

export interface ReceivePricingInput {
  pickup_fee_paise?: number;
  delivery_fee_paise?: number; // 3000 same-day, 0 next-day
}

export interface PricingBreakdown {
  courier_charge: number;
  service_fee: number;
  gst_amount: number;
  total: number;
}

const GST_RATE = 0.18;

export function priceSendOrder(input: SendPricingInput): PricingBreakdown {
  const base = input.base_fee_paise ?? 4000;
  const perKm = input.per_km_fee_paise ?? 500;
  const distance = input.distance_km ?? 0;
  const service_fee = base + Math.max(0, distance - 5) * perKm;
  const gst_amount = Math.round(service_fee * GST_RATE);
  return {
    courier_charge: input.courier_charge_paise,
    service_fee,
    gst_amount,
    total: input.courier_charge_paise + service_fee + gst_amount,
  };
}

export function priceReceiveOrder(input: ReceivePricingInput): PricingBreakdown {
  const pickup = input.pickup_fee_paise ?? 9900;
  const delivery = input.delivery_fee_paise ?? 0;
  const service_fee = pickup + delivery;
  const gst_amount = Math.round(service_fee * GST_RATE);
  return {
    courier_charge: 0,
    service_fee,
    gst_amount,
    total: service_fee + gst_amount,
  };
}
