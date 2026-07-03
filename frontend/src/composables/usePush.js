import { ref } from 'vue'
import api from '../api'

/* Web Push opt-in/out. Server disables the feature when VAPID keys are unset. */

const supported = 'serviceWorker' in navigator && 'PushManager' in window
const subscribed = ref(false)
const busy = ref(false)

function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const raw = window.atob(base64)
  return Uint8Array.from([...raw].map(c => c.charCodeAt(0)))
}

export function usePush() {
  async function refreshState() {
    if (!supported) return
    try {
      const reg = await navigator.serviceWorker.ready
      subscribed.value = !!(await reg.pushManager.getSubscription())
    } catch {
      subscribed.value = false
    }
  }

  async function serverEnabled() {
    try {
      const res = await api.get('/push/public_key/')
      return res.data.enabled ? res.data.public_key : null
    } catch {
      return null
    }
  }

  async function enable() {
    if (!supported) return { success: false, error: 'Push is not supported in this browser' }
    busy.value = true
    try {
      const publicKey = await serverEnabled()
      if (!publicKey) return { success: false, error: 'Push notifications are not configured on the server' }

      const permission = await Notification.requestPermission()
      if (permission !== 'granted') return { success: false, error: 'Notification permission was denied' }

      const reg = await navigator.serviceWorker.ready
      const sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(publicKey),
      })
      await api.post('/push/subscribe/', sub.toJSON())
      subscribed.value = true
      return { success: true }
    } catch (error) {
      return { success: false, error: error.message || 'Failed to enable push' }
    } finally {
      busy.value = false
    }
  }

  async function disable() {
    if (!supported) return { success: true }
    busy.value = true
    try {
      const reg = await navigator.serviceWorker.ready
      const sub = await reg.pushManager.getSubscription()
      if (sub) {
        await api.post('/push/unsubscribe/', { endpoint: sub.endpoint }).catch(() => {})
        await sub.unsubscribe()
      }
      subscribed.value = false
      return { success: true }
    } finally {
      busy.value = false
    }
  }

  return { supported, subscribed, busy, refreshState, enable, disable }
}
