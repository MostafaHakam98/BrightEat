import { reactive } from 'vue'

const toasts = reactive([])
let nextId = 0

export function useToast() {
  function add(message, type = 'info', duration = 3500) {
    const id = ++nextId
    toasts.push({ id, message, type })
    setTimeout(() => {
      const idx = toasts.findIndex(t => t.id === id)
      if (idx !== -1) toasts.splice(idx, 1)
    }, duration)
  }

  return {
    toasts,
    success: (msg, duration = 3500) => add(msg, 'success', duration),
    error:   (msg, duration = 5000) => add(msg, 'error', duration),
    info:    (msg, duration = 3500) => add(msg, 'info', duration),
    warning: (msg, duration = 4000) => add(msg, 'warning', duration),
    remove:  (id) => { const i = toasts.findIndex(t => t.id === id); if (i !== -1) toasts.splice(i, 1) },
  }
}
