'use client';
import { useEffect, useRef, useState } from 'react';

declare global {
  interface Window { google: any; __ppGmapsLoading?: Promise<void> }
}

const KEY = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY ?? '';

// Thrissur — launch city default
const DEFAULT_CENTER = { lat: 10.5276, lng: 76.2144 };

function loadMaps(): Promise<void> {
  if (typeof window === 'undefined') return Promise.resolve();
  if (window.google?.maps) return Promise.resolve();
  if (window.__ppGmapsLoading) return window.__ppGmapsLoading;
  window.__ppGmapsLoading = new Promise<void>((resolve, reject) => {
    const s = document.createElement('script');
    s.src = `https://maps.googleapis.com/maps/api/js?key=${KEY}&libraries=places&v=weekly`;
    s.async = true;
    s.defer = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error('Google Maps failed to load'));
    document.head.appendChild(s);
  });
  return window.__ppGmapsLoading;
}

export type PickedLocation = {
  lat: number;
  lng: number;
  full_address: string;
  pincode: string;
};

type Props = {
  value: PickedLocation | null;
  onChange: (loc: PickedLocation) => void;
  label?: string;
  accentClass?: string;        // for marker colour; defaults to blue
  initialCenter?: { lat: number; lng: number };
};

function extractPincode(result: any): string {
  const comps = result?.address_components ?? [];
  const pin = comps.find((c: any) => c.types?.includes('postal_code'));
  return pin?.long_name ?? '';
}

export default function MapPicker({
  value, onChange, label, accentClass, initialCenter,
}: Props) {
  const mapDivRef = useRef<HTMLDivElement | null>(null);
  const inputRef = useRef<HTMLInputElement | null>(null);
  const mapRef = useRef<any>(null);
  const markerRef = useRef<any>(null);
  const geocoderRef = useRef<any>(null);
  const autocompleteRef = useRef<any>(null);

  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [locating, setLocating] = useState(false);
  const [searchText, setSearchText] = useState(value?.full_address ?? '');

  const accent = accentClass ?? '#0E5BFF';

  const place = (lat: number, lng: number) => {
    if (!mapRef.current) return;
    const pos = { lat, lng };
    mapRef.current.panTo(pos);
    if (mapRef.current.getZoom() < 15) mapRef.current.setZoom(16);
    if (!markerRef.current) {
      markerRef.current = new window.google.maps.Marker({
        map: mapRef.current,
        position: pos,
        draggable: true,
        icon: {
          path: window.google.maps.SymbolPath.CIRCLE,
          scale: 11,
          fillColor: accent,
          fillOpacity: 1,
          strokeColor: '#fff',
          strokeWeight: 3,
        },
      });
      markerRef.current.addListener('dragend', () => {
        const p = markerRef.current.getPosition();
        reverseAndEmit(p.lat(), p.lng());
      });
    } else {
      markerRef.current.setPosition(pos);
    }
  };

  const reverseAndEmit = (lat: number, lng: number) => {
    if (!geocoderRef.current) {
      onChange({ lat, lng, full_address: value?.full_address ?? '', pincode: value?.pincode ?? '' });
      return;
    }
    geocoderRef.current.geocode({ location: { lat, lng } }, (results: any[], status: string) => {
      if (status === 'OK' && results?.[0]) {
        const addr = results[0].formatted_address ?? '';
        const pin = extractPincode(results[0]);
        setSearchText(addr);
        onChange({ lat, lng, full_address: addr, pincode: pin });
      } else {
        onChange({ lat, lng, full_address: value?.full_address ?? '', pincode: value?.pincode ?? '' });
      }
    });
  };

  useEffect(() => {
    if (!KEY) { setError('NEXT_PUBLIC_GOOGLE_MAPS_API_KEY is not set'); return; }
    let cancelled = false;
    loadMaps().then(() => {
      if (cancelled || !mapDivRef.current) return;
      const center = value ? { lat: value.lat, lng: value.lng } : (initialCenter ?? DEFAULT_CENTER);
      mapRef.current = new window.google.maps.Map(mapDivRef.current, {
        center,
        zoom: value ? 16 : 13,
        disableDefaultUI: true,
        zoomControl: true,
        gestureHandling: 'greedy',
        styles: [{ featureType: 'poi', stylers: [{ visibility: 'off' }] }],
      });
      geocoderRef.current = new window.google.maps.Geocoder();

      mapRef.current.addListener('click', (e: any) => {
        const lat = e.latLng.lat();
        const lng = e.latLng.lng();
        place(lat, lng);
        reverseAndEmit(lat, lng);
      });

      if (inputRef.current && window.google.maps.places) {
        autocompleteRef.current = new window.google.maps.places.Autocomplete(inputRef.current, {
          fields: ['geometry', 'formatted_address', 'address_components'],
          componentRestrictions: { country: 'in' },
        });
        autocompleteRef.current.addListener('place_changed', () => {
          const p = autocompleteRef.current.getPlace();
          if (!p?.geometry?.location) return;
          const lat = p.geometry.location.lat();
          const lng = p.geometry.location.lng();
          const addr = p.formatted_address ?? '';
          const pin = extractPincode(p);
          place(lat, lng);
          setSearchText(addr);
          onChange({ lat, lng, full_address: addr, pincode: pin });
        });
      }

      if (value) place(value.lat, value.lng);
      setReady(true);
    }).catch((e) => setError(e.message));
    return () => { cancelled = true; };
  }, []);  // eslint-disable-line react-hooks/exhaustive-deps

  const useMyLocation = () => {
    if (!navigator.geolocation) { setError('Geolocation not available in this browser'); return; }
    setError(null);
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setLocating(false);
        place(pos.coords.latitude, pos.coords.longitude);
        reverseAndEmit(pos.coords.latitude, pos.coords.longitude);
      },
      (err) => { setLocating(false); setError(err.message || 'Could not get current location'); },
      { enableHighAccuracy: true, timeout: 10_000 },
    );
  };

  return (
    <div className="space-y-2">
      {label && <div className="text-xs font-semibold text-slate-500">{label}</div>}
      <div className="relative">
        <input
          ref={inputRef}
          value={searchText}
          onChange={(e) => setSearchText(e.target.value)}
          placeholder={ready ? 'Search address or landmark' : 'Loading map…'}
          disabled={!ready}
          className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm pr-10"
        />
        <button
          type="button"
          onClick={useMyLocation}
          disabled={!ready || locating}
          title="Use my current location"
          className="absolute right-1 top-1 px-2 py-1 text-xs rounded-md bg-slate-100 hover:bg-slate-200 disabled:opacity-50"
        >
          {locating ? '…' : '📍 Me'}
        </button>
      </div>
      <div
        ref={mapDivRef}
        className="w-full h-64 rounded-lg border border-slate-200 bg-slate-50"
      />
      <div className="text-xs text-slate-500">
        Tap the map or drag the pin to set the exact spot. The driver will navigate to this point.
      </div>
      {value && (
        <div className="text-xs text-slate-600 bg-slate-50 rounded-md px-3 py-2">
          <div className="font-medium truncate">{value.full_address || 'Pinned location'}</div>
          <div className="text-slate-500">
            {value.pincode ? `PIN ${value.pincode} · ` : ''}
            {value.lat.toFixed(5)}, {value.lng.toFixed(5)}
          </div>
        </div>
      )}
      {error && <div className="text-xs text-red-600">{error}</div>}
    </div>
  );
}
