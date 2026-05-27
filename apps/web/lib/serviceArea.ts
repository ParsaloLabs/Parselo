import { api } from './api';

export type ServiceArea = {
  name: string;
  center_lat: number;
  center_lng: number;
  radius_m: number;
};

// Fallback matches db/migrations/0010_service_areas.sql seed. Used until the
// first /config/service-areas fetch completes so a cold page load still gates
// correctly — fail-safe inward, never fail-open outward.
const FALLBACK: ServiceArea[] = [
  { name: 'Thrissur', center_lat: 10.5276, center_lng: 76.2144, radius_m: 15000 },
];

let cache: ServiceArea[] = FALLBACK;
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

export async function loadServiceAreas(): Promise<void> {
  if (loaded) return;
  if (inflight) return inflight;
  inflight = (async () => {
    try {
      const res = await api<{ areas: ServiceArea[] }>('/config/service-areas', { auth: false });
      if (res?.areas?.length) {
        cache = res.areas.map((a) => ({
          name: a.name,
          center_lat: Number(a.center_lat),
          center_lng: Number(a.center_lng),
          radius_m: Number(a.radius_m),
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

export function isInServiceArea(lat: number, lng: number): boolean {
  for (const a of cache) {
    if (distanceMeters(lat, lng, a.center_lat, a.center_lng) <= a.radius_m) {
      return true;
    }
  }
  return false;
}

export function nearestServiceArea(lat: number, lng: number): ServiceArea | null {
  if (cache.length === 0) return null;
  let best = cache[0];
  let bestD = distanceMeters(lat, lng, best.center_lat, best.center_lng);
  for (let i = 1; i < cache.length; i++) {
    const d = distanceMeters(lat, lng, cache[i].center_lat, cache[i].center_lng);
    if (d < bestD) {
      bestD = d;
      best = cache[i];
    }
  }
  return best;
}
