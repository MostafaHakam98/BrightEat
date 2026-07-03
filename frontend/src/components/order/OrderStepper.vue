<template>
  <div class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200 dark:ring-gray-700 px-4 py-4 sm:px-6">
    <ol class="flex items-start" aria-label="Order progress">
      <li
        v-for="(step, i) in steps"
        :key="step.key"
        class="flex items-start"
        :class="i < steps.length - 1 ? 'flex-1' : ''"
        :aria-current="i === currentIndex ? 'step' : undefined"
      >
        <div class="flex flex-col items-center gap-1 shrink-0">
          <span
            class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold border-2 transition-colors"
            :class="circleClass(i)"
          >
            <template v-if="i < currentIndex">✓</template>
            <template v-else>{{ i + 1 }}</template>
          </span>
          <span class="text-[11px] sm:text-xs font-medium" :class="labelClass(i)">
            {{ step.label }}
          </span>
        </div>
        <div
          v-if="i < steps.length - 1"
          class="flex-1 h-0.5 mx-1.5 sm:mx-3 mt-[15px] rounded-full"
          :class="i < currentIndex ? 'bg-blue-500 dark:bg-blue-400' : 'bg-gray-200 dark:bg-gray-700'"
        ></div>
      </li>
    </ol>
    <p
      v-if="contextLine"
      class="mt-3 text-sm text-center font-medium"
      :class="contextClass"
    >
      {{ contextLine }}
    </p>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { formatCountdown, useTick } from '../../composables/useCountdown'

const props = defineProps({
  order: { type: Object, default: null },
})

const steps = [
  { key: 'OPEN', label: 'Open' },
  { key: 'LOCKED', label: 'Locked' },
  { key: 'ORDERED', label: 'Ordered' },
  { key: 'CLOSED', label: 'Closed' },
]

const tick = useTick(30000)

const currentIndex = computed(() => {
  const idx = steps.findIndex(s => s.key === props.order?.status)
  return idx === -1 ? 0 : idx
})

function circleClass(i) {
  if (i < currentIndex.value) {
    return 'border-blue-500 dark:border-blue-400 text-indigo-600 dark:text-indigo-400 bg-blue-50 dark:bg-blue-900/30'
  }
  if (i === currentIndex.value) {
    return 'border-indigo-600 dark:border-indigo-500 bg-indigo-600 dark:bg-indigo-500 text-white'
  }
  return 'border-gray-300 dark:border-gray-600 text-gray-400 dark:text-gray-500'
}

function labelClass(i) {
  if (i === currentIndex.value) return 'text-blue-700 dark:text-blue-300'
  if (i < currentIndex.value) return 'text-gray-700 dark:text-gray-300'
  return 'text-gray-400 dark:text-gray-500'
}

const countdown = computed(() => {
  // touch tick so the countdown re-evaluates on a timer
  void tick.value
  if (props.order?.status !== 'OPEN' || !props.order?.cutoff_time) return null
  return formatCountdown(props.order.cutoff_time)
})

const contextLine = computed(() => {
  const order = props.order
  if (!order) return ''
  switch (order.status) {
    case 'OPEN': {
      const c = countdown.value
      if (!c) return 'Open for orders'
      if (c.urgency === 'passed') return 'Cutoff passed — waiting to be locked'
      return c.text.replace(/^Closes in/, 'Locks in')
    }
    case 'LOCKED': {
      const payments = order.payments || []
      if (!payments.length) return 'Locked — payments are being calculated'
      const unpaid = payments.filter(p => !p.is_paid).length
      return `Waiting on ${unpaid} of ${payments.length} payments`
    }
    case 'ORDERED':
      return 'Food is on the way — settle up'
    case 'CLOSED':
      return 'Done'
    default:
      return ''
  }
})

const contextClass = computed(() => {
  if (props.order?.status === 'OPEN' && countdown.value) {
    if (countdown.value.urgency === 'urgent' || countdown.value.urgency === 'passed') {
      return 'text-red-600 dark:text-red-400'
    }
    if (countdown.value.urgency === 'warning') {
      return 'text-amber-600 dark:text-amber-400'
    }
  }
  return 'text-gray-600 dark:text-gray-300'
})
</script>
