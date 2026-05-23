// Parsalo service worker — minimal offline shell.
// API calls go straight to the network so they never get stale.
const CACHE = 'pp-web-v1';
const SHELL = ['/', '/home', '/manifest.webmanifest'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).catch(() => {}));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))),
    ),
  );
  self.clients.claim();
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET') return;
  if (url.pathname.startsWith('/api/')) return;
  // Network-first for navigations, fall back to cached shell when offline.
  if (e.request.mode === 'navigate') {
    e.respondWith(
      fetch(e.request).catch(() => caches.match('/home').then((r) => r ?? caches.match('/'))),
    );
    return;
  }
  // Cache-first for everything else.
  e.respondWith(
    caches.match(e.request).then((cached) =>
      cached ?? fetch(e.request).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy)).catch(() => {});
        return res;
      }),
    ),
  );
});
