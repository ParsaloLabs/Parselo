'use client';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { api } from '../../../lib/api';
import SignaturePad, { SignaturePadHandle } from '../../../components/SignaturePad';

async function compressImage(file: File, maxDim = 1200, quality = 0.75): Promise<string> {
  const url = URL.createObjectURL(file);
  try {
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const i = new Image();
      i.onload = () => resolve(i);
      i.onerror = () => reject(new Error('Could not read image'));
      i.src = url;
    });
    let { width, height } = img;
    if (width > maxDim || height > maxDim) {
      const scale = maxDim / Math.max(width, height);
      width = Math.round(width * scale);
      height = Math.round(height * scale);
    }
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d')!;
    ctx.drawImage(img, 0, 0, width, height);
    return canvas.toDataURL('image/jpeg', quality);
  } finally {
    URL.revokeObjectURL(url);
  }
}

type Address = { id: string; label?: string | null; full_address: string; pincode?: string | null; is_default: boolean };
type Courier = { id: string; name: string };
type Branch = { id: string; name: string; address: string };

export default function ReceivePage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const [couriers, setCouriers] = useState<Courier[]>([]);
  const [addresses, setAddresses] = useState<Address[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);

  const [courierId, setCourierId] = useState('');
  const [branchId, setBranchId] = useState('');
  const [trackingId, setTrackingId] = useState('');
  const [deliveryId, setDeliveryId] = useState('');
  const [newDelivery, setNewDelivery] = useState({ full_address: '', pincode: '' });
  const [sameDay, setSameDay] = useState(false);

  const sigRef = useRef<SignaturePadHandle>(null);
  const [idDataUrl, setIdDataUrl] = useState<string | null>(null);
  const [idFileName, setIdFileName] = useState<string | null>(null);
  const [agreed, setAgreed] = useState(false);

  const onIdPick = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setError(null);
    try {
      const data = await compressImage(file);
      setIdDataUrl(data);
      setIdFileName(file.name);
    } catch (err: any) {
      setError(err.message);
    }
  };

  useEffect(() => {
    api<Courier[]>('/couriers').then(setCouriers).catch(() => {});
    api<Address[]>('/addresses').then((rows) => {
      setAddresses(rows);
      const def = rows.find((r) => r.is_default) ?? rows[0];
      if (def) setDeliveryId(def.id);
    }).catch(() => {});
  }, []);

  useEffect(() => {
    if (!courierId) { setBranches([]); setBranchId(''); return; }
    api<Branch[]>(`/couriers/${courierId}/branches`).then(setBranches).catch(() => setBranches([]));
  }, [courierId]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    const signature = sigRef.current?.toDataURL();
    if (!signature) { setError('Please sign in the box below to authorize collection'); return; }
    if (!idDataUrl) { setError('Please upload a photo of your government-issued ID'); return; }
    if (!agreed) { setError('Please confirm the declaration to proceed'); return; }

    setLoading(true);
    try {
      let delId = deliveryId;
      if (!delId) {
        if (!newDelivery.full_address) throw new Error('Add a delivery address');
        const created = await api<Address>('/addresses', {
          method: 'POST',
          body: {
            full_address: newDelivery.full_address,
            pincode: newDelivery.pincode || undefined,
            is_default: addresses.length === 0,
          },
        });
        delId = created.id;
      }
      const order = await api<{ id: string }>('/orders', {
        method: 'POST',
        body: {
          order_type: 'receive',
          source_courier_id: courierId,
          source_tracking_id: trackingId,
          source_branch_id: branchId || undefined,
          delivery_address_id: delId,
          same_day: sameDay,
          user_signature_url: signature,
          user_id_proof_url: idDataUrl,
        },
      });
      router.push(`/home/orders/${order.id}/pay`);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const pickupFee = 9900;
  const deliveryFee = sameDay ? 3000 : 0;
  const service = pickupFee + deliveryFee;
  const gst = Math.round(service * 0.18);
  const total = service + gst;

  return (
    <div className="max-w-2xl mx-auto">
      <div className="flex items-center gap-2 mb-6 text-sm text-slate-500">
        <Link href="/home" className="hover:text-slate-900">← Home</Link>
        <span>/</span>
        <span>Receive a parcel</span>
      </div>

      <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 mb-6 text-sm text-amber-900">
        <strong>How this works:</strong> Our agent visits the courier office on your behalf,
        collects your parcel, and delivers it to your address.
        You'll get an OTP to share with the agent at delivery.
      </div>

      <form onSubmit={submit} className="space-y-5">
        <section className="bg-white border border-slate-200 rounded-xl p-5 space-y-3">
          <h3 className="font-semibold">Where is the parcel?</h3>
          <div>
            <label className="block text-xs text-slate-500 mb-1">Courier</label>
            <select value={courierId} onChange={(e) => setCourierId(e.target.value)} required
              className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm">
              <option value="">Select courier</option>
              {couriers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </div>
          {branches.length > 0 && (
            <div>
              <label className="block text-xs text-slate-500 mb-1">Branch (optional)</label>
              <select value={branchId} onChange={(e) => setBranchId(e.target.value)}
                className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm">
                <option value="">Auto-select nearest</option>
                {branches.map((b) => <option key={b.id} value={b.id}>{b.name} — {b.address}</option>)}
              </select>
            </div>
          )}
          <div>
            <label className="block text-xs text-slate-500 mb-1">Tracking / consignment number</label>
            <input value={trackingId} onChange={(e) => setTrackingId(e.target.value)} required
              placeholder="e.g. AWB123456789"
              className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm font-mono" />
          </div>
        </section>

        <section className="bg-white border border-slate-200 rounded-xl p-5">
          <h3 className="font-semibold mb-3">Deliver to</h3>
          {addresses.length > 0 && (
            <div className="space-y-2 mb-3">
              {addresses.map((a) => (
                <label key={a.id} className={`flex items-start gap-3 p-3 rounded-lg border cursor-pointer ${
                  deliveryId === a.id ? 'border-brand bg-blue-50' : 'border-slate-200'
                }`}>
                  <input type="radio" name="delivery" checked={deliveryId === a.id}
                    onChange={() => setDeliveryId(a.id)} className="mt-1" />
                  <div className="flex-1">
                    {a.label && <div className="text-xs font-semibold text-slate-500">{a.label}</div>}
                    <div className="text-sm">{a.full_address}</div>
                    {a.pincode && <div className="text-xs text-slate-500">PIN {a.pincode}</div>}
                  </div>
                </label>
              ))}
              <label className={`flex items-start gap-3 p-3 rounded-lg border cursor-pointer ${
                deliveryId === '' ? 'border-brand bg-blue-50' : 'border-slate-200'
              }`}>
                <input type="radio" name="delivery" checked={deliveryId === ''}
                  onChange={() => setDeliveryId('')} className="mt-1" />
                <div className="text-sm">Use a new address</div>
              </label>
            </div>
          )}
          {deliveryId === '' && (
            <div className="space-y-2">
              <textarea
                value={newDelivery.full_address}
                onChange={(e) => setNewDelivery({ ...newDelivery, full_address: e.target.value })}
                placeholder="House/flat, street, area, city" rows={2} required
                className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm"
              />
              <input
                value={newDelivery.pincode}
                onChange={(e) => setNewDelivery({ ...newDelivery, pincode: e.target.value })}
                placeholder="Pincode" maxLength={6}
                className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm"
              />
            </div>
          )}
        </section>

        <section className="bg-white border border-slate-200 rounded-xl p-5">
          <h3 className="font-semibold mb-3">Delivery speed</h3>
          <div className="grid grid-cols-2 gap-3">
            <label className={`p-3 rounded-lg border cursor-pointer text-center ${
              !sameDay ? 'border-brand bg-blue-50' : 'border-slate-200'
            }`}>
              <input type="radio" checked={!sameDay} onChange={() => setSameDay(false)} className="hidden" />
              <div className="font-semibold">Next day</div>
              <div className="text-xs text-slate-500 mt-1">Free</div>
            </label>
            <label className={`p-3 rounded-lg border cursor-pointer text-center ${
              sameDay ? 'border-brand bg-blue-50' : 'border-slate-200'
            }`}>
              <input type="radio" checked={sameDay} onChange={() => setSameDay(true)} className="hidden" />
              <div className="font-semibold">Same day</div>
              <div className="text-xs text-slate-500 mt-1">+₹30</div>
            </label>
          </div>
        </section>

        <section className="bg-white border border-slate-200 rounded-xl p-5 space-y-4">
          <div>
            <h3 className="font-semibold">Authorization</h3>
            <p className="text-xs text-slate-500 mt-1">
              The courier office requires your signature and ID to release the parcel to our agent.
              We share these only with the courier office, never with the agent.
            </p>
          </div>

          <div>
            <label className="block text-xs text-slate-500 mb-2">Signature</label>
            <div className="border border-slate-300 rounded-lg overflow-hidden bg-white">
              <SignaturePad ref={sigRef} className="w-full h-40 block" />
            </div>
            <button type="button" onClick={() => sigRef.current?.clear()}
              className="mt-2 text-xs text-slate-500 hover:text-slate-900">
              Clear signature
            </button>
          </div>

          <div>
            <label className="block text-xs text-slate-500 mb-2">Government-issued ID (Aadhaar / PAN / Driving licence)</label>
            <input type="file" accept="image/*" capture="environment" onChange={onIdPick}
              className="block w-full text-sm text-slate-700 file:mr-3 file:py-2 file:px-3 file:rounded-lg file:border-0 file:bg-slate-100 file:text-sm file:font-medium hover:file:bg-slate-200" />
            {idDataUrl && (
              <div className="mt-3 flex items-center gap-3 p-3 bg-slate-50 rounded-lg">
                <img src={idDataUrl} alt="ID preview" className="h-16 w-16 object-cover rounded border border-slate-200" />
                <div className="flex-1 text-sm">
                  <div className="font-medium truncate">{idFileName}</div>
                  <button type="button" onClick={() => { setIdDataUrl(null); setIdFileName(null); }}
                    className="text-xs text-red-600 hover:text-red-800">Remove</button>
                </div>
              </div>
            )}
          </div>

          <label className="flex items-start gap-2 text-xs text-slate-700">
            <input type="checkbox" checked={agreed} onChange={(e) => setAgreed(e.target.checked)}
              className="mt-0.5" />
            <span>
              I confirm the parcel belongs to me and authorize Parsalo and its agent to collect it on
              my behalf, and I take responsibility for any claims arising from this collection.
            </span>
          </label>
        </section>

        <section className="bg-white border border-slate-200 rounded-xl p-5 space-y-2 text-sm">
          <div className="flex justify-between">
            <span className="text-slate-600">Pickup fee</span>
            <span>₹{(pickupFee / 100).toFixed(0)}</span>
          </div>
          {sameDay && (
            <div className="flex justify-between">
              <span className="text-slate-600">Same-day delivery</span>
              <span>₹{(deliveryFee / 100).toFixed(0)}</span>
            </div>
          )}
          <div className="flex justify-between">
            <span className="text-slate-600">GST (18%)</span>
            <span>₹{(gst / 100).toFixed(0)}</span>
          </div>
          <div className="border-t border-slate-200 pt-2 flex justify-between font-bold text-base">
            <span>Total</span>
            <span>₹{(total / 100).toFixed(0)}</span>
          </div>
        </section>

        {error && <p className="text-red-600 text-sm">{error}</p>}
        <button type="submit" disabled={loading}
          className="w-full bg-amber-500 text-white font-semibold py-3 rounded-lg hover:bg-amber-600 disabled:opacity-60">
          {loading ? 'Placing…' : `Place order — ₹${(total / 100).toFixed(0)}`}
        </button>
      </form>
    </div>
  );
}
