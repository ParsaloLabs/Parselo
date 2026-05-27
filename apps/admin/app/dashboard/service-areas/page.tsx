'use client';
import { useEffect, useState } from 'react';
import { api } from '../../../lib/api';

type ServiceArea = {
  id: string;
  name: string;
  center_lat: number;
  center_lng: number;
  radius_m: number;
  is_active: boolean;
  updated_at: string;
};

type FormState = {
  id?: string;
  name: string;
  center_lat: string;
  center_lng: string;
  radius_km: string;
  is_active: boolean;
};

const emptyForm: FormState = {
  name: '',
  center_lat: '',
  center_lng: '',
  radius_km: '15',
  is_active: true,
};

export default function ServiceAreasPage() {
  const [areas, setAreas] = useState<ServiceArea[] | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [savedAt, setSavedAt] = useState<string | null>(null);

  const load = async () => {
    const data = await api<ServiceArea[]>('/admin/service-areas');
    setAreas(data);
  };

  useEffect(() => {
    load().catch((e) => setError(e.message));
  }, []);

  const startNew = () => {
    setForm(emptyForm);
    setSavedAt(null);
    setError(null);
  };

  const startEdit = (a: ServiceArea) => {
    setForm({
      id: a.id,
      name: a.name,
      center_lat: a.center_lat.toString(),
      center_lng: a.center_lng.toString(),
      radius_km: (a.radius_m / 1000).toString(),
      is_active: a.is_active,
    });
    setSavedAt(null);
    setError(null);
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSaving(true);
    try {
      const payload = {
        id: form.id,
        name: form.name.trim(),
        center_lat: parseFloat(form.center_lat),
        center_lng: parseFloat(form.center_lng),
        radius_m: Math.round(parseFloat(form.radius_km) * 1000),
        is_active: form.is_active,
      };
      await api('/admin/service-areas', { method: 'POST', body: payload });
      await load();
      setSavedAt(new Date().toLocaleTimeString());
      if (!form.id) setForm(emptyForm);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (id: string) => {
    if (!confirm('Delete this service area? Order-create will reject pickups/deliveries inside it.')) return;
    setError(null);
    try {
      await api(`/admin/service-areas/${id}`, { method: 'DELETE' });
      await load();
      if (form.id === id) setForm(emptyForm);
    } catch (e: any) {
      setError(e.message);
    }
  };

  if (!areas) {
    return (
      <div>
        <h1 className="text-2xl font-bold mb-2">Service areas</h1>
        <p className="text-sm text-slate-500">{error ?? 'Loading…'}</p>
      </div>
    );
  }

  return (
    <div className="max-w-4xl">
      <h1 className="text-2xl font-bold mb-2">Service areas</h1>
      <p className="text-sm text-slate-500 mb-6">
        Define the zones where Parsalo agents operate. Pickups (send) and deliveries (receive) outside
        every active zone are rejected at order create. Changes apply within ~10 seconds.
      </p>

      <div className="bg-white border border-slate-200 rounded-xl overflow-hidden mb-8">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-slate-600 text-xs uppercase">
            <tr>
              <th className="text-left px-4 py-2">Name</th>
              <th className="text-left px-4 py-2">Centre (lat, lng)</th>
              <th className="text-left px-4 py-2">Radius</th>
              <th className="text-left px-4 py-2">Status</th>
              <th className="text-left px-4 py-2">Updated</th>
              <th className="px-4 py-2"></th>
            </tr>
          </thead>
          <tbody>
            {areas.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-center text-slate-500">
                  No zones yet — add one below.
                </td>
              </tr>
            ) : (
              areas.map((a) => (
                <tr key={a.id} className="border-t border-slate-100">
                  <td className="px-4 py-3 font-medium">{a.name}</td>
                  <td className="px-4 py-3 font-mono text-xs">
                    {a.center_lat.toFixed(4)}, {a.center_lng.toFixed(4)}
                  </td>
                  <td className="px-4 py-3">{(a.radius_m / 1000).toFixed(1)} km</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium ${
                        a.is_active ? 'bg-green-100 text-green-800' : 'bg-slate-200 text-slate-600'
                      }`}
                    >
                      {a.is_active ? 'Active' : 'Disabled'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs text-slate-500">
                    {new Date(a.updated_at).toLocaleString()}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      onClick={() => startEdit(a)}
                      className="text-xs text-brand hover:underline mr-3"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => remove(a.id)}
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
            {form.id ? 'Edit zone' : 'Add zone'}
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
          <Field label="Name" help="Shown to ops only (e.g. Thrissur, Ernakulam).">
            <input
              type="text"
              required
              minLength={2}
              maxLength={60}
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full"
            />
          </Field>

          <Field label="Radius (km)" help="500 m to 200 km. Customers outside this circle see the bottom sheet.">
            <input
              type="number"
              step="0.1"
              min="0.5"
              max="200"
              required
              value={form.radius_km}
              onChange={(e) => setForm({ ...form, radius_km: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full"
            />
          </Field>

          <Field label="Centre latitude" help="Decimal degrees, -90 to 90.">
            <input
              type="number"
              step="0.0000001"
              min="-90"
              max="90"
              required
              value={form.center_lat}
              onChange={(e) => setForm({ ...form, center_lat: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full font-mono"
            />
          </Field>

          <Field label="Centre longitude" help="Decimal degrees, -180 to 180.">
            <input
              type="number"
              step="0.0000001"
              min="-180"
              max="180"
              required
              value={form.center_lng}
              onChange={(e) => setForm({ ...form, center_lng: e.target.value })}
              className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-full font-mono"
            />
          </Field>
        </div>

        <label className="flex items-center gap-2 mt-5 text-sm">
          <input
            type="checkbox"
            checked={form.is_active}
            onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
          />
          Active — orders inside this zone are accepted
        </label>

        <div className="flex items-center gap-4 mt-6">
          <button
            type="submit"
            disabled={saving}
            className="bg-brand text-white text-sm font-semibold px-4 py-2 rounded-md hover:opacity-90 disabled:opacity-60"
          >
            {saving ? 'Saving…' : form.id ? 'Save changes' : 'Add zone'}
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
