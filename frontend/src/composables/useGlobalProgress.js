import { ref, computed } from 'vue'

/* Global "something is loading" signal. Every in-flight API request and route
 * transition increments the counter; the top progress bar in App.vue renders
 * while it's non-zero. Small grace period on stop so rapid request chains
 * don't make the bar flicker. */

const inflight = ref(0)
const visible = ref(false)
let hideTimer = null

export function progressStart() {
  inflight.value += 1
  if (hideTimer) { clearTimeout(hideTimer); hideTimer = null }
  visible.value = true
}

export function progressStop() {
  inflight.value = Math.max(0, inflight.value - 1)
  if (inflight.value === 0) {
    // let chained requests (e.g. Promise.all pages) keep one continuous bar
    hideTimer = setTimeout(() => { visible.value = false }, 250)
  }
}

export function useGlobalProgress() {
  return {
    loading: computed(() => visible.value),
  }
}
