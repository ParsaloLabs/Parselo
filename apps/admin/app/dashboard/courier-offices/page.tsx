'use client';
import { useEffect, useState } from 'react';
import { api } from '../../../lib/api';

type Courier = { id: string; name: string };

type Branch = {
  id: string;
  courier_id: string;
  courier_name: string;
  name: string | null;
  district: string | null;
  full_address: string;
  latitude: number | null;
  longitude: number | null;
  pincode: string | null;
  phone: string | null;
  opening_hours: string | null;
};

type FormState = {
  id?: string;
  courier_id: string;
  name: string;
  district: string;
  full_address: string;
  pincode: string;
  phone: string;
  opening_hours: string;
  latitude: string;
  longitude: string;
};

const emptyForm: FormState = {
  courier_id: '',
  name: '',
  district: '',
  full_address: '',
  pincode: '',
  phone: '',
  opening_hours: '',
  latitude: '',
  longitude: '',
};

export default function CourierOfficesPage() {
  const [branches, setBranches] = useState<Branch[] | null>(null);
  const [couriers, setCouriers] = useState<Courier[]>([]);
  const [radiusEnabled, setRadiusEnabled] = useState<boolean | null>(null);
  const [togglingRadius, setTogglingRadius] = useState(false);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [saving, setSaving] = useState(false);
  const [locating, setLocating] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [savedAt, setSavedAt] = useState<string | null>(null);

  const load = async () => {
    const [b, c, flags] = await Promise.all([
      api<Branch[]>('/admin/courier-branches'),
      api<Courier[]>('/couriers', { auth: false }),
      api<Record<string, unknown>>('/admin/flags'),
    ]);
    setBranches(b);
    setCouriers(c);
    setRadiusEnabled(flags?.service_area_radius_enabled === true);
    if (!form.courier_id && c.length > 0) {
      setForm((f) => ({ ...f, courier_id: c[0].id }));
    }
  };

  const toggleRadius = async () => {
    if (radiusEnabled === null) return;
    setTogglingRadius(true);
    setError(null);
    const next = !radiusEnabled;
    try {
      await api('/admin/flags/service_area_radius_enabled', {
        method: 'PUT',
        body: { value: next },
      });
      setRadiusEnabled(next);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setTogglingRadius(false);
    }
  };

  useEffect(() => {
    load().catch((e) => setError(e.message));
  }, []);

  const startNew = () => {
    setForm({ ...emptyForm, courier_id: couriers[0]?.id ?? '' });
    setSavedAt(null);
    setError(null);
  };

  const startEdit = (b: Branch) => {
    setForm({
      id: b.id,
      courier_id: b.courier_id,
      name: b.name ?? '',
      district: b.district ?? '',
      full_address: b.full_address,
      pincode: b.pincode ?? '',
      phone: b.phone ?? '',
      opening_hours: b.opening_hours ?? '',
      latitude: b.latitude !== null ? String(b.latitude) : '',
      longitude: b.longitude !== null ? String(b.longitude) : '',
    });
    setSavedAt(null);
    setError(null);
    if (typeof window !== 'undefined') window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });
  };

  const useMyLocation = () => {
    if (!navigator.geolocation) {
      setError('Geolocation is not available in this browser.');
      return;
    }
    setError(null);
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setForm((f) => ({
          ...f,
          latitude: pos.coords.latitude.toFixed(7),
          longitude: pos.coords.longitude.toFixed(7),
        }));
        setLocating(false);
      },
      (err) => {
        setError(err.message || 'Could not get current location.');
        setLocating(false);
      },
      { enableHighAccuracy: true, timeout: 10_000 },
    );
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSaving(true);
    try {
      const payload = {
        id: form.id,
        courier_id: form.courier_id,
        name: form.name.trim(),
        district: form.district.trim(),
        full_address: form.full_address.trim(),
        pincode: form.pincode.trim(),
        phone: form.phone.trim() || undefined,
        opening_hours: form.opening_hours.trim() || undefined,
        latitude: parseFloat(form.latitude),
        longitude: parseFloat(form.longitude),
      };
      await api('/admin/courier-branches', { method: 'POST', body: payload });
      await load();
      setSavedAt(new Date().toLocaleTimeString());
      if (!form.id) {
        setForm({ ...emptyForm, courier_id: payload.courier_id });
      }
    } catch (e: any) {
      setError(e.message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (id: string) => {
    if (!confirm('Delete this courier office? Orders already pointing at it will keep the reference but the office will disappear from the customer picker.')) return;
    setError(null);
    try {
      await api(`/admin/courier-branches/${id}`, { method: 'DELETE' });
      await load();
      if (form.id === id) startNew();
    } catch (e: any) {
      setError(e.message);
    }
  };

  if (!branches) {
    return (
      <div>
        <h1 className="text-2xl font-bold mb-2">Courier offices</h1>
        <p className="text-sm text-slate-500">{error ?? 'Loading…'}</p>
      </div>
    );
  }

  return (
    <div className="max-w-5xl">
      <h1 className="text-2xl font-bold mb-2">Courier offices</h1>
      <p className="text-sm text-slate-500 mb-6">
        Physical drop-off offices (DTDC, Bluedart, etc.). Customers placing a send order pick the
        nearest one from this list, ranked by distance from their pickup pin.
      </p>

      <div className="bg-white border border-slate-200 rounded-xl p-5 mb-6 flex items-start gap-4">
        <div className="flex-1">
          <div className="text-sm font-semibold text-slate-800">15 km radius gate</div>
          <p className="text-xs text-slate-500 mt-1 leading-relaxed">
            <strong>Off (default):</strong> any pin in a district where we have ≥1 active office is in-zone — district-wide gating.<br />
            <strong>On:</strong> stricter — pin must also be within 15 km of an active office. Use this when launching a single neighborhood inside a larger district.
          </p>
        </div>
        <button
          type="button"
          onClick={toggleRadius}
          disabled={togglingRadius || radiusEnabled === null}
          className={`shrink-0 inline-flex items-center gap-2 px-4 py-2 rounded-md text-sm font-semibold border transition ${
            radiusEnabled
              ? 'bg-brand text-white border-brand'
              : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-50'
          } disabled:opacity-60`}
        >
          <span
            className={`inline-block w-8 h-4 rounded-full relative transition ${
              radiusEnabled ? 'bg-white/30' : 'bg-slate-300'
            }`}
          >
            <span
              className={`absolute top-0.5 w-3 h-3 rounded-full bg-white transition ${
                radiusEnabled ? 'left-4' : 'left-0.5'
              }`}
            />
          </span>
          {radiusEnabled === null ? '…' : radiusEnabled ? 'Radius ON' : 'Radius OFF'}
        </button>
      </div>

      <div className="bg-white border border-slate-200 rounded-xl overflow-hidden mb-8">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-slate-600 text-xs uppercase">
            <tr>
              <th className="text-left px-4 py-2">Courier</th>
              <th className="text-left px-4 py-2">Office</th>
              <th className="text-left px-4 py-2">District</th>
              <th className="text-left px-4 py-2">Address</th>
              <th className="text-left px-4 py-2">Coords</th>
              <th className="text-left px-4 py-2">Phone</th>
              <th className="px-4 py-2"></th>
            </tr>
          </thead>
          <tbody>
            {branches.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-6 text-center text-slate-500">
                  No offices added yet — fill the form below.
                </td>
              </tr>
            ) : (
              branches.map((b) => (
                <tr key={b.id} className="border-t border-slate-100 align-top">
                  <td className="px-4 py-3 font-medium">{b.courier_name}</td>
                  <td className="px-4 py-3">{b.name ?? '—'}</td>
                  <td className="px-4 py-3">{b.district ?? '—'}</td>
                  <td className="px-4 py-3 text-slate-600 max-w-xs">
                    <div className="line-clamp-2">{b.full_address}</div>
                    {b.pincode && <div className="text-xs text-slate-500">PIN {b.pincode}</div>}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs">
                    {b.latitude !== null && b.longitude !== null
                      ? `${b.latitude.toFixed(4)}, ${b.longitude.toFixed(4)}`
                      : '—'}
                  </td>
                  <td className="px-4 py-3 text-xs">{b.phone ?? '—'}</td>
                  <td className="px-4 py-3 text-right whitespace-nowrap">
                    <button
                      onClick={() => startEdit(b)}
                      className="text-xs text-brand hover:underline mr-3"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => remove(b.id)}
                      className="text-xs text-red-600 hover:underline"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <form onSubmit={save} className="bg-white border border-slate-200 rounded-xl p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-slate-600 uppercase tracking-wide">
            {form.id ? 'Edit office' : 'Add office'}
          </h2>
          {form.id && (
            <button
              type="button"
              onClick={startNew}
              className="text-xs text-slate-500 hover:text-slate-900"
            >
              Cancel — add new instead
            </button>
          )}
        </div>

        <div className="grid grid-cols-2 gap-5">
          <Field label="Courier" help="Brand. Manage the list under couriers (DB seed).">
            <select
              required
              value={form.courier_id}
              onChange={(e) => setForm({ ...form, courier_id: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full bg-white"
            >
              {couriers.length === 0 && <option value="">No couriers configured</option>}
              {couriers.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </Field>

          <Field label="District" help="e.g. Thrissur, Ernakulam. Used to group the list.">
            <input
              type="text"
              required
              minLength={2}
              maxLength={80}
              value={form.district}
              onChange={(e) => setForm({ ...form, district: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full"
            />
          </Field>

          <Field label="Office name" help="e.g. DTDC Round North, Bluedart Patturaikkal.">
            <input
              type="text"
              required
              minLength={2}
              maxLength={255}
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full"
            />
          </Field>

          <Field label="Pincode" help="6 digits.">
            <input
              type="text"
              required
              pattern="\d{6}"
              maxLength={6}
              value={form.pincode}
              onChange={(e) => setForm({ ...form, pincode: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full"
            />
          </Field>
        </div>

        <div className="grid grid-cols-1 gap-5 mt-5">
          <Field label="Full address" help="What the agent sees on their map card.">
            <textarea
              required
              minLength={5}
              maxLength={500}
              rows={2}
              value={form.full_address}
              onChange={(e) => setForm({ ...form, full_address: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full"
            />
          </Field>
        </div>

        <div className="grid grid-cols-2 gap-5 mt-5">
          <Field label="Phone (optional)" help="Office landline / desk number.">
            <input
              type="text"
              maxLength={15}
              value={form.phone}
              onChange={(e) => setForm({ ...form, phone: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full"
            />
          </Field>

          <Field label="Opening hours (optional)" help="e.g. Mon–Sat 9 am – 7 pm.">
            <input
              type="text"
              maxLength={120}
              value={form.opening_hours}
              onChange={(e) => setForm({ ...form, opening_hours: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full"
            />
          </Field>
        </div>

        <div className="mt-5">
          <div className="flex items-center justify-between mb-2">
            <div>
              <label className="block text-sm font-medium text-slate-800">Location</label>
              <p className="text-xs text-slate-500">
                Decimal degrees. Use "Get current location" while standing at the office, or paste from Google Maps.
              </p>
            </div>
            <button
              type="button"
              onClick={useMyLocation}
              disabled={locating}
              className="text-xs bg-slate-100 hover:bg-slate-200 px-3 py-1.5 rounded-md disabled:opacity-60"
            >
              {locating ? 'Locating…' : '📍 Get current location'}
            </button>
          </div>
          <div className="grid grid-cols-2 gap-5">
            <input
              type="number"
              step="0.0000001"
              min="-90"
              max="90"
              required
              placeholder="Latitude"
              value={form.latitude}
              onChange={(e) => setForm({ ...form, latitude: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full font-mono"
            />
            <input
              type="number"
              step="0.0000001"
              min="-180"
              max="180"
              required
              placeholder="Longitude"
              value={form.longitude}
              onChange={(e) => setForm({ ...form, longitude: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full font-mono"
            />
          </div>
        </div>

        <div className="flex items-center gap-4 mt-6">
          <button
            type="submit"
            disabled={saving || !form.courier_id}
            className="bg-brand text-white text-sm font-semibold px-4 py-2 rounded-md hover:opacity-90 disabled:opacity-60"
          >
            {saving ? 'Saving…' : form.id ? 'Save changes' : 'Add office'}
          </button>
          {savedAt && !saving && (
            <span className="text-xs text-green-700">Saved at {savedAt}</span>
          )}
          {error && <span className="text-xs text-red-700">{error}</span>}
        </div>
      </form>
    </div>
  );
}

function Field({
  label,
  help,
  children,
}: {
  label: string;
  help: string;
  children: React.ReactNode;
}) {
  return (
    <div>
      <label className="block text-sm font-medium text-slate-800 mb-1">{label}</label>
      <p className="text-xs text-slate-500 mb-2">{help}</p>
      {children}
    </div>
  );
}
