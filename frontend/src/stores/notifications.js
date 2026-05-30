import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '../api'

export const useNotificationsStore = defineStore('notifications', () => {
  const notifications = ref([])
  const unreadCount = ref(0)

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

  return { notifications, unreadCount, fetchUnreadCount, fetchNotifications, markRead, markAllRead }
})
