'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { api } from '../../../lib/api';
import { loadServiceAreas, isInServiceArea, nearestServiceArea } from '../../../lib/serviceArea';
import MapPicker, { PickedLocation } from '../../../components/MapPicker';
import OutOfServiceArea from '../../../components/OutOfServiceArea';

type Address = {
  id: string; label?: string | null; full_address: string;
  pincode?: string | null; is_default: boolean;
};
type Quote = {
  courier_id: string; courier_name: string;
  price_paise: number; eta_days: number; rating: number;
};

const PARCEL_TYPES = ['Documents', 'Electronics', 'Clothing', 'Food', 'Fragile', 'Other'];

export default function SendPage() {
  const router = useRouter();
  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const [addresses, setAddresses] = useState<Address[]>([]);
  const [pickupId, setPickupId] = useState<string>('');
  const [newPickup, setNewPickup] = useState({ full_address: '', pincode: '' });
  const [pickupPin, setPickupPin] = useState<PickedLocation | null>(null);
  const [deliveryPin, setDeliveryPin] = useState<PickedLocation | null>(null);
  const [outOfArea, setOutOfArea] = useState<{ city: string | null } | null>(null);

  useEffect(() => { loadServiceAreas(); }, []);

  const [parcelType, setParcelType] = useState('Documents');
  const [weight, setWeight] = useState('1');
  const [description, setDescription] = useState('');
  const [declaredValue, setDeclaredValue] = useState('');

  const [recipientName, setRecipientName] = useState('');
  const [recipientPhone, setRecipientPhone] = useState('+91');
  const [deliveryAddress, setDeliveryAddress] = useState('');
  const [deliveryPincode, setDeliveryPincode] = useState('');

  const [quotes, setQuotes] = useState<Quote[]>([]);
  const [selectedQuote, setSelectedQuote] = useState<Quote | null>(null);

  useEffect(() => {
    api<Address[]>('/addresses').then((rows) => {
      setAddresses(rows);
      const def = rows.find((r) => r.is_default) ?? rows[0];
      if (def) setPickupId(def.id);
    }).catch(() => {});
  }, []);

  const goToQuotes = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      let pickup = addresses.find((a) => a.id === pickupId);
      if (!pickup) {
        if (!pickupPin) throw new Error('Pinpoint the pickup location on the map');
        const fullAddress = newPickup.full_address || pickupPin.full_address;
        if (!fullAddress) throw new Error('Add a pickup address');
        const pin = newPickup.pincode || pickupPin.pincode;
        const created = await api<Address>('/addresses', {
          method: 'POST',
          body: {
            full_address: fullAddress,
            latitude: pickupPin.lat,
            longitude: pickupPin.lng,
            pincode: pin || undefined,
            is_default: addresses.length === 0,
          },
        });
        setAddresses((prev) => [created, ...prev]);
        setPickupId(created.id);
        pickup = created;
      }
      if (!deliveryPin) throw new Error('Pinpoint the delivery location on the map');
      const fromPin = pickup.pincode || newPickup.pincode || pickupPin?.pincode || '680001';
      const toPin = deliveryPincode || deliveryPin.pincode || '110001';
      const res = await api<{ quotes: Quote[] }>('/quotes', {
        method: 'POST',
        body: {
          from_pincode: fromPin,
          to_pincode: toPin,
          weight_kg: Number(weight),
          parcel_type: parcelType,
        },
      });
      setQuotes(res.quotes);
      setSelectedQuote(res.quotes[0] ?? null);
      setStep(2);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const placeOrder = async () => {
    if (!selectedQuote) return;
    setError(null);
    setLoading(true);
    try {
      const order = await api<{ id: string }>('/orders', {
        method: 'POST',
        body: {
          order_type: 'send',
          parcel_type: parcelType,
          parcel_weight_kg: Number(weight),
          parcel_description: description || undefined,
          declared_value: declaredValue ? Math.round(Number(declaredValue) * 100) : undefined,
          pickup_address_id: pickupId,
          recipient_name: recipientName,
          recipient_phone: recipientPhone,
          delivery_address: deliveryAddress,
          delivery_lat: deliveryPin?.lat,
          delivery_lng: deliveryPin?.lng,
          selected_courier_id: selectedQuote.courier_id,
          courier_charge_paise: selectedQuote.price_paise,
        },
      });
      router.push(`/home/orders/${order.id}/pay`);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <OutOfServiceArea
        open={outOfArea !== null}
        nearestCityName={outOfArea?.city}
        onClose={() => setOutOfArea(null)}
      />
      <div className="flex items-center gap-2 mb-6 text-sm text-slate-500">
        <Link href="/home" className="hover:text-slate-900">← Home</Link>
        <span>/</span>
        <span>Send a parcel</span>
      </div>

      <div className="flex items-center gap-2 mb-6">
        {[1, 2, 3].map((n) => (
          <div key={n} className="flex items-center gap-2 flex-1">
            <div className={`h-8 w-8 rounded-full flex items-center justify-center text-sm font-semibold ${
              step >= n ? 'bg-brand text-white' : 'bg-slate-200 text-slate-500'
            }`}>{n}</div>
            <div className={`text-sm ${step >= n ? 'text-slate-900' : 'text-slate-400'}`}>
              {n === 1 ? 'Details' : n === 2 ? 'Choose courier' : 'Review'}
            </div>
            {n < 3 && <div className={`flex-1 h-0.5 ${step > n ? 'bg-brand' : 'bg-slate-200'}`} />}
          </div>
        ))}
      </div>

      {step === 1 && (
        <form onSubmit={goToQuotes} className="space-y-6">
          <section className="bg-white border border-slate-200 rounded-xl p-5">
            <h3 className="font-semibold mb-3">Pickup address</h3>
            {addresses.length > 0 && (
              <div className="space-y-2 mb-3">
                {addresses.map((a) => (
                  <label key={a.id} className={`flex items-start gap-3 p-3 rounded-lg border cursor-pointer ${
                    pickupId === a.id ? 'border-brand bg-blue-50' : 'border-slate-200'
                  }`}>
                    <input type="radio" name="pickup" checked={pickupId === a.id}
                      onChange={() => setPickupId(a.id)} className="mt-1" />
                    <div className="flex-1">
                      {a.label && <div className="text-xs font-semibold text-slate-500">{a.label}</div>}
                      <div className="text-sm">{a.full_address}</div>
                      {a.pincode && <div className="text-xs text-slate-500">PIN {a.pincode}</div>}
                    </div>
                  </label>
                ))}
                <label className={`flex items-start gap-3 p-3 rounded-lg border cursor-pointer ${
                  pickupId === '' ? 'border-brand bg-blue-50' : 'border-slate-200'
                }`}>
                  <input type="radio" name="pickup" checked={pickupId === ''}
                    onChange={() => setPickupId('')} className="mt-1" />
                  <div className="text-sm">Use a new address</div>
                </label>
              </div>
            )}
            {pickupId === '' && (
              <div className="space-y-3">
                <MapPicker
                  label="Pin the pickup spot"
                  value={pickupPin}
                  onChange={(loc) => {
                    if (!isInServiceArea(loc.lat, loc.lng)) {
                      const nearest = nearestServiceArea(loc.lat, loc.lng);
                      setOutOfArea({ city: nearest?.name ?? null });
                      return;
                    }
                    setPickupPin(loc);
                    setNewPickup((p) => ({
                      full_address: p.full_address || loc.full_address,
                      pincode: p.pincode || loc.pincode,
                    }));
                  }}
                />
                <textarea
                  value={newPickup.full_address}
                  onChange={(e) => setNewPickup({ ...newPickup, full_address: e.target.value })}
                  placeholder="House/flat, street, area (refine the auto-filled address)"
                  className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" rows={2} required
                />
                <input
                  value={newPickup.pincode}
                  onChange={(e) => setNewPickup({ ...newPickup, pincode: e.target.value })}
                  placeholder="Pincode" maxLength={6}
                  className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm"
                />
              </div>
            )}
          </section>

          <section className="bg-white border border-slate-200 rounded-xl p-5 space-y-3">
            <h3 className="font-semibold">Parcel details</h3>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs text-slate-500 mb-1">Type</label>
                <select value={parcelType} onChange={(e) => setParcelType(e.target.value)}
                  className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm">
                  {PARCEL_TYPES.map((t) => <option key={t}>{t}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-xs text-slate-500 mb-1">Weight (kg)</label>
                <input type="number" step="0.1" min="0.1" max="50" value={weight}
                  onChange={(e) => setWeight(e.target.value)} required
                  className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
              </div>
            </div>
            <div>
              <label className="block text-xs text-slate-500 mb-1">Description (optional)</label>
              <input value={description} onChange={(e) => setDescription(e.target.value)}
                placeholder="e.g. 2 books, signed copies"
                className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
            </div>
            <div>
              <label className="block text-xs text-slate-500 mb-1">Declared value (₹, optional)</label>
              <input type="number" min="0" value={declaredValue}
                onChange={(e) => setDeclaredValue(e.target.value)} placeholder="e.g. 2000"
                className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
            </div>
          </section>

          <section className="bg-white border border-slate-200 rounded-xl p-5 space-y-3">
            <h3 className="font-semibold">Recipient</h3>
            <div className="grid grid-cols-2 gap-3">
              <input value={recipientName} onChange={(e) => setRecipientName(e.target.value)}
                placeholder="Full name" required
                className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
              <input value={recipientPhone} onChange={(e) => setRecipientPhone(e.target.value)}
                placeholder="+91XXXXXXXXXX" required
                className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
            </div>
            <MapPicker
              label="Pin the delivery spot"
              accentClass="#F59E0B"
              value={deliveryPin}
              onChange={(loc) => {
                setDeliveryPin(loc);
                if (!deliveryAddress) setDeliveryAddress(loc.full_address);
                if (!deliveryPincode) setDeliveryPincode(loc.pincode);
              }}
            />
            <textarea value={deliveryAddress} onChange={(e) => setDeliveryAddress(e.target.value)}
              placeholder="Delivery address (house/flat, street, area, city)" rows={2} required
              className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
            <input value={deliveryPincode} onChange={(e) => setDeliveryPincode(e.target.value)}
              placeholder="Delivery pincode" maxLength={6} required
              className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
          </section>

          {error && <p className="text-red-600 text-sm">{error}</p>}
          <button type="submit" disabled={loading}
            className="w-full bg-brand text-white font-semibold py-3 rounded-lg hover:bg-brand-dark disabled:opacity-60">
            {loading ? 'Getting prices…' : 'Get courier quotes →'}
          </button>
        </form>
      )}

      {step === 2 && (
        <div className="space-y-3">
          <h3 className="font-semibold mb-2">Choose a courier</h3>
          {quotes.map((q) => (
            <label key={q.courier_id}
              className={`flex items-center gap-4 p-4 bg-white rounded-xl border cursor-pointer ${
                selectedQuote?.courier_id === q.courier_id ? 'border-brand bg-blue-50' : 'border-slate-200'
              }`}>
              <input type="radio" name="quote"
                checked={selectedQuote?.courier_id === q.courier_id}
                onChange={() => setSelectedQuote(q)} />
              <div className="flex-1">
                <div className="font-semibold">{q.courier_name}</div>
                <div className="text-xs text-slate-500">⭐ {q.rating} · {q.eta_days}-day delivery</div>
              </div>
              <div className="text-lg font-bold">₹{(q.price_paise / 100).toFixed(0)}</div>
            </label>
          ))}
          <div className="flex gap-3 mt-4">
            <button onClick={() => setStep(1)}
              className="flex-1 border border-slate-300 rounded-lg py-2.5 font-medium hover:bg-slate-50">
              Back
            </button>
            <button onClick={() => setStep(3)} disabled={!selectedQuote}
              className="flex-1 bg-brand text-white rounded-lg py-2.5 font-semibold hover:bg-brand-dark disabled:opacity-60">
              Continue
            </button>
          </div>
        </div>
      )}

      {step === 3 && selectedQuote && (
        <div className="space-y-4">
          <h3 className="font-semibold">Review & confirm</h3>
          <div className="bg-white border border-slate-200 rounded-xl p-5 space-y-3 text-sm">
            <Row label="Pickup">
              {addresses.find((a) => a.id === pickupId)?.full_address ?? newPickup.full_address}
            </Row>
            <Row label="Parcel">{parcelType} · {weight} kg{description && ` · ${description}`}</Row>
            <Row label="Recipient">{recipientName} ({recipientPhone})</Row>
            <Row label="Delivery">{deliveryAddress}, {deliveryPincode}</Row>
            <Row label="Courier">{selectedQuote.courier_name} · {selectedQuote.eta_days}d</Row>
          </div>

          <div className="bg-white border border-slate-200 rounded-xl p-5 space-y-2 text-sm">
            <PriceRow label="Courier charge" paise={selectedQuote.price_paise} />
            <PriceRow label="Service fee" paise={4900} />
            <PriceRow label="GST (18% on service)" paise={Math.round(4900 * 0.18)} />
            <div className="border-t border-slate-200 pt-2 flex justify-between font-bold text-base">
              <span>Total</span>
              <span>₹{((selectedQuote.price_paise + 4900 + Math.round(4900 * 0.18)) / 100).toFixed(0)}</span>
            </div>
          </div>

          {error && <p className="text-red-600 text-sm">{error}</p>}
          <div className="flex gap-3">
            <button onClick={() => setStep(2)}
              className="flex-1 border border-slate-300 rounded-lg py-3 font-medium hover:bg-slate-50">
              Back
            </button>
            <button onClick={placeOrder} disabled={loading}
              className="flex-1 bg-brand text-white rounded-lg py-3 font-semibold hover:bg-brand-dark disabled:opacity-60">
              {loading ? 'Placing…' : 'Place order'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex justify-between gap-4">
      <span className="text-slate-500">{label}</span>
      <span className="text-right">{children}</span>
    </div>
  );
}

function PriceRow({ label, paise }: { label: string; paise: number }) {
  return (
    <div className="flex justify-between">
      <span className="text-slate-600">{label}</span>
      <span>₹{(paise / 100).toFixed(0)}</span>
    </div>
  );
}
