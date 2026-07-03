import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '../api'

export const useNotificationsStore = defineStore('notifications', () => {
  const notifications = ref([])
  const unreadCount = ref(0)

  // ── Live delivery over /ws/notifications/ ────────────────────────
  // The backend pushes {type: 'notification'} to the user's personal group,
  // and {type: 'new_order' | 'order_update'} to everyone — so list pages can
  // refresh without polling.
  const liveSocket = ref(null)
  let reconnectAttempts = 0
  let pingTimer = null
  let shouldReconnect = false
  const orderListeners = new Set()
  const notificationListeners = new Set()

  function onOrderEvent(cb) {
    orderListeners.add(cb)
    return () => orderListeners.delete(cb)
  }

  function onNotification(cb) {
    notificationListeners.add(cb)
    return () => notificationListeners.delete(cb)
  }

  function connectLive() {
    if (liveSocket.value && liveSocket.value.readyState === WebSocket.OPEN) return
    const token = localStorage.getItem('access_token')
    if (!token) return

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    const ws = new WebSocket(
      `${protocol}//${window.location.host}/ws/notifications/?token=${encodeURIComponent(token)}`
    )
    shouldReconnect = true

    ws.onopen = () => { reconnectAttempts = 0 }

    ws.onmessage = (event) => {
      let data
      try { data = JSON.parse(event.data) } catch { return }
      if (data.type === 'notification' && data.notification) {
        notifications.value.unshift(data.notification)
        unreadCount.value += 1
        notificationListeners.forEach(cb => cb(data.notification))
      } else if ((data.type === 'new_order' || data.type === 'order_update') && data.order) {
        orderListeners.forEach(cb => cb(data.type, data.order))
      }
    }

    ws.onclose = (event) => {
      clearInterval(pingTimer)
      if (shouldReconnect && event.code !== 1000 && reconnectAttempts < 5) {
        reconnectAttempts += 1
        setTimeout(connectLive, 3000)
      }
    }

    pingTimer = setInterval(() => {
      if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ type: 'ping' }))
    }, 30_000)

    liveSocket.value = ws
  }

  function disconnectLive() {
    shouldReconnect = false
    clearInterval(pingTimer)
    if (liveSocket.value) {
      liveSocket.value.close(1000, 'Client disconnecting')
      liveSocket.value = null
    }
  }

  // ── REST (initial load + polling fallback) ───────────────────────
  async function fetchUnreadCount() {
    try {
      const res = await api.get('/notifications/unread_count/')
      unreadCount.value = res.data.unread_count
    } catch {
      // silently ignore — polling failure should not break the UI
    }
  }

  async function fetchNotifications() {
    try {
      const res = await api.get('/notifications/')
      notifications.value = res.data
      unreadCount.value = notifications.value.filter(n => !n.is_read).length
    } catch {
      //
    }
  }

  async function markRead(id) {
    await api.post(`/notifications/${id}/mark_read/`)
    const n = notifications.value.find(n => n.id === id)
    if (n) n.is_read = true
    unreadCount.value = notifications.value.filter(n => !n.is_read).length
  }

  async function markAllRead() {
    await api.post('/notifications/mark_all_read/')
    notifications.value.forEach(n => { n.is_read = true })
    unreadCount.value = 0
  }

  return {
    notifications, unreadCount,
    fetchUnreadCount, fetchNotifications, markRead, markAllRead,
    connectLive, disconnectLive, onOrderEvent, onNotification,
  }
})
