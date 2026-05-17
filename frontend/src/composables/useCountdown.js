import { ref, onMounted, onUnmounted } from 'vue'

export function formatCountdown(cutoffTime) {
  if (!cutoffTime) return null
  const diff = new Date(cutoffTime) - Date.now()
  if (diff <= 0) return { text: 'Cutoff passed', urgency: 'passed' }

  const totalMin = Math.floor(diff / 60000)
  const hours = Math.floor(totalMin / 60)
  const mins = totalMin % 60
  const days = Math.floor(hours / 24)

  if (days >= 1) return { text: `Closes in ${days}d ${hours % 24}h`, urgency: 'normal' }
  if (hours >= 1) return { text: `Closes in ${hours}h ${mins}m`, urgency: 'warning' }
  if (totalMin > 0) return { text: `Closes in ${totalMin}m`, urgency: 'urgent' }
  return { text: 'Closing soon', urgency: 'urgent' }
}

// Single interval shared per component instance — touch tick.value in a method
// to make countdown() reactive without creating one timer per order card.
export function useTick(intervalMs = 30000) {
  const tick = ref(0)
  let timer = null
  onMounted(() => { timer = setInterval(() => tick.value++, intervalMs) })
  onUnmounted(() => clearInterval(timer))
  return tick
}
