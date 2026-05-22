'use client';
import Link from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api, setToken, STATUS_LABEL } from '../../lib/api';

type Job = {
  id: string; order_code: string; order_type: 'send' | 'receive';
  status: string; total_amount: number;
  recipient_name?: string | null; delivery_address?: string | null;
  source_tracking_id?: string | null;
};

export default function DashboardPage() {
  const router = useRouter();
  const [online, setOnline] = useState(false);
  const [assigned, setAssigned] = useState<Job[]>([]);
  const [available, setAvailable] = useState<Job[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [pendingJob, setPendingJob] = useState<Job | null>(null);
  const [popupBusy, setPopupBusy] = useState(false);
  const seenIdsRef = useRef<Set<string> | null>(null);
  const dismissedIdsRef = useRef<Set<string>>(new Set());

  const playChime = () => {
    try {
      const Ctx = (window.AudioContext || (window as any).webkitAudioContext) as typeof AudioContext;
      const ctx = new Ctx();
      const note = (freq: number, startAt: number, duration: number) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.value = freq;
        osc.connect(gain);
        gain.connect(ctx.destination);
        const t0 = ctx.currentTime + startAt;
        gain.gain.setValueAtTime(0, t0);
        gain.gain.linearRampToValueAtTime(0.3, t0 + 0.01);
        gain.gain.exponentialRampToValueAtTime(0.01, t0 + duration);
        osc.start(t0);
        osc.stop(t0 + duration);
      };
      note(880, 0, 0.18);
      note(660, 0.18, 0.25);
      setTimeout(() => ctx.close().catch(() => {}), 800);
    } catch {}
  };

  const load = useCallback(async () => {
    try {
      const res = await api<{ assigned: Job[]; available: Job[] }>('/agent/jobs');
      setAssigned(res.assigned);
      setAvailable(res.available);

      const incomingIds = new Set(res.available.map((j) => j.id));
      if (seenIdsRef.current === null) {
        // First load — seed the set, don't pop a modal for jobs that already existed.
        seenIdsRef.current = incomingIds;
      } else {
        const fresh = res.available.find(
          (j) => !seenIdsRef.current!.has(j.id) && !dismissedIdsRef.current.has(j.id),
        );
        if (fresh) {
          setPendingJob((current) => current ?? fresh);
          if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
            try { navigator.vibrate([200, 80, 200]); } catch {}
          }
          playChime();
        }
        seenIdsRef.current = incomingIds;
      }
    } catch (e: any) {
      if (String(e.message).includes('401')) {
        setToken(null);
        router.replace('/login');
        return;
      }
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [router]);

  useEffect(() => {
    load();
    const t = setInterval(load, 8000);
    return () => clearInterval(t);
  }, [load]);

  // Auto-dismiss the popup after 30s so the agent isn't stuck on a stale offer.
  useEffect(() => {
    if (!pendingJob) return;
    const t = setTimeout(() => {
      dismissedIdsRef.current.add(pendingJob.id);
      setPendingJob(null);
    }, 30000);
    return () => clearTimeout(t);
  }, [pendingJob]);

  // Live location ping when online (best-effort).
  useEffect(() => {
    if (!online || typeof navigator === 'undefined' || !navigator.geolocation) return;
    const watch = navigator.geolocation.watchPosition(
      (pos) => {
        api('/agent/location', {
          method: 'POST',
          body: { lat: pos.coords.latitude, lng: pos.coords.longitude },
        }).catch(() => {});
      },
      () => {}, { enableHighAccuracy: true, maximumAge: 30000 },
    );
    return () => navigator.geolocation.clearWatch(watch);
  }, [online]);

  const toggleOnline = async (next: boolean) => {
    setOnline(next);
    try {
      await api('/agent/online-status', { method: 'POST', body: { is_online: next } });
      if (!next) {
        setPendingJob(null);
        dismissedIdsRef.current = new Set();
        seenIdsRef.current = null;
      }
      await load();
    } catch (e: any) {
      setError(e.message);
      setOnline(!next);
    }
  };

  const acceptFromPopup = async (id: string) => {
    setPopupBusy(true);
    try {
      await api(`/agent/jobs/${id}/accept`, { method: 'POST' });
      setPendingJob(null);
      router.push(`/jobs/${id}`);
    } catch (e: any) {
      setError(e.message);
      setPendingJob(null);
    } finally {
      setPopupBusy(false);
    }
  };

  const skipPopup = () => {
    if (!pendingJob) return;
    dismissedIdsRef.current.add(pendingJob.id);
    setPendingJob(null);
  };

  const accept = async (id: string) => {
    try {
      await api(`/agent/jobs/${id}/accept`, { method: 'POST' });
      await load();
    } catch (e: any) {
      setError(e.message);
    }
  };

  return (
    <div>
      <div className={`flex items-center justify-between p-4 rounded-xl mb-4 ${
        online ? 'bg-green-50 border border-green-200' : 'bg-slate-100 border border-slate-200'
      }`}>
        <div>
          <div className="font-semibold">{online ? '🟢 Online · accepting jobs' : '⚪ Offline'}</div>
          <div className="text-xs text-slate-500 mt-0.5">
            {online ? 'Sharing your location with dispatch' : 'Toggle on to receive jobs'}
          </div>
        </div>
        <label className="relative inline-flex items-center cursor-pointer">
          <input type="checkbox" checked={online} onChange={(e) => toggleOnline(e.target.checked)} className="sr-only peer" />
          <div className="w-11 h-6 bg-slate-300 peer-checked:bg-brand rounded-full transition-colors relative">
            <div className={`absolute top-0.5 left-0.5 bg-white w-5 h-5 rounded-full transition-transform ${
              online ? 'translate-x-5' : ''
            }`} />
          </div>
        </label>
      </div>

      {error && <p className="text-red-600 text-sm mb-3">{error}</p>}

      <h2 className="text-sm font-semibold text-slate-500 uppercase mb-2 mt-4">
        Active jobs ({assigned.length})
      </h2>
      {assigned.length === 0 ? (
        <div className="text-sm text-slate-500 mb-4">No active jobs</div>
      ) : (
        <div className="space-y-2 mb-4">
          {assigned.map((j) => (
            <Link key={j.id} href={`/jobs/${j.id}`}
              className="flex items-center bg-white border border-slate-200 rounded-xl p-4 hover:bg-slate-50">
              <div className="text-2xl mr-3">{j.order_type === 'send' ? '📤' : '📥'}</div>
              <div className="flex-1 min-w-0">
                <div className="font-mono text-sm font-bold">{j.order_code}</div>
                <div className="text-xs text-slate-500 truncate">{STATUS_LABEL[j.status] ?? j.status}</div>
              </div>
              <div className="text-brand font-semibold text-sm">Open →</div>
            </Link>
          ))}
        </div>
      )}

      <h2 className="text-sm font-semibold text-slate-500 uppercase mb-2 mt-4">
        Available ({available.length})
      </h2>
      {loading ? (
        <div className="text-sm text-slate-500">Loading…</div>
      ) : available.length === 0 ? (
        <div className="text-sm text-slate-500">Nothing right now. We'll refresh automatically.</div>
      ) : (
        <div className="space-y-2">
          {available.map((j) => (
            <div key={j.id} className="bg-white border border-slate-200 rounded-xl p-4">
              <div className="flex items-center mb-2">
                <div className="text-2xl mr-3">{j.order_type === 'send' ? '📤' : '📥'}</div>
                <div className="flex-1 min-w-0">
                  <div className="font-mono text-sm font-bold">{j.order_code}</div>
                  <div className="text-xs text-slate-500 truncate">
                    {j.order_type === 'send'
                      ? `To ${j.recipient_name ?? '—'}`
                      : `Tracking ${j.source_tracking_id ?? '—'}`}
                  </div>
                </div>
                <div className="font-semibold text-sm">₹{(j.total_amount / 100).toFixed(0)}</div>
              </div>
              <button onClick={() => accept(j.id)}
                className="w-full bg-brand text-white text-sm font-semibold py-2 rounded-lg hover:bg-brand-dark">
                Accept
              </button>
            </div>
          ))}
        </div>
      )}

      {pendingJob && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm md:items-center">
          <div className="w-full md:max-w-md bg-white rounded-t-3xl md:rounded-3xl shadow-2xl animate-[slideup_180ms_ease-out] overflow-hidden">
            <div className="bg-gradient-to-r from-emerald-500 to-emerald-600 text-white px-6 py-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <span className="relative flex h-3 w-3">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-white opacity-60" />
                  <span className="relative inline-flex rounded-full h-3 w-3 bg-white" />
                </span>
                <span className="font-semibold tracking-wide uppercase text-sm">New job available</span>
              </div>
              <button onClick={skipPopup} className="text-white/80 hover:text-white text-xl leading-none">×</button>
            </div>

            <div className="px-6 pt-6 pb-4">
              <div className="text-4xl mb-2">{pendingJob.order_type === 'send' ? '📤' : '📥'}</div>
              <div className="font-mono text-lg font-bold">{pendingJob.order_code}</div>
              <div className="text-sm text-slate-600 mt-1">
                {pendingJob.order_type === 'send'
                  ? `Send → ${pendingJob.recipient_name ?? 'recipient'}`
                  : `Receive → tracking ${pendingJob.source_tracking_id ?? '—'}`}
              </div>
              {pendingJob.delivery_address && (
                <div className="text-xs text-slate-500 mt-1 truncate">{pendingJob.delivery_address}</div>
              )}

              <div className="mt-5 bg-slate-50 rounded-xl p-4 flex items-center justify-between">
                <div>
                  <div className="text-xs text-slate-500 uppercase tracking-wide">Order value</div>
                  <div className="text-2xl font-bold">₹{(pendingJob.total_amount / 100).toFixed(0)}</div>
                </div>
                <div className="text-xs text-slate-500">Auto-dismiss in 30s</div>
              </div>
            </div>

            <div className="px-6 pb-6 grid grid-cols-3 gap-2">
              <button onClick={skipPopup} disabled={popupBusy}
                className="col-span-1 border border-slate-300 text-slate-700 rounded-xl py-3 font-semibold text-sm hover:bg-slate-50 disabled:opacity-60">
                Skip
              </button>
              <button onClick={() => acceptFromPopup(pendingJob.id)} disabled={popupBusy}
                className="col-span-2 bg-emerald-600 text-white rounded-xl py-3 font-bold hover:bg-emerald-700 disabled:opacity-60">
                {popupBusy ? 'Accepting…' : 'Accept job →'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
