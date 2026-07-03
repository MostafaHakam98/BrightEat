import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { VitePWA } from 'vite-plugin-pwa'

// Backend to proxy /api and /ws to. Dev default is the compose backend;
// E2E/CI point this at a local uvicorn. preview.proxy inherits server.proxy.
const proxyTarget = process.env.VITE_PROXY_TARGET || 'http://localhost:19992'

// https://vite.dev/config/
export default defineConfig({
  server: {
    proxy: {
      '/api': { target: proxyTarget, changeOrigin: true },
      '/media': { target: proxyTarget, changeOrigin: true },
      '/ws': { target: proxyTarget, ws: true, changeOrigin: true },
    },
  },
  plugins: [
    vue(),
    VitePWA({
      // Custom SW (src/sw.js) so we can handle Web Push + offline fallback;
      // it reimplements the same precache/runtime caching generateSW gave us.
      strategies: 'injectManifest',
      srcDir: 'src',
      filename: 'sw.js',
      registerType: 'autoUpdate',
      includeAssets: ['favicon.svg', 'logo.svg'],
      manifest: {
        name: 'OrderQ',
        short_name: 'OrderQ',
        description: 'OrderQ - Restaurant Order Management System',
        theme_color: '#4f46e5',
        background_color: '#ffffff',
        display: 'standalone',
        orientation: 'portrait-primary',
        scope: '/',
        start_url: '/',
        icons: [
          {
            src: '/icon-192x192.png',
            sizes: '192x192',
            type: 'image/png',
            purpose: 'any maskable'
          },
          {
            src: '/icon-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'any maskable'
          },
          {
            src: '/apple-touch-icon.png',
            sizes: '180x180',
            type: 'image/png',
            purpose: 'any'
          }
        ]
      },
      injectManifest: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2}'],
      },
      devOptions: {
        enabled: true,
        type: 'module'
      }
    })
  ],
})
