'use strict';

// Serene's offline cache.
//
// Flutter's generated service worker (flutter_service_worker.js) is a stub
// that unregisters itself in recent Flutter releases, so this file is the one
// that actually makes the PWA installable and usable offline.
//
// Bump CACHE_NAME whenever the caching strategy changes. Normal app updates do
// not need a bump: navigation and script requests are network-first, so a
// deployed build is picked up on the next online visit.
const CACHE_NAME = 'serene-shell-v1';
const NAVIGATION_TIMEOUT_MS = 4500;
const CDN_HOSTS = ['fonts.gstatic.com', 'www.gstatic.com'];

// Files that are cached during installation. Missing optional entries are
// ignored, so this list can stay ahead of build changes.
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './flutter_bootstrap.js',
  './flutter.js',
  './version.json',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
  './icons/apple-touch-icon-120.png',
  './icons/apple-touch-icon-152.png',
  './icons/apple-touch-icon-167.png',
  './icons/apple-touch-icon-180.png',
  './main.dart.js',
  './assets/AssetManifest.bin',
  './assets/AssetManifest.bin.json',
  './assets/FontManifest.json',
  './assets/fonts/MaterialIcons-Regular.otf',
  './assets/assets/audio/chime.wav',
  './assets/assets/audio/exhale.wav',
  './assets/assets/audio/inhale.wav',
  './assets/shaders/ink_sparkle.frag',
  './assets/shaders/stretch_effect.frag',
  // CanvasKit is bundled by `flutter build web --no-web-resources-cdn`.
  // Without that flag these are harmless extra cache attempts; the CDN copies
  // are cached at runtime instead.
  './canvaskit/canvaskit.js',
  './canvaskit/canvaskit.wasm',
  './canvaskit/chromium/canvaskit.js',
  './canvaskit/chromium/canvaskit.wasm',
  // CanvasKit's default text font, loaded from Google Fonts.
  'https://fonts.gstatic.com/s/roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2',
];

// These are re-fetched even if the HTTP cache has a copy, so a new deployment
// is reflected as soon as the worker installs.
const FRESH_ON_INSTALL = new Set([
  './',
  './index.html',
  './manifest.json',
  './flutter_bootstrap.js',
  './flutter.js',
  './version.json',
]);

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      await Promise.allSettled(
        APP_SHELL.map(async (url) => {
          try {
            const options = FRESH_ON_INSTALL.has(url) ? { cache: 'reload' } : {};
            const response = await fetch(new Request(url, options));
            if (response && (response.ok || response.type === 'opaque')) {
              await cache.put(new Request(url), response);
            }
          } catch (_) {
            // Optional or not yet built: keep installing the rest.
          }
        }),
      );
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((key) => key.startsWith('serene-') && key !== CACHE_NAME)
          .map((key) => caches.delete(key)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;

  // Only plain page/asset GETs. Range requests (audio seeking) and
  // non-http(s) schemes are left to the browser.
  if (request.method !== 'GET') return;
  if (request.headers.has('range')) return;

  let url;
  try {
    url = new URL(request.url);
  } catch (_) {
    return;
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return;

  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request, './index.html', NAVIGATION_TIMEOUT_MS));
    return;
  }

  if (url.origin === self.location.origin) {
    // Code must be fresh when online; everything else can be served from the
    // cache immediately and refreshed in the background.
    const destination = request.destination;
    if (
      destination === 'script' ||
      destination === 'style' ||
      destination === 'worker'
    ) {
      event.respondWith(networkFirst(request, null, 0));
    } else {
      event.respondWith(staleWhileRevalidate(event, request));
    }
    return;
  }

  // CanvasKit and the Roboto fallback live on Google's CDN.
  if (CDN_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(request));
  }
});

async function networkFirst(request, fallbackUrl, timeoutMs) {
  const cache = await caches.open(CACHE_NAME);
  try {
    const response = timeoutMs
      ? await fetchWithTimeout(request, timeoutMs)
      : await fetch(request);
    if (response && response.ok) {
      await cache.put(request, response.clone());
      return response;
    }
    // A gateway or captive portal can answer with a 5xx page even though the
    // network is reachable. Treat that like being offline and use the cache so
    // the installed app never shows a server error instead of its own shell.
    if (response && response.status >= 500) {
      const cached = await cache.match(request);
      if (cached) return cached;
      if (fallbackUrl) {
        const shell = await cache.match(fallbackUrl);
        if (shell) return shell;
      }
    }
    return response;
  } catch (_) {
    const cached = await cache.match(request);
    if (cached) return cached;
    if (fallbackUrl) {
      const shell = await cache.match(fallbackUrl);
      if (shell) return shell;
    }
    return Response.error();
  }
}

function staleWhileRevalidate(event, request) {
  // Start the network update synchronously so the worker stays alive long
  // enough to write it to the cache.
  const network = (async () => {
    const cache = await caches.open(CACHE_NAME);
    try {
      const response = await fetch(request);
      if (response && (response.ok || response.type === 'opaque')) {
        await cache.put(request, response.clone());
      }
      return response;
    } catch (_) {
      return undefined;
    }
  })();
  event.waitUntil(network.then(() => undefined).catch(() => undefined));

  return (async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    return cached || (await network) || Response.error();
  })();
}

async function cacheFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);
  if (cached) return cached;

  try {
    const response = await fetch(request);
    if (response && (response.ok || response.type === 'opaque')) {
      await cache.put(request, response.clone());
    }
    return response;
  } catch (_) {
    return Response.error();
  }
}

function fetchWithTimeout(request, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  return fetch(request, { signal: controller.signal }).finally(() =>
    clearTimeout(timer),
  );
}
