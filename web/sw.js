// Service worker de KikiDraw: deja la app usable sin conexión.
//
// - Archivos de la app (mismo origen): network-first. Con red siempre se
//   usa la versión nueva; sin red, la última guardada.
// - Fuentes de fallback de Google (gstatic): cache-first, no cambian.
//
// Los dibujos no pasan por acá: viven en IndexedDB.

const CACHE = "kikidraw-v1";

// Lo mínimo para arrancar. El resto (CanvasKit, fuentes, shaders) lo
// manda la página con un mensaje "cache-urls" apenas carga.
const SHELL = [
  "./",
  "index.html",
  "flutter_bootstrap.js",
  "main.dart.js",
  "manifest.json",
  "favicon.png",
  "icons/Icon-192.png",
  "icons/Icon-512.png",
];

const FONT_HOSTS = ["fonts.gstatic.com", "www.gstatic.com"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll(SHELL))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))),
      )
      .then(() => self.clients.claim()),
  );
});

function isCacheable(url) {
  return url.origin === self.location.origin || FONT_HOSTS.includes(url.hostname);
}

self.addEventListener("message", (event) => {
  if (event.data?.type !== "cache-urls") return;
  const urls = (event.data.urls || [])
    .map((u) => new URL(u, self.location.href))
    .filter(isCacheable);
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      Promise.all(
        urls.map(async (url) => {
          if (await cache.match(url)) return;
          try {
            const response = await fetch(url);
            if (response.ok) await cache.put(url, response);
          } catch (_) {
            // Sin red o recurso caído: se intenta de nuevo en otra visita.
          }
        }),
      ),
    ),
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (!isCacheable(url)) return;

  if (url.origin !== self.location.origin) {
    event.respondWith(cacheFirst(request));
    return;
  }
  event.respondWith(networkFirst(request));
});

async function cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok) {
    const cache = await caches.open(CACHE);
    cache.put(request, response.clone());
  }
  return response;
}

async function networkFirst(request) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(CACHE);
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const cached = await caches.match(request, { ignoreSearch: true });
    if (cached) return cached;
    // Sin red y sin la ruta exacta: si es una navegación, la app.
    if (request.mode === "navigate") {
      const shell = await caches.match("index.html");
      if (shell) return shell;
    }
    throw error;
  }
}
