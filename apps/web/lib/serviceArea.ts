import { api } from './api';

// Service-area gate, client-side.
//
// Primary check is district-wise: a pin is in-zone iff its reverse-geocoded
// district matches a district where we have ≥1 active courier office.
// Optional 15 km radius is layered on top when the admin flips
// `service_area_radius_enabled`.
//
// The config endpoint ships the flag value, the serviceable district set,
// and the office list in one round-trip — cached after the first load so the
// out-of-zone modal appears instantly on every pin drop.

// Default radius — used until the /config response lands, and as a fallback
// when the endpoint is unreachable. Admin can override via the flag.
export const DEFAULT_RADIUS_M = 15_000;
export const SERVICE_RADIUS_M = DEFAULT_RADIUS_M;

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
const FALLBACK_OFFICES: CourierOffice[] = [
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

let officeCache: CourierOffice[] = FALLBACK_OFFICES;
let districtCache: string[] = ['thrissur'];
let radiusEnabledCache = false;
let radiusMCache: number = DEFAULT_RADIUS_M;
let loaded = false;
let inflight: Promise<void> | null = null;

function normalizeDistrict(d: string | null | undefined): string {
  if (!d) return '';
  return d
    .toLowerCase()
    .replace(/\s+district$/i, '')
    .replace(/[^a-z0-9]+/g, '')
    .trim();
}

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
      const res = await api<{
        offices: CourierOffice[];
        radius_m: number;
        radius_gate_enabled?: boolean;
        serviceable_districts?: string[];
      }>('/config/courier-offices', { auth: false });
      if (res?.offices?.length) {
        officeCache = res.offices.map((o) => ({
          ...o,
          latitude: Number(o.latitude),
          longitude: Number(o.longitude),
        }));
      }
      if (res?.serviceable_districts?.length) {
        districtCache = res.serviceable_districts;
      } else {
        districtCache = Array.from(
          new Set(officeCache.map((o) => normalizeDistrict(o.district)).filter(Boolean)),
        );
      }
      radiusEnabledCache = res?.radius_gate_enabled === true;
      const rm = Number(res?.radius_m);
      if (Number.isFinite(rm) && rm > 0) radiusMCache = rm;
      loaded = true;
    } catch {
      // Stay on fallback so Thrissur still works offline / on first load.
    } finally {
      inflight = null;
    }
  })();
  return inflight;
}

export function isInServiceArea(
  lat: number,
  lng: number,
  district: string | null | undefined,
  radiusM: number = radiusMCache,
): boolean {
  const pinDistrict = normalizeDistrict(district);
  if (!pinDistrict) {
    // Geocoder gave us nothing — fall back to radius regardless of flag so we
    // still gate but don't false-reject.
    for (const o of officeCache) {
      if (distanceMeters(lat, lng, o.latitude, o.longitude) <= radiusM) return true;
    }
    return false;
  }
  if (!districtCache.includes(pinDistrict)) return false;
  if (!radiusEnabledCache) return true;
  for (const o of officeCache) {
    if (distanceMeters(lat, lng, o.latitude, o.longitude) <= radiusM) return true;
  }
  return false;
}

export function nearbyOffices(lat: number, lng: number, radiusM: number = radiusMCache): RankedOffice[] {
  const ranked: RankedOffice[] = [];
  for (const o of officeCache) {
    const d = distanceMeters(lat, lng, o.latitude, o.longitude);
    if (d <= radiusM) ranked.push({ ...o, distance_m: Math.round(d) });
  }
  ranked.sort((a, b) => a.distance_m - b.distance_m);
  return ranked;
}

export function nearestServiceArea(lat: number, lng: number): { name: string } | null {
  if (officeCache.length === 0) return null;
  let best = officeCache[0];
  let bestD = distanceMeters(lat, lng, best.latitude, best.longitude);
  for (let i = 1; i < officeCache.length; i++) {
    const d = distanceMeters(lat, lng, officeCache[i].latitude, officeCache[i].longitude);
    if (d < bestD) {
      bestD = d;
      best = officeCache[i];
    }
  }
  return { name: best.district ?? best.courier_name };
}

export function isRadiusGateEnabled(): boolean {
  return radiusEnabledCache;
}

export function currentServiceRadiusM(): number {
  return radiusMCache;
}
