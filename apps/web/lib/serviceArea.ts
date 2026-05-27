import { api } from './api';

// A location is serviceable iff at least one active courier office sits
// within SERVICE_RADIUS_M of it. Clients cache the full office list once and
// run a local Haversine on every pin drop, so the "out-of-zone" sheet
// appears instantly without a server round-trip.

export const SERVICE_RADIUS_M = 15_000;

export type CourierOffice = {
  id: string;
  courier_name: string;
  name: string | null;
  district: string | null;
  full_address: string;
  latitude: number;
  longitude: number;
};

export type RankedOffice = CourierOffice & { distance_m: number };

// Fallback so a cold offline boot still gates correctly — treats Thrissur
// town hall as a single pseudo-office. Fail-safe inward, never fail-open.
const FALLBACK: CourierOffice[] = [
  {
    id: 'fallback-thrissur',
    courier_name: 'Parsalo',
    name: 'Thrissur HQ',
    district: 'Thrissur',
    full_address: 'Thrissur, Kerala',
    latitude: 10.5276,
    longitude: 76.2144,
  },
];

let cache: CourierOffice[] = FALLBACK;
let loaded = false;
let inflight: Promise<void> | null = null;

function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export async function loadCourierOffices(): Promise<void> {
  if (loaded) return;
  if (inflight) return inflight;
  inflight = (async () => {
    try {
      const res = await api<{ offices: CourierOffice[]; radius_m: number }>(
        '/config/courier-offices',
        { auth: false },
      );
      if (res?.offices?.length) {
        cache = res.offices.map((o) => ({
          ...o,
          latitude: Number(o.latitude),
          longitude: Number(o.longitude),
        }));
      }
      loaded = true;
    } catch {
      // Stay on fallback so Thrissur still works offline / on first load.
    } finally {
      inflight = null;
    }
  })();
  return inflight;
}

export function isInServiceArea(lat: number, lng: number, radiusM: number = SERVICE_RADIUS_M): boolean {
  for (const o of cache) {
    if (distanceMeters(lat, lng, o.latitude, o.longitude) <= radiusM) return true;
  }
  return false;
}

export function nearbyOffices(lat: number, lng: number, radiusM: number = SERVICE_RADIUS_M): RankedOffice[] {
  const ranked: RankedOffice[] = [];
  for (const o of cache) {
    const d = distanceMeters(lat, lng, o.latitude, o.longitude);
    if (d <= radiusM) ranked.push({ ...o, distance_m: Math.round(d) });
  }
  ranked.sort((a, b) => a.distance_m - b.distance_m);
  return ranked;
}

export function nearestServiceArea(lat: number, lng: number): { name: string } | null {
  if (cache.length === 0) return null;
  let best = cache[0];
  let bestD = distanceMeters(lat, lng, best.latitude, best.longitude);
  for (let i = 1; i < cache.length; i++) {
    const d = distanceMeters(lat, lng, cache[i].latitude, cache[i].longitude);
    if (d < bestD) {
      bestD = d;
      best = cache[i];
    }
  }
  return { name: best.district ?? best.courier_name };
}
