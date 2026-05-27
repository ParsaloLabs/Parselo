// Service-area gate.
//
// A customer pickup (for send) or delivery (for receive) is valid only if it
// falls within an active service-areas row. Check is Haversine — fast, no
// external API. Mirrors dispatch.ts's 10s in-process cache pattern, so the
// order-create hot path doesn't re-read the row on every request.

import { query } from './db';

export type ServiceArea = {
  name: string;
  center_lat: number;
  center_lng: number;
  radius_m: number;
};

const CACHE_MS = 10_000;
let cached: { value: ServiceArea[]; loadedAt: number } | null = null;

export function invalidateServiceAreaCache(): void {
  cached = null;
}

export async function listServiceAreas(): Promise<ServiceArea[]> {
  if (cached && Date.now() - cached.loadedAt < CACHE_MS) {
    return cached.value;
  }
  try {
    const { rows } = await query<{
      name: string;
      center_lat: string;
      center_lng: string;
      radius_m: number;
    }>(
      `SELECT name, center_lat, center_lng, radius_m
         FROM service_areas
        WHERE is_active = TRUE
        ORDER BY name`,
    );
    const value: ServiceArea[] = rows.map((r) => ({
      name: r.name,
      center_lat: Number(r.center_lat),
      center_lng: Number(r.center_lng),
      radius_m: r.radius_m,
    }));
    cached = { value, loadedAt: Date.now() };
    return value;
  } catch (e) {
    // Table missing (pre-migration) — fail closed so we don't accept orders
    // from anywhere by accident. Log once per cache window.
    console.warn('[service-area] load failed, treating all locations as out-of-zone', e);
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

export async function isInServiceArea(lat: number, lng: number): Promise<boolean> {
  const areas = await listServiceAreas();
  for (const a of areas) {
    if (distanceMeters(lat, lng, a.center_lat, a.center_lng) <= a.radius_m) {
      return true;
    }
  }
  return false;
}
