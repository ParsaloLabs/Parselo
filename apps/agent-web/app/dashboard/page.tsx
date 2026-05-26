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
  parcel_description?: string | null;
  offer_id?: string | null;
  offer_distance_m?: number | null;
  offer_expires_at?: string | null;
  offer_rank?: number | null;
};

const DEFAULT_OFFER_TTL = 30;

type ProfitData = {
  totalProfits: number;
  dailyProfits: Record<string, number>;
};

export default function DashboardPage() {
  const router = useRouter();
  const [online, setOnline] = useState(false);
  const [assigned, setAssigned] = useState<Job[]>([]);
  const [offered, setOffered] = useState<Job[]>([]);
  const [profits, setProfits] = useState<ProfitData>({ totalProfits: 0, dailyProfits: {} });
  const [showCalendar, setShowCalendar] = useState(false);
  const [currentMonthDate, setCurrentMonthDate] = useState(new Date());
  const [timeLeft, setTimeLeft] = useState(DEFAULT_OFFER_TTL);
  const [totalSeconds, setTotalSeconds] = useState(DEFAULT_OFFER_TTL);
  const [swipeState, setSwipeState] = useState<{ id: string; direction: 'left' | 'right' } | null>(null);
  
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
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
      const res = await api<{ assigned: Job[]; offered: Job[] }>('/agent/jobs');
      setAssigned(res.assigned ?? []);
      const incoming = res.offered ?? [];
      setOffered(incoming);

      // Load profits
      const profitRes = await api<ProfitData>('/agent/profits');
      setProfits(profitRes);

      const incomingIds = new Set(incoming.map((j) => j.id));
      if (seenIdsRef.current === null) {
        seenIdsRef.current = incomingIds;
      } else {
        const fresh = incoming.find(
          (j) => !seenIdsRef.current!.has(j.id) && !dismissedIdsRef.current.has(j.id),
        );
        if (fresh) {
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

  // Live location ping when online
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
        dismissedIdsRef.current = new Set();
        seenIdsRef.current = null;
      }
      await load();
    } catch (e: any) {
      setError(e.message);
      setOnline(!next);
    }
  };

  const accept = async (id: string) => {
    try {
      await api(`/agent/jobs/${id}/accept`, { method: 'POST' });
      await load();
      router.push(`/jobs/${id}`);
    } catch (e: any) {
      setError(e.message);
    }
  };

  const skipPopup = (id: string) => {
    dismissedIdsRef.current.add(id);
    setOffered((current) => current.filter((j) => j.id !== id));
    // Tell the server so the dispatcher can re-offer to the next agent.
    // Fire-and-forget: TTL sweep reclaims the offer if this call fails.
    api(`/agent/jobs/${id}/decline`, { method: 'POST' }).catch(() => {});
  };

  const handleAccept = useCallback(async (id: string) => {
    if (swipeState) return;
    setSwipeState({ id, direction: 'right' });
    setTimeout(async () => {
      await accept(id);
      setSwipeState(null);
    }, 350);
  }, [swipeState]);

  const handleSkip = useCallback((id: string) => {
    if (swipeState) return;
    setSwipeState({ id, direction: 'left' });
    setTimeout(() => {
      skipPopup(id);
      setSwipeState(null);
    }, 350);
  }, [swipeState]);

  const visibleOffered = offered.filter((j) => !dismissedIdsRef.current.has(j.id));

  const topJob = visibleOffered[0];
  const topJobId = topJob?.id;
  const topExpiresAt = topJob?.offer_expires_at ?? null;

  useEffect(() => {
    if (!topJobId || !online) {
      setTimeLeft(DEFAULT_OFFER_TTL);
      setTotalSeconds(DEFAULT_OFFER_TTL);
      return;
    }

    // Drive the countdown from the server-supplied expiry so all polling
    // clients converge on the same auto-skip moment.
    const computeRemaining = () => {
      if (!topExpiresAt) return DEFAULT_OFFER_TTL;
      const ms = new Date(topExpiresAt).getTime() - Date.now();
      return Math.max(0, Math.ceil(ms / 1000));
    };
    const initial = computeRemaining();
    setTotalSeconds(initial > DEFAULT_OFFER_TTL ? initial : DEFAULT_OFFER_TTL);
    setTimeLeft(initial);
    if (initial <= 0) {
      // Server will reap on its sweep; just hide locally.
      dismissedIdsRef.current.add(topJobId);
      setOffered((cur) => cur.filter((j) => j.id !== topJobId));
      return;
    }
    const interval = setInterval(() => {
      const next = computeRemaining();
      setTimeLeft(next);
      if (next <= 0) {
        clearInterval(interval);
        dismissedIdsRef.current.add(topJobId);
        setOffered((cur) => cur.filter((j) => j.id !== topJobId));
      }
    }, 1000);

    return () => clearInterval(interval);
  }, [topJobId, topExpiresAt, online]);

  // Calendar calculations
  const year = currentMonthDate.getFullYear();
  const month = currentMonthDate.getMonth();
  const numDays = new Date(year, month + 1, 0).getDate();
  const startDayOfWeek = new Date(year, month, 1).getDay();

  const calendarDays: (Date | null)[] = [];
  for (let i = 0; i < startDayOfWeek; i++) {
    calendarDays.push(null);
  }
  for (let i = 1; i <= numDays; i++) {
    calendarDays.push(new Date(year, month, i));
  }

  const prevMonth = (e: React.MouseEvent) => {
    e.stopPropagation();
    setCurrentMonthDate(new Date(year, month - 1, 1));
  };
  
  const nextMonth = (e: React.MouseEvent) => {
    e.stopPropagation();
    setCurrentMonthDate(new Date(year, month + 1, 1));
  };

  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  return (
    <div className="space-y-4 sm:space-y-6">
      {/* Premium Compact Gradient Hero Section */}
      <div className="relative overflow-hidden bg-gradient-to-tr from-brand-dark via-brand to-emerald-500 rounded-2xl p-3.5 sm:p-5 text-white shadow-lg">
        <div className="relative z-10 flex items-center justify-between gap-4">
          <div className="min-w-0">
            <span className="text-[9px] sm:text-xs font-bold uppercase tracking-widest text-emerald-200">Delivery Partner Console</span>
            <h1 className="text-lg sm:text-2xl font-black mt-0.5 leading-tight">Hello, welcome back!</h1>
            <p className="hidden sm:block text-xs text-white/80 mt-1">Manage active orders, track daily earnings, and accept incoming gigs.</p>
          </div>
          <div className="flex items-center gap-2 sm:gap-3.5 bg-white/10 backdrop-blur-md border border-white/10 rounded-xl px-2.5 py-1.5 sm:p-3 sm:px-4 shrink-0">
            <div className="text-right">
              <span className="block text-[8px] sm:text-[9px] uppercase font-bold text-emerald-200 tracking-wider">Duty Status</span>
              <span className="block font-extrabold text-[10px] sm:text-xs mt-0.5">{online ? '🟢 ONLINE' : '⚪ OFFLINE'}</span>
            </div>
            <label className="relative inline-flex items-center cursor-pointer">
              <input type="checkbox" checked={online} onChange={(e) => toggleOnline(e.target.checked)} className="sr-only peer" />
              <div className="w-9 h-5 sm:w-11 sm:h-6 bg-white/20 peer-checked:bg-white rounded-full transition-colors relative border border-white/20">
                <div className={`absolute top-0.5 left-0.5 bg-brand w-4 h-4 sm:w-5 sm:h-5 rounded-full transition-all ${
                  online ? 'translate-x-4 bg-emerald-600 sm:translate-x-5' : ''
                }`} />
              </div>
            </label>
          </div>
        </div>
        {/* Subtle background graphics */}
        <div className="absolute right-0 bottom-0 opacity-10 transform translate-x-12 translate-y-12">
          <svg className="w-64 h-64" fill="currentColor" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="40" />
          </svg>
        </div>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl p-3.5 flex items-start gap-2 shadow-sm">
          <span className="text-sm">⚠️</span>
          <div>
            <strong className="font-semibold">Error status:</strong> {error}
          </div>
        </div>
      )}

      {/* Profits Tracker Card with Expanding Calendar */}
      <div 
        onClick={() => setShowCalendar(!showCalendar)}
        className="bg-white border border-slate-200/80 rounded-2xl p-4 sm:p-5 shadow-sm hover:shadow-md cursor-pointer transition-all active:scale-[0.99] group overflow-hidden"
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 sm:h-12 sm:w-12 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center text-lg sm:text-xl font-bold">
              ₹
            </div>
            <div>
              <span className="text-[10px] sm:text-xs font-bold text-slate-400 uppercase tracking-wider block">Total Profits</span>
              <span className="text-xl sm:text-3xl font-black text-slate-800 leading-tight">₹{profits.totalProfits.toLocaleString('en-IN')}</span>
            </div>
          </div>
          <div className="flex items-center gap-1.5 text-xs font-bold text-brand bg-brand/5 group-hover:bg-brand/10 px-2.5 py-1 rounded-lg transition-colors">
            {showCalendar ? 'Hide details' : 'Show Calendar'}
            <span className={`transform transition-transform duration-200 ${showCalendar ? 'rotate-180' : ''}`}>▼</span>
          </div>
        </div>

        {/* Interactive calendar popup/expand */}
        {showCalendar && (
          <div className="mt-5 pt-5 border-t border-slate-100 animate-[fadein_200ms_ease-out]" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-bold text-slate-800 text-sm">
                Earnings Heatmap: {monthNames[month]} {year}
              </h3>
              <div className="flex gap-1.5">
                <button onClick={prevMonth} className="p-1 px-2.5 rounded-lg bg-slate-50 border border-slate-200 text-xs font-bold hover:bg-slate-100">&lt;</button>
                <button onClick={nextMonth} className="p-1 px-2.5 rounded-lg bg-slate-50 border border-slate-200 text-xs font-bold hover:bg-slate-100">&gt;</button>
              </div>
            </div>
            
            {/* Week header */}
            <div className="grid grid-cols-7 gap-1 text-center text-[10px] font-bold text-slate-400 uppercase mb-2">
              <div>Sun</div><div>Mon</div><div>Tue</div><div>Wed</div><div>Thu</div><div>Fri</div><div>Sat</div>
            </div>

            {/* Days Grid */}
            <div className="grid grid-cols-7 gap-1">
              {calendarDays.map((date, idx) => {
                if (!date) return <div key={`empty-${idx}`} className="aspect-square bg-slate-50/50 rounded-lg" />;
                
                const dString = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
                const profitAmt = profits.dailyProfits[dString] || 0;
                const hasProfit = profitAmt > 0;
                
                return (
                  <div 
                    key={dString} 
                    className={`aspect-square rounded-lg flex flex-col justify-between p-1.5 border transition-all ${
                      hasProfit 
                        ? 'bg-emerald-50 border-emerald-200/60 shadow-xs' 
                        : 'bg-white border-slate-100 hover:bg-slate-50'
                    }`}
                  >
                    <span className={`text-[10px] font-bold ${hasProfit ? 'text-emerald-700' : 'text-slate-400'}`}>
                      {date.getDate()}
                    </span>
                    {hasProfit && (
                      <span className="text-[9px] font-black text-emerald-600 truncate block text-center bg-emerald-500/10 rounded-md py-0.5">
                        ₹{profitAmt}
                      </span>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>

      {/* Active Jobs Section */}
      <div>
        <h2 className="text-xs font-black text-slate-400 uppercase tracking-widest mb-3">
          Assigned Tasks ({assigned.length})
        </h2>
        {assigned.length === 0 ? (
          <div className="bg-slate-50 border border-slate-200/60 rounded-2xl p-6 text-center">
            <span className="text-2xl block mb-1">📦</span>
            <span className="text-xs text-slate-500 font-medium">No assigned delivery tasks at the moment. Ready for next orders.</span>
          </div>
        ) : (
          <div className="space-y-3">
            {assigned.map((j) => (
              <Link 
                key={j.id} href={`/jobs/${j.id}`}
                className="flex items-center justify-between bg-white border border-slate-200/80 rounded-2xl p-4.5 hover:bg-slate-50 transition-all hover:translate-x-1 active:scale-[0.99] shadow-xs group"
              >
                <div className="flex items-center gap-3.5 min-w-0">
                  <div className={`h-11 w-11 rounded-xl flex items-center justify-center text-xl shadow-xs ${
                    j.order_type === 'send' ? 'bg-amber-50 text-amber-600' : 'bg-brand/10 text-brand'
                  }`}>
                    {j.order_type === 'send' ? '📤' : '📥'}
                  </div>
                  <div className="min-w-0">
                    <div className="font-mono text-sm font-extrabold text-slate-800 leading-none">{j.order_code}</div>
                    <div className="text-[11px] text-slate-400 mt-1 font-semibold uppercase tracking-wider">
                      {STATUS_LABEL[j.status] ?? j.status}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-[10px] font-bold text-brand bg-brand/5 px-2.5 py-1 rounded-lg group-hover:bg-brand/10 transition-colors">
                    Manage →
                  </span>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>

      {/* Main Feature: accepting or rejecting incoming order with ScrollStack */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-xs font-black text-slate-400 uppercase tracking-widest">
            Incoming Job Queue ({visibleOffered.length})
          </h2>
        </div>

        {!online ? (
          <div className="bg-slate-100/80 border border-slate-200 border-dashed rounded-2xl p-8 text-center">
            <span className="text-2xl block mb-1">📴</span>
            <span className="text-xs text-slate-500 font-bold block">You are offline.</span>
            <span className="text-[10px] text-slate-400 mt-1 block">Toggle duty switch to "Active & Online" to view the incoming job stack.</span>
          </div>
        ) : loading ? (
          <div className="text-center py-8 text-xs text-slate-400 font-semibold animate-pulse">Loading Gigs Queue…</div>
        ) : visibleOffered.length === 0 ? (
          <div className="bg-slate-50 border border-slate-200/60 rounded-2xl p-10 text-center">
            <div className="animate-bounce text-2xl mb-2">🔭</div>
            <strong className="text-xs text-slate-600 block">Scanning Thrissur area...</strong>
            <span className="text-[10px] text-slate-400 mt-1 block">No matches right now. Keep this open, new jobs refresh automatically.</span>
          </div>
        ) : (
          <div className="w-full flex flex-row overflow-x-auto gap-0 py-4 px-4 scroll-smooth scrollbar-none mt-2 relative">
            {visibleOffered.map((j, idx) => {
              const isSwiping = swipeState?.id === j.id;
              const swipeDir = swipeState?.direction;

              // Progressive left offset so cards stack fanned out on the left edge when scrolled
              const leftOffset = 16 + idx * 20;

              let transform = 'none';
              let opacity = 1;

              if (isSwiping) {
                if (swipeDir === 'left') {
                  // Reject swipe: animate far left with slight rotation
                  transform = 'translate3d(-140%, 15px, 0) rotate(-12deg) scale(0.95)';
                  opacity = 0;
                } else {
                  // Accept swipe: animate far right with slight rotation
                  transform = 'translate3d(140%, 15px, 0) rotate(12deg) scale(0.95)';
                  opacity = 0;
                }
              }

              return (
                <div
                  key={j.id}
                  style={{
                    position: 'sticky',
                    left: `${leftOffset}px`,
                    transform,
                    opacity,
                    transition: 'transform 380ms cubic-bezier(0.16, 1, 0.3, 1), opacity 380ms ease',
                  }}
                  className="shrink-0 w-[82%] xs:w-[80%] max-w-[315px] bg-white border border-slate-200/80 rounded-[24px] p-4 sm:p-5 shadow-[0_8px_24px_rgba(0,0,0,0.04)] flex flex-col h-[290px] sm:h-[305px] justify-between overflow-hidden mr-12"
                >
                  {/* Premium, highly minimalistic top-edge horizontal gradient progress timer */}
                  {idx === 0 && (
                    <div className="absolute top-0 left-0 w-full h-[3px] bg-slate-100 overflow-hidden z-30">
                      <div 
                        className="h-full bg-gradient-to-r from-brand to-emerald-500 transition-all duration-1000 ease-linear" 
                        style={{ width: `${(timeLeft / Math.max(totalSeconds, 1)) * 100}%` }}
                      />
                    </div>
                  )}

                  <div className="flex flex-col h-full justify-between relative overflow-hidden">
                    {/* Upper Section */}
                    <div className="flex justify-between items-start gap-4 pt-1">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-1.5 flex-wrap mb-2">
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-brand/10 text-brand">
                            {j.order_type === 'send' ? '📤 Dispatch Send' : '📥 Partner Collect'}
                          </span>
                          {typeof j.offer_distance_m === 'number' && (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-50 border border-slate-200 text-slate-700">
                              📍 {j.offer_distance_m < 1000
                                ? `${j.offer_distance_m} m`
                                : `${(j.offer_distance_m / 1000).toFixed(j.offer_distance_m < 10000 ? 1 : 0)} km`} away
                            </span>
                          )}
                        </div>
                        <h3 className="font-mono text-base font-bold text-slate-800 tracking-tight">{j.order_code}</h3>
                        <p className="text-xs text-slate-500 mt-1 truncate">
                          <strong>Item:</strong> {j.parcel_description || 'Package'}
                        </p>
                      </div>
                      <div className="text-right">
                        <span className="text-2xl font-black text-emerald-600 block">₹{(j.total_amount / 100).toFixed(0)}</span>
                        <span className="text-[10px] text-slate-400 font-medium uppercase tracking-wider mt-0.5 block">Payout</span>
                      </div>
                    </div>

                    {/* Location Info */}
                    <div className="my-2.5 space-y-1.5 border-t border-slate-100 pt-2.5">
                      <div className="flex items-start gap-2 text-xs">
                        <span className="text-emerald-500 font-bold">From:</span>
                        <span className="text-slate-600 font-medium truncate">
                          {j.order_type === 'send' ? 'Customer Address' : (j.source_tracking_id ? `Courier branch` : 'Sender Address')}
                        </span>
                      </div>
                      <div className="flex items-start gap-2 text-xs">
                        <span className="text-rose-500 font-bold">To:</span>
                        <span className="text-slate-600 font-medium truncate">
                          {j.delivery_address || 'Destination'}
                        </span>
                      </div>
                    </div>

                    {/* Interactive Buttons at bottom */}
                    <div className="flex items-center justify-between border-t border-slate-100 pt-2.5 mt-0.5">
                      {/* Reject Button (Red Cross on Left) */}
                      <button 
                        onClick={(e) => { e.stopPropagation(); handleSkip(j.id); }}
                        className="h-10 w-10 sm:h-12 sm:w-12 rounded-full border border-red-200 bg-red-50 text-red-600 flex items-center justify-center hover:bg-red-100 hover:scale-105 active:scale-95 transition-all shadow-sm cursor-pointer z-40"
                        title="Reject Offer"
                      >
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>

                      <div className="flex flex-col items-center">
                        <span className="text-[10px] text-slate-400 font-bold tracking-widest uppercase">
                          {idx === 0 ? 'Accept Offer' : 'Queue Gigs'}
                        </span>
                        {idx === 0 && (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[9px] font-extrabold bg-slate-50 border border-slate-100 text-slate-500 mt-1 shadow-xs">
                            <span className="relative flex h-1.5 w-1.5">
                              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-brand/60 opacity-75" />
                              <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-brand" />
                            </span>
                            Auto-skip in {timeLeft}s
                          </span>
                        )}
                      </div>

                      {/* Accept Button (Green Tick on Right) */}
                      <button 
                        onClick={(e) => { e.stopPropagation(); handleAccept(j.id); }}
                        className="h-10 w-10 sm:h-12 sm:w-12 rounded-full bg-emerald-500 text-white flex items-center justify-center hover:bg-emerald-600 hover:scale-105 active:scale-95 transition-all shadow-md shadow-emerald-500/20 cursor-pointer z-40"
                        title="Accept Offer"
                      >
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M5 13l4 4L19 7" />
                        </svg>
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
            {/* End spacer so the last card can stack and release cleanly */}
            <div className="shrink-0 w-24 h-1 pointer-events-none" />
          </div>
        )}
      </div>
    </div>
  );
}
