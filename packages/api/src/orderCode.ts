import { query } from './db';

// Generate PP-{YEAR}-{5-digit-sequence}
export async function generateOrderCode(): Promise<string> {
  const year = new Date().getFullYear();
  const { rows } = await query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM orders WHERE EXTRACT(YEAR FROM created_at) = $1`,
    [year],
  );
  const seq = (Number(rows[0]?.count ?? 0) + 1).toString().padStart(5, '0');
  return `PP-${year}-${seq}`;
}
