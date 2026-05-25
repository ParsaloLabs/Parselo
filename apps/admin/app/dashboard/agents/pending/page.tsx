'use client';
import { useEffect, useState } from 'react';
import { api } from '../../../../lib/api';

type PendingAgent = {
  id: string;
  phone: string;
  full_name: string;
  email: string | null;
  vehicle_type: string | null;
  vehicle_number: string | null;
  dl_number: string | null;
  city: string | null;
  status: 'pending' | 'rejected';
  rejection_reason: string | null;
  created_at: string;
};

export default function PendingAgentsPage() {
  const [agents, setAgents] = useState<PendingAgent[]>([]);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [rejectingId, setRejectingId] = useState<string | null>(null);
  const [reason, setReason] = useState('');

  const load = () => api<PendingAgent[]>('/admin/agents/pending').then(setAgents);
  useEffect(() => { load(); }, []);

  const approve = async (id: string) => {
    if (!confirm('Approve this applicant? They will be able to log in to the agent app.')) return;
    setBusyId(id);
    try {
      await api(`/admin/agents/${id}/approve`, { method: 'POST' });
      await load();
    } catch (e: any) {
      alert(e.message);
    } finally {
      setBusyId(null);
    }
  };

  const submitReject = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!rejectingId) return;
    setBusyId(rejectingId);
    try {
      await api(`/admin/agents/${rejectingId}/reject`, {
        method: 'POST',
        body: { reason },
      });
      setRejectingId(null);
      setReason('');
      await load();
    } catch (e: any) {
      alert(e.message);
    } finally {
      setBusyId(null);
    }
  };

  const pending = agents.filter((a) => a.status === 'pending');
  const rejected = agents.filter((a) => a.status === 'rejected');

  return (
    <div>
      <h1 className="text-2xl font-bold mb-2">Agent applications</h1>
      <p className="text-sm text-slate-500 mb-6">
        New applicants from <code>/agent-signup</code>. Approve to let them log in to the agent app.
      </p>

      <Section title={`Pending (${pending.length})`} empty="No new applications.">
        {pending.map((a) => (
          <Card key={a.id} agent={a}>
            <button
              disabled={busyId === a.id}
              onClick={() => approve(a.id)}
              className="bg-green-600 text-white text-sm font-semibold px-3 py-1.5 rounded-md hover:bg-green-700 disabled:opacity-60"
            >
              Approve
            </button>
            <button
              disabled={busyId === a.id}
              onClick={() => { setRejectingId(a.id); setReason(''); }}
              className="bg-red-50 text-red-700 border border-red-200 text-sm font-semibold px-3 py-1.5 rounded-md hover:bg-red-100 disabled:opacity-60"
            >
              Reject
            </button>
          </Card>
        ))}
      </Section>

      {rejected.length > 0 && (
        <Section title={`Rejected (${rejected.length})`} empty="None.">
          {rejected.map((a) => (
            <Card key={a.id} agent={a}>
              <button
                disabled={busyId === a.id}
                onClick={() => approve(a.id)}
                className="bg-slate-100 text-slate-700 text-sm font-semibold px-3 py-1.5 rounded-md hover:bg-slate-200 disabled:opacity-60"
              >
                Reconsider
              </button>
            </Card>
          ))}
        </Section>
      )}

      {rejectingId && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
          <form onSubmit={submitReject} className="bg-white rounded-xl p-6 w-full max-w-md">
            <h2 className="text-lg font-bold mb-2">Reject applicant</h2>
            <p className="text-sm text-slate-500 mb-4">
              The applicant won't be able to log in. The reason is stored for your records.
            </p>
            <textarea
              required minLength={1} maxLength={500}
              value={reason} onChange={(e) => setReason(e.target.value)}
              rows={3} placeholder="Reason (e.g. incomplete documents)"
              className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm"
            />
            <div className="flex justify-end gap-2 mt-4">
              <button type="button" onClick={() => setRejectingId(null)} className="px-3 py-1.5 text-sm rounded-md hover:bg-slate-100">
                Cancel
              </button>
              <button type="submit" disabled={!reason.trim() || busyId === rejectingId} className="bg-red-600 text-white text-sm font-semibold px-3 py-1.5 rounded-md hover:bg-red-700 disabled:opacity-60">
                Reject
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}

function Section({ title, empty, children }: { title: string; empty: string; children: React.ReactNode }) {
  const arr = Array.isArray(children) ? children : [children];
  return (
    <div className="mb-8">
      <h2 className="text-sm font-semibold text-slate-600 uppercase tracking-wide mb-3">{title}</h2>
      {arr.length === 0 ? (
        <div className="bg-white border border-dashed border-slate-300 rounded-xl p-6 text-center text-sm text-slate-500">{empty}</div>
      ) : (
        <div className="grid gap-3">{children}</div>
      )}
    </div>
  );
}

function Card({ agent, children }: { agent: PendingAgent; children: React.ReactNode }) {
  return (
    <div className="bg-white border border-slate-200 rounded-xl p-4">
      <div className="flex justify-between items-start gap-4">
        <div className="grid grid-cols-2 md:grid-cols-3 gap-x-6 gap-y-2 text-sm flex-1">
          <Detail label="Name" value={agent.full_name} />
          <Detail label="Phone" value={agent.phone} />
          <Detail label="Email" value={agent.email ?? '—'} />
          <Detail label="City" value={agent.city ?? '—'} />
          <Detail label="Vehicle" value={`${agent.vehicle_type ?? '—'} · ${agent.vehicle_number ?? '—'}`} />
          <Detail label="DL number" value={agent.dl_number ?? '—'} />
          <Detail label="Applied" value={new Date(agent.created_at).toLocaleString()} />
          {agent.rejection_reason && <Detail label="Rejected because" value={agent.rejection_reason} />}
        </div>
        <div className="flex flex-col gap-2 shrink-0">{children}</div>
      </div>
    </div>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-xs text-slate-500">{label}</div>
      <div className="font-medium">{value}</div>
    </div>
  );
}
