// Tiny key/value feature-flag helper backed by the feature_flags table.
// Reads are cached for 10 s — same pattern as serviceArea.ts — so the
// order-create hot path doesn't hit the DB on every request.

import { query } from './db';

const CACHE_MS = 10_000;
let cached: { value: Record<string, unknown>; loadedAt: number } | null = null;

export function invalidateFlagsCache(): void {
  cached = null;
}

async function loadFlags(): Promise<Record<string, unknown>> {
  if (cached && Date.now() - cached.loadedAt < CACHE_MS) {
    return cached.value;
  }
  try {
    const { rows } = await query<{ key: string; value: unknown }>(
      `SELECT key, value FROM feature_flags`,
    );
    const value: Record<string, unknown> = {};
    for (const r of rows) value[r.key] = r.value;
    cached = { value, loadedAt: Date.now() };
    return value;
  } catch (e) {
    console.warn('[flags] load failed, defaulting all flags to off', e);
    return {};
  }
}

export async function getFlag<T = unknown>(key: string, fallback: T): Promise<T> {
  const all = await loadFlags();
  return (key in all ? (all[key] as T) : fallback);
}

export async function getBoolFlag(key: string, fallback = false): Promise<boolean> {
  const v = await getFlag<unknown>(key, fallback);
  return v === true || v === 'true';
}

export async function getAllFlags(): Promise<Record<string, unknown>> {
  return { ...(await loadFlags()) };
}

export async function setFlag(key: string, value: unknown): Promise<void> {
  await query(
    `INSERT INTO feature_flags (key, value, updated_at)
     VALUES ($1, $2::jsonb, NOW())
     ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()`,
    [key, JSON.stringify(value)],
  );
  invalidateFlagsCache();
}

export const FLAG_RADIUS_ENABLED = 'service_area_radius_enabled';
export const FLAG_RADIUS_M = 'service_area_radius_m';

export async function getNumberFlag(key: string, fallback: number): Promise<number> {
  const v = await getFlag<unknown>(key, fallback);
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}
