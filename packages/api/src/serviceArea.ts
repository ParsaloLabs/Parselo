// Service-area gate.
//
// Primary check is district-wise: a pin is in-zone iff its (reverse-geocoded)
// district matches a district where we have ≥1 active courier office. That
// way "where we operate" stays in lockstep with courier_branches.
//
// Optional stricter check is the 15 km radius — toggleable via the
// `service_area_radius_enabled` feature flag. Useful when launching a single
// neighborhood and we don't want to claim the whole district yet.
//
// Order of checks: district first (cheap, fail-fast), then radius if enabled.
// Same 10s in-process cache as before for both office and flag reads.

import { query } from './db';
import { getBoolFlag, getNumberFlag, FLAG_RADIUS_ENABLED, FLAG_RADIUS_M } from './flags';

// Default radius — used as the fallback when the feature_flags row is
// missing/invalid, and as a sane initial value for new installs.
export const DEFAULT_RADIUS_M = 15_000;

// Back-compat alias for older imports.
export const SERVICE_RADIUS_M = DEFAULT_RADIUS_M;

export async function getServiceRadiusM(): Promise<number> {
  return getNumberFlag(FLAG_RADIUS_M, DEFAULT_RADIUS_M);
}

export type CourierOffice = {
  id: string;
  courier_name: string;
  name: string | null;
  district: string | null;
  full_address: string;
  latitude: number;
  longitude: number;
};

const CACHE_MS = 10_000;
let cached: { value: CourierOffice[]; loadedAt: number } | null = null;

export function invalidateServiceAreaCache(): void {
  cached = null;
}

export async function listCourierOffices(): Promise<CourierOffice[]> {
  if (cached && Date.now() - cached.loadedAt < CACHE_MS) {
    return cached.value;
  }
  try {
    const { rows } = await query<{
      id: string;
      courier_name: string;
      name: string | null;
      district: string | null;
      full_address: string;
      latitude: string;
      longitude: string;
    }>(
      `SELECT b.id, c.name AS courier_name, b.name, b.district, b.full_address,
              b.latitude, b.longitude
         FROM courier_branches b
         JOIN couriers c ON c.id = b.courier_id
        WHERE c.is_active = TRUE
          AND b.latitude IS NOT NULL
          AND b.longitude IS NOT NULL`,
    );
    const value: CourierOffice[] = rows.map((r) => ({
      id: r.id,
      courier_name: r.courier_name,
      name: r.name,
      district: r.district,
      full_address: r.full_address,
      latitude: Number(r.latitude),
      longitude: Number(r.longitude),
    }));
    cached = { value, loadedAt: Date.now() };
    return value;
  } catch (e) {
    console.warn('[service-area] office load failed, treating all locations as out-of-zone', e);
    return [];
  }
}

// Normalize for district comparison: trim, lowercase, drop punctuation/whitespace
// runs. Reverse-geocoded labels often vary on case and surrounding text
// ("Thrissur District" vs "Thrissur") — keep the comparison forgiving so an
// admin who types "Thrissur" in the office row still matches.
export function normalizeDistrict(d: string | null | undefined): string {
  if (!d) return '';
  return d
    .toLowerCase()
    .replace(/\s+district$/i, '')
    .replace(/[^a-z0-9]+/g, '')
    .trim();
}

export async function listServiceableDistricts(): Promise<string[]> {
  const offices = await listCourierOffices();
  const set = new Set<string>();
  for (const o of offices) {
    const n = normalizeDistrict(o.district);
    if (n) set.add(n);
  }
  return Array.from(set);
}

// Haversine distance in metres.
export function distanceMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export type RankedOffice = CourierOffice & { distance_m: number };

export async function findNearbyOffices(
  lat: number,
  lng: number,
  radiusM?: number,
): Promise<RankedOffice[]> {
  const effectiveRadius = radiusM ?? (await getServiceRadiusM());
  const offices = await listCourierOffices();
  const ranked: RankedOffice[] = [];
  for (const o of offices) {
    const d = distanceMeters(lat, lng, o.latitude, o.longitude);
    if (d <= effectiveRadius) ranked.push({ ...o, distance_m: Math.round(d) });
  }
  ranked.sort((a, b) => a.distance_m - b.distance_m);
  return ranked;
}

export async function hasNearbyOffice(
  lat: number,
  lng: number,
  radiusM?: number,
): Promise<boolean> {
  const effectiveRadius = radiusM ?? (await getServiceRadiusM());
  const offices = await listCourierOffices();
  for (const o of offices) {
    if (distanceMeters(lat, lng, o.latitude, o.longitude) <= effectiveRadius) return true;
  }
  return false;
}

// The single gate the order-create path should call. Combines the district
// check (always on) with the radius check (flag-gated). Reverse-geocoded
// district from the client may be null on geocoder failure — when that
// happens we fall back to "any office within radius" as a soft pass so we
// don't lock customers out due to a geocoder hiccup.
export async function isPinServiceable(
  lat: number,
  lng: number,
  district: string | null | undefined,
): Promise<boolean> {
  const radiusOn = await getBoolFlag(FLAG_RADIUS_ENABLED, false);
  const districts = await listServiceableDistricts();
  const pinDistrict = normalizeDistrict(district);

  let districtOk: boolean;
  if (pinDistrict) {
    districtOk = districts.includes(pinDistrict);
  } else {
    // Geocoder didn't give us a district — fall back to radius regardless of
    // the flag, so we still gate but don't false-reject.
    districtOk = await hasNearbyOffice(lat, lng);
    return districtOk;
  }
  if (!districtOk) return false;
  if (!radiusOn) return true;
  return await hasNearbyOffice(lat, lng);
}
