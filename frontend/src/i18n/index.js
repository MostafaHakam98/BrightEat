import { createI18n } from 'vue-i18n'
import en from '../locales/en.json'
import ar from '../locales/ar.json'

// Arabic strings fall back to English until fully translated — a mixed page
// beats a broken one. Locale persists per device.
export const RTL_LOCALES = ['ar']

const saved = localStorage.getItem('locale')
const initialLocale = saved === 'ar' || saved === 'en' ? saved : 'en'

export const i18n = createI18n({
  legacy: false,
  locale: initialLocale,
  fallbackLocale: 'en',
  messages: { en, ar },
  missingWarn: false,
  fallbackWarn: false,
})

export function applyLocale(locale) {
  i18n.global.locale.value = locale
  localStorage.setItem('locale', locale)
  document.documentElement.lang = locale
  document.documentElement.dir = RTL_LOCALES.includes(locale) ? 'rtl' : 'ltr'
}

// Apply direction/lang for the initial load
applyLocale(initialLocale)
