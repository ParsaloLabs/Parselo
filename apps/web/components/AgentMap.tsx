'use client';
import { useEffect, useRef, useState } from 'react';

declare global {
  interface Window { google: any; __ppGmapsLoading?: Promise<void> }
}

const KEY = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY ?? '';

function loadMaps(): Promise<void> {
  if (typeof window === 'undefined') return Promise.resolve();
  if (window.google?.maps) return Promise.resolve();
  if (window.__ppGmapsLoading) return window.__ppGmapsLoading;
  window.__ppGmapsLoading = new Promise<void>((resolve, reject) => {
    const s = document.createElement('script');
    s.src = `https://maps.googleapis.com/maps/api/js?key=${KEY}&v=weekly`;
    s.async = true;
    s.defer = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error('Google Maps failed to load'));
    document.head.appendChild(s);
  });
  return window.__ppGmapsLoading;
}

type Props = {
  agent: { name: string; lat: number; lng: number } | null;
  // Future: pickup/delivery coordinates — we don't store them today, so we centre on the agent.
};

export default function AgentMap({ agent }: Props) {
  const ref = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<any>(null);
  const markerRef = useRef<any>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!KEY) { setError('NEXT_PUBLIC_GOOGLE_MAPS_API_KEY is not set'); return; }
    if (!agent) return;
    let cancelled = false;
    loadMaps().then(() => {
      if (cancelled || !ref.current) return;
      if (!mapRef.current) {
        mapRef.current = new window.google.maps.Map(ref.current, {
          center: { lat: agent.lat, lng: agent.lng },
          zoom: 15,
          disableDefaultUI: true,
          zoomControl: true,
          gestureHandling: 'greedy',
          styles: [{ featureType: 'poi', stylers: [{ visibility: 'off' }] }],
        });
      }
      if (!markerRef.current) {
        markerRef.current = new window.google.maps.Marker({
          map: mapRef.current,
          position: { lat: agent.lat, lng: agent.lng },
          title: agent.name,
          icon: {
            path: window.google.maps.SymbolPath.CIRCLE,
            scale: 10,
            fillColor: '#0E5BFF',
            fillOpacity: 1,
            strokeColor: '#fff',
            strokeWeight: 3,
          },
        });
      } else {
        markerRef.current.setPosition({ lat: agent.lat, lng: agent.lng });
        mapRef.current.panTo({ lat: agent.lat, lng: agent.lng });
      }
    }).catch((e) => setError(e.message));
    return () => { cancelled = true; };
  }, [agent?.lat, agent?.lng, agent?.name]);

  if (!agent) return null;
  if (error) {
    return (
      <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 text-sm text-amber-900 mb-4">
        {error}
      </div>
    );
  }
  return (
    <div className="bg-white border border-slate-200 rounded-xl overflow-hidden mb-4">
      <div className="px-4 py-3 border-b border-slate-200 flex items-center justify-between">
        <div className="text-sm">
          <div className="font-semibold">🛵 {agent.name}</div>
          <div className="text-xs text-slate-500">Live location</div>
        </div>
        <div className="text-xs text-slate-400">updated every 10s</div>
      </div>
      <div ref={ref} className="w-full h-72" />
    </div>
  );
}
