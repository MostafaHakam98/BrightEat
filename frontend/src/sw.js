/* Custom service worker (injectManifest): precache + runtime caching as before,
 * plus Web Push handling and an offline navigation fallback. */
import { precacheAndRoute, cleanupOutdatedCaches, matchPrecache } from 'workbox-precaching'
import { registerRoute, setCatchHandler } from 'workbox-routing'
import { NetworkFirst, CacheFirst } from 'workbox-strategies'
import { ExpirationPlugin } from 'workbox-expiration'
import { CacheableResponsePlugin } from 'workbox-cacheable-response'
import { clientsClaim } from 'workbox-core'

self.skipWaiting()
clientsClaim()

precacheAndRoute(self.__WB_MANIFEST)
cleanupOutdatedCaches()

// Same runtime caching we had with generateSW
registerRoute(
  ({ url }) => /\.(?:png|jpg|jpeg|svg|gif|webp)$/.test(url.pathname),
  new CacheFirst({
    cacheName: 'images-cache',
    plugins: [new ExpirationPlugin({ maxEntries: 50, maxAgeSeconds: 60 * 60 * 24 * 30 })],
  })
)
registerRoute(
  ({ url }) => url.pathname.startsWith('/api/'),
  new NetworkFirst({
    cacheName: 'api-cache',
    networkTimeoutSeconds: 10,
    plugins: [new CacheableResponsePlugin({ statuses: [0, 200] })],
  })
)

// Offline fallback: navigations that fail get the precached offline page
setCatchHandler(async ({ request }) => {
  if (request.mode === 'navigate') {
    const offline = await matchPrecache('/offline.html')
    if (offline) return offline
  }
  return Response.error()
})

// ── Web Push ──────────────────────────────────────────────────────
self.addEventListener('push', (event) => {
  let data = { title: 'OrderQ', body: '', url: '/' }
  try {
    data = { ...data, ...event.data.json() }
  } catch {
    data.body = event.data ? event.data.text() : ''
  }
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: '/icon-192x192.png',
      badge: '/icon-192x192.png',
      data: { url: data.url },
    })
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = event.notification.data?.url || '/'
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if ('focus' in client) {
          client.focus()
          if ('navigate' in client) client.navigate(url)
          return
        }
      }
      return self.clients.openWindow(url)
    })
  )
})
