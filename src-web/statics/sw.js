const VERSION = 'v0.0.0';
const STATIC_CACHE = `static-${VERSION}`;
const RUNTIME_CACHE = `runtime-${VERSION}`;
const STATIC_ASSETS = [
    '/',
    '/index.html',
    '/favicon.ico',
    '/statics/style.css',
    '/statics/js/index.js',
    '/statics/js/loader.js',
    '/statics/js/minimal.js',
    '/statics/js/state.js',
    '/statics/ms-icon-310x310.png',
    '/statics/ms-icon-150x150.png',
    '/statics/ms-icon-70x70.png',
    '/statics/manifest.json'
];


self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(STATIC_CACHE).then((cache) => cache.addAll(STATIC_ASSETS))
    );
    self.skipWaiting();
});

self.addEventListener('activate', (event) => {
    event.waitUntil((async () => {
        const keys = await caches.keys();
        await Promise.all(
            keys.map((k) => {
                if (![STATIC_CACHE, RUNTIME_CACHE].includes(k)) return caches.delete(k);
            })
        );
    })());
    self.clients.claim();
});

self.addEventListener('fetch', (event) => {
    const req = event.request;

    if (req.method !== 'GET') return;

    const url = new URL(req.url);
    const isHTML = req.headers.get('accept')?.includes('text/html');

    if (isHTML) {
        event.respondWith(networkFirst(req));
    } else if (url.origin === self.location.origin) {
        event.respondWith(cacheFirst(req));
    }
});

async function cacheFirst(req) {
    const cached = await caches.match(req);
    if (cached) return cached;
    const res = await fetch(req);
    const cache = await caches.open(RUNTIME_CACHE);
    cache.put(req, res.clone());
    return res;
}

async function networkFirst(req) {
    const cache = await caches.open(RUNTIME_CACHE);
    try {
        const res = await fetch(req);
        cache.put(req, res.clone());
        return res;
    } catch {
        const cached = await caches.match(req);
        return cached || caches.match('/offline.html');
    }
}
