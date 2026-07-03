import { createApp } from 'vue'
import { createPinia } from 'pinia'
import './style.css'
import App from './App.vue'
import router from './router'
import { i18n } from './i18n'
import { useThemeStore } from './stores/theme'

const app = createApp(App)
const pinia = createPinia()

// Error tracking — no-op unless VITE_SENTRY_DSN is provided at build time
if (import.meta.env.VITE_SENTRY_DSN) {
  import('@sentry/vue').then((Sentry) => {
    Sentry.init({
      app,
      dsn: import.meta.env.VITE_SENTRY_DSN,
      environment: import.meta.env.MODE,
      tracesSampleRate: 0.1,
    })
  })
}

app.use(pinia)
app.use(router)
app.use(i18n)

// Initialize theme store - this will automatically apply the theme
// The store calls applyTheme() when created, but we also ensure it's applied after mount
const themeStore = useThemeStore()

app.mount('#app')

// Ensure theme is applied after DOM is ready (redundant but safe)
themeStore.applyTheme()
