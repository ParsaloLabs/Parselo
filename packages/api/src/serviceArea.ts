// Service-area gate, redefined.
//
// "Where do we operate?" is now derived from the courier_branches table.
// A pickup/delivery address is serviceable iff there is at least one active
// courier office within SERVICE_RADIUS_M of it. That way adding a new office
// in another city automatically opens the zone — admin manages one list, not
// two.
//
// Same 10s in-process cache pattern as before so the order-create hot path
// doesn't re-read the table on every request.

import { query } from './db';

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
  radiusM: number = SERVICE_RADIUS_M,
): Promise<RankedOffice[]> {
  const offices = await listCourierOffices();
  const ranked: RankedOffice[] = [];
  for (const o of offices) {
    const d = distanceMeters(lat, lng, o.latitude, o.longitude);
    if (d <= radiusM) ranked.push({ ...o, distance_m: Math.round(d) });
  }
  ranked.sort((a, b) => a.distance_m - b.distance_m);
  return ranked;
}

export async function hasNearbyOffice(
  lat: number,
  lng: number,
  radiusM: number = SERVICE_RADIUS_M,
): Promise<boolean> {
  const offices = await listCourierOffices();
  for (const o of offices) {
    if (distanceMeters(lat, lng, o.latitude, o.longitude) <= radiusM) return true;
  }
  return false;
}
