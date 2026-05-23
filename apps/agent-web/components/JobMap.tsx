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

type LatLng = { lat: number; lng: number };

type Props = {
  pickup: { lat: number | null; lng: number | null; label?: string | null } | null;
  drop:   { lat: number | null; lng: number | null; label?: string | null } | null;
  // Which leg the agent is currently on — controls the highlighted Navigate button.
  // 'pickup' before parcel_collected, 'drop' after.
  activeLeg: 'pickup' | 'drop';
};

function asLL(p: Props['pickup'] | Props['drop']): LatLng | null {
  if (!p || p.lat == null || p.lng == null) return null;
  return { lat: Number(p.lat), lng: Number(p.lng) };
}

function dot(map: any, pos: LatLng, color: string, title: string, label?: string) {
  return new window.google.maps.Marker({
    map, position: pos, title,
    label: label ? { text: label, color: '#fff', fontWeight: '700', fontSize: '12px' } : undefined,
    icon: {
      path: window.google.maps.SymbolPath.CIRCLE,
      scale: 12, fillColor: color, fillOpacity: 1,
      strokeColor: '#fff', strokeWeight: 3,
    },
  });
}

export default function JobMap({ pickup, drop, activeLeg }: Props) {
  const ref = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<any>(null);
  const markersRef = useRef<{ pickup?: any; drop?: any; agent?: any }>({});
  const [agentLoc, setAgentLoc] = useState<LatLng | null>(null);
  const [error, setError] = useState<string | null>(null);

  const pickupLL = asLL(pickup);
  const dropLL = asLL(drop);

  useEffect(() => {
    if (!navigator.geolocation) return;
    const id = navigator.geolocation.watchPosition(
      (pos) => setAgentLoc({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => {}, { enableHighAccuracy: true, maximumAge: 15_000 },
    );
    return () => navigator.geolocation.clearWatch(id);
  }, []);

  useEffect(() => {
    if (!KEY) { setError('NEXT_PUBLIC_GOOGLE_MAPS_API_KEY is not set'); return; }
    if (!pickupLL && !dropLL && !agentLoc) return;
    let cancelled = false;
    loadMaps().then(() => {
      if (cancelled || !ref.current) return;
      const center = (activeLeg === 'pickup' ? pickupLL : dropLL) ?? agentLoc ?? pickupLL ?? dropLL!;
      if (!mapRef.current) {
        mapRef.current = new window.google.maps.Map(ref.current, {
          center, zoom: 14,
          disableDefaultUI: true, zoomControl: true,
          gestureHandling: 'greedy',
          styles: [{ featureType: 'poi', stylers: [{ visibility: 'off' }] }],
        });
      }

      const m = markersRef.current;
      if (pickupLL) {
        if (m.pickup) m.pickup.setPosition(pickupLL);
        else m.pickup = dot(mapRef.current, pickupLL, '#10B981', pickup?.label ?? 'Pickup', 'P');
      }
      if (dropLL) {
        if (m.drop) m.drop.setPosition(dropLL);
        else m.drop = dot(mapRef.current, dropLL, '#EF4444', drop?.label ?? 'Drop', 'D');
      }
      if (agentLoc) {
        if (m.agent) m.agent.setPosition(agentLoc);
        else m.agent = dot(mapRef.current, agentLoc, '#0E5BFF', 'You');
      }

      const bounds = new window.google.maps.LatLngBounds();
      let count = 0;
      for (const p of [pickupLL, dropLL, agentLoc]) {
        if (p) { bounds.extend(p); count++; }
      }
      if (count >= 2) mapRef.current.fitBounds(bounds, 80);
      else if (count === 1) mapRef.current.setCenter(center);
    }).catch((e) => setError(e.message));
    return () => { cancelled = true; };
  }, [pickupLL?.lat, pickupLL?.lng, dropLL?.lat, dropLL?.lng, agentLoc?.lat, agentLoc?.lng, activeLeg]);

  const navUrl = (to: LatLng) =>
    `https://www.google.com/maps/dir/?api=1&destination=${to.lat},${to.lng}&travelmode=driving`;

  if (!pickupLL && !dropLL) {
    return (
      <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 text-sm text-amber-900 mb-4">
        Customer didn't pin a precise location for this order. Use the address below.
      </div>
    );
  }
  if (error) {
    return (
      <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 text-sm text-amber-900 mb-4">
        {error}
      </div>
    );
  }

  return (
    <div className="bg-white border border-slate-200 rounded-xl overflow-hidden mb-4">
      <div ref={ref} className="w-full h-64" />
      <div className="px-3 py-2 grid grid-cols-2 gap-2 border-t border-slate-200">
        <a
          href={pickupLL ? navUrl(pickupLL) : '#'}
          target="_blank" rel="noreferrer"
          aria-disabled={!pickupLL}
          className={`text-center text-sm font-semibold py-2 rounded-lg ${
            activeLeg === 'pickup'
              ? 'bg-brand text-white hover:bg-brand-dark'
              : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
          } ${!pickupLL ? 'opacity-40 pointer-events-none' : ''}`}
        >
          🧭 Navigate to pickup
        </a>
        <a
          href={dropLL ? navUrl(dropLL) : '#'}
          target="_blank" rel="noreferrer"
          aria-disabled={!dropLL}
          className={`text-center text-sm font-semibold py-2 rounded-lg ${
            activeLeg === 'drop'
              ? 'bg-brand text-white hover:bg-brand-dark'
              : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
          } ${!dropLL ? 'opacity-40 pointer-events-none' : ''}`}
        >
          🧭 Navigate to drop
        </a>
      </div>
    </div>
  );
}
