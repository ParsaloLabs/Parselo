'use client';
import { useEffect, useState } from 'react';
import { api } from '../../../lib/api';

type Agent = {
  id: string; phone: string; full_name: string; vehicle_type?: string | null;
  is_online: boolean; is_active: boolean; rating: number; total_deliveries: number;
};

export default function AgentsPage() {
  const [agents, setAgents] = useState<Agent[]>([]);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ phone: '', full_name: '', password: '', vehicle_type: 'bike', vehicle_number: '' });

  const load = () => api<Agent[]>('/admin/agents').then(setAgents);
  useEffect(() => { load(); }, []);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api('/admin/agents', { method: 'POST', body: form });
      setCreating(false);
      setForm({ phone: '', full_name: '', password: '', vehicle_type: 'bike', vehicle_number: '' });
      await load();
    } catch (e: any) {
      alert(e.message);
    }
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-4">
        <h1 className="text-2xl font-bold">Agents</h1>
        <button
          className="bg-brand text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-brand-dark"
          onClick={() => setCreating((c) => !c)}
        >
          {creating ? 'Cancel' : 'Add agent'}
        </button>
      </div>
      {creating && (
        <form onSubmit={submit} className="bg-white border border-slate-200 rounded-xl p-4 mb-6 grid grid-cols-2 gap-3">
          <input required placeholder="Phone (+91…)" className="border rounded px-3 py-2" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
          <input required placeholder="Full name" className="border rounded px-3 py-2" value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} />
          <input required placeholder="Password" type="password" className="border rounded px-3 py-2" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} />
          <input placeholder="Vehicle number" className="border rounded px-3 py-2" value={form.vehicle_number} onChange={(e) => setForm({ ...form, vehicle_number: e.target.value })} />
          <select className="border rounded px-3 py-2" value={form.vehicle_type} onChange={(e) => setForm({ ...form, vehicle_type: e.target.value })}>
            <option value="bike">Bike</option>
            <option value="scooter">Scooter</option>
          </select>
          <button type="submit" className="col-span-2 bg-brand text-white py-2 rounded-lg">Create</button>
        </form>
      )}
      <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-slate-600">
            <tr>
              <th className="px-4 py-3">Name</th>
              <th className="px-4 py-3">Phone</th>
              <th className="px-4 py-3">Vehicle</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Deliveries</th>
              <th className="px-4 py-3">Rating</th>
            </tr>
          </thead>
          <tbody>
            {agents.map((a) => (
              <tr key={a.id} className="border-t border-slate-100">
                <td className="px-4 py-3 font-medium">{a.full_name}</td>
                <td className="px-4 py-3">{a.phone}</td>
                <td className="px-4 py-3 capitalize">{a.vehicle_type ?? '—'}</td>
                <td className="px-4 py-3">{a.is_online ? <span className="text-green-600">● online</span> : <span className="text-slate-400">○ offline</span>}</td>
                <td className="px-4 py-3">{a.total_deliveries}</td>
                <td className="px-4 py-3">{Number(a.rating).toFixed(1)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
