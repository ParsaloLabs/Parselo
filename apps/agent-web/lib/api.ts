const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4000/api/v1';
const TOKEN_KEY = 'pp.agent.token';

export function setToken(t: string | null) {
  if (typeof window === 'undefined') return;
  if (t) localStorage.setItem(TOKEN_KEY, t);
  else localStorage.removeItem(TOKEN_KEY);
}

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(TOKEN_KEY);
}

export async function api<T = any>(
  path: string,
  opts: { method?: string; body?: any; auth?: boolean } = {},
): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (opts.auth !== false) {
    const t = getToken();
    if (t) headers.authorization = `Bearer ${t}`;
  }
  const res = await fetch(`${API_URL}${path}`, {
    method: opts.method ?? 'GET',
    headers,
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  if (!res.ok) throw new Error(await extractErrorCode(res));
  if (res.status === 204) return undefined as any;
  return res.json();
}

async function extractErrorCode(res: Response): Promise<string> {
  const text = await res.text();
  try {
    const parsed = JSON.parse(text);
    return parsed.error ?? parsed.message ?? `http_${res.status}`;
  } catch {
    return text || `http_${res.status}`;
  }
}

export async function downloadFile(path: string, filename: string) {
  const t = getToken();
  const res = await fetch(`${API_URL}${path}`, {
    headers: t ? { authorization: `Bearer ${t}` } : {},
  });
  if (!res.ok) throw new Error(await extractErrorCode(res));
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

export const STATUS_LABEL: Record<string, string> = {
  pending: 'Pending',
  agent_assigned: 'Assigned',
  agent_en_route_pickup: 'En route',
  parcel_collected: 'Collected',
  at_courier_office: 'At courier',
  shipped: 'Shipped',
  out_for_delivery: 'Out for delivery',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
  failed: 'Failed',
};
