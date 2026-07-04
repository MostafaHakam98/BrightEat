<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

    <!-- Header -->
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Reports</h1>
      <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Your spending and activity statistics</p>
    </div>

    <!-- Controls row -->
    <div class="flex flex-wrap items-center gap-4 mb-6">
      <!-- Period tabs -->
      <div class="flex gap-1 bg-gray-100 dark:bg-gray-800 rounded-xl p-1">
        <button
          v-for="p in periods"
          :key="p.value"
          @click="selectedPeriod = p.value; fetchReport()"
          :class="[
            'px-3 py-1.5 rounded-lg text-sm font-medium transition-colors',
            selectedPeriod === p.value
              ? 'bg-white dark:bg-gray-700 text-indigo-600 dark:text-indigo-400 shadow-sm'
              : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white',
          ]"
        >
          {{ p.label }}
        </button>
      </div>

      <!-- User picker (manager/admin) -->
      <select
        v-if="authStore.isManager || authStore.isAdmin"
        v-model="selectedUserId"
        @change="fetchReport"
        class="px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg dark:bg-gray-700 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
      >
        <option :value="authStore.user?.id">Me</option>
        <option v-for="user in users" :key="user.id" :value="user.id">{{ user.username }}</option>
      </select>
    </div>

    <!-- Loading -->
    <div v-if="loading" aria-busy="true">
      <span class="sr-only">Loading report…</span>
      <div class="mb-6 flex items-baseline gap-3">
        <BaseSkeleton width="11rem" height="1.375rem" />
        <BaseSkeleton width="6rem" height="0.875rem" />
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-4">
        <div
          v-for="i in 6"
          :key="i"
          class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-100 dark:border-gray-700 p-5 space-y-2.5"
        >
          <BaseSkeleton width="55%" height="0.75rem" />
          <BaseSkeleton width="40%" height="1.75rem" />
        </div>
      </div>
      <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-100 dark:border-gray-700 p-5 space-y-3">
        <BaseSkeleton width="10rem" height="1rem" />
        <BaseSkeleton v-for="i in 4" :key="i" height="0.875rem" :width="`${90 - i * 12}%`" />
      </div>
    </div>

    <!-- Report -->
    <div v-else-if="report">
      <!-- Period heading -->
      <div class="mb-6 flex items-baseline gap-3">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-white">{{ report.period_label }}</h2>
        <span class="text-sm text-gray-500 dark:text-gray-400">· {{ report.user.username }}</span>
      </div>

      <!-- Metric grid -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-4">
        <MetricCard
          v-for="m in metrics"
          :key="m.key"
          :label="m.label"
          :value="formatMetric(m.key)"
          :sub="m.sub"
          :color="m.color"
          @click="openDetail(m.key)"
        />
      </div>
    </div>

    <!-- Empty -->
    <div v-else class="text-center py-16 text-gray-500 dark:text-gray-400">
      No report data available.
    </div>

    <!-- Detail modal -->
    <teleport to="body">
      <transition name="dialog">
        <div
          v-if="detailKey"
          class="fixed inset-0 z-[9998] flex items-center justify-center p-4"
          @click.self="detailKey = null"
        >
          <div class="absolute inset-0 bg-black/40 dark:bg-black/60 backdrop-blur-sm" @click="detailKey = null"/>
          <div class="relative bg-white dark:bg-gray-800 rounded-2xl shadow-2xl ring-1 ring-black/5 dark:ring-white/10 w-full max-w-lg p-6">
            <div class="flex items-start justify-between mb-4">
              <h3 class="text-base font-semibold text-gray-900 dark:text-white">{{ currentDetail?.title }}</h3>
              <button @click="detailKey = null" class="p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
            <div class="space-y-3">
              <div class="bg-gray-50 dark:bg-gray-700/60 rounded-xl p-4">
                <p class="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-2">Formula</p>
                <p class="text-sm text-gray-800 dark:text-gray-200 whitespace-pre-line font-mono leading-relaxed">{{ currentDetail?.formula }}</p>
              </div>
              <div class="bg-indigo-50 dark:bg-indigo-900/20 rounded-xl p-4">
                <p class="text-xs font-semibold text-indigo-600 dark:text-indigo-400 uppercase tracking-wider mb-2">Explanation</p>
                <p class="text-sm text-gray-700 dark:text-gray-300 leading-relaxed">{{ currentDetail?.explanation }}</p>
              </div>
            </div>
          </div>
        </div>
      </transition>
    </teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, defineComponent, h } from 'vue'
import { useOrdersStore } from '../stores/orders'
import { useAuthStore } from '../stores/auth'
import api from '../api'
import BaseSkeleton from '../components/ui/BaseSkeleton.vue'

const ordersStore = useOrdersStore()
const authStore = useAuthStore()

const loading = ref(false)
const report = ref(null)
const selectedUserId = ref(authStore.user?.id)
const users = ref([])
const selectedPeriod = ref('monthly')
const detailKey = ref(null)

const periods = [
  { value: 'daily',    label: 'Today' },
  { value: 'weekly',   label: 'This Week' },
  { value: 'monthly',  label: 'This Month' },
  { value: 'all_time', label: 'All Time' },
]

const metrics = [
  { key: 'total_spend',             label: 'Total Spend',            color: 'blue',   sub: 'Your total payments' },
  { key: 'collector_count',         label: 'Times as Collector',     color: 'green',  sub: 'Orders you collected' },
  { key: 'unpaid_count',            label: 'Unpaid Incidents',       color: 'red',    sub: 'Payments still owed' },
  { key: 'total_collected',         label: 'Total Collected',        color: 'purple', sub: 'From others as collector' },
  { key: 'total_orders_participated',label: 'Orders Participated',  color: 'indigo', sub: 'Unique orders joined' },
  { key: 'avg_order_value',         label: 'Avg Order Value',        color: 'teal',   sub: 'Average total per order' },
  { key: 'total_fees_paid',         label: 'Fees Paid',              color: 'orange', sub: 'Delivery, tip, service' },
  { key: 'payment_completion_rate', label: 'Payment Rate',           color: 'cyan',   sub: 'Payments marked paid' },
  { key: 'total_pending',           label: 'Total Pending',          color: 'pink',   sub: 'Amount you owe' },
  { key: 'total_owed_to_user',      label: 'Owed to You',            color: 'yellow', sub: 'Others owe you' },
  { key: 'most_ordered_restaurant', label: 'Favourite Restaurant',   color: 'emerald',sub: 'Most-ordered spot' },
]

function formatMetric(key) {
  if (!report.value) return '–'
  const v = report.value[key]
  if (key === 'payment_completion_rate') return `${v.toFixed(1)}%`
  if (key === 'collector_count' || key === 'total_orders_participated' || key === 'unpaid_count') return v
  if (key === 'most_ordered_restaurant') return v || 'N/A'
  return `${(+v).toFixed(2)} EGP`
}

const periodPhraseMap = {
  daily:    'today',
  weekly:   'this week',
  monthly:  'this month',
  all_time: 'all time',
}

const details = computed(() => {
  const phrase = periodPhraseMap[selectedPeriod.value]
  return {
    total_spend: {
      title: 'Total Spend',
      formula: `Sum of all payment amounts where you are the payer\n(from ${phrase})`,
      explanation: `Total amount you have spent ${phrase} across all orders you participated in. Includes item costs and your share of fees.`,
    },
    collector_count: {
      title: 'Times as Collector',
      formula: `COUNT(orders where you are collector)\n(from ${phrase})`,
      explanation: `How many times you were the collector ${phrase}. As collector, your own payment is automatically marked paid.`,
    },
    unpaid_count: {
      title: 'Unpaid Incidents',
      formula: `COUNT(payments where is_paid = False\nand order status ∈ {LOCKED, ORDERED, CLOSED})\n(from ${phrase})`,
      explanation: `Number of payments you still need to make ${phrase} — orders that are locked or closed but not yet paid.`,
    },
    total_collected: {
      title: 'Total Collected',
      formula: `Sum of payments from other participants\nfor orders where you were collector\n(from ${phrase})`,
      explanation: `Money you collected from others when acting as collector ${phrase}.`,
    },
    total_orders_participated: {
      title: 'Orders Participated',
      formula: `COUNT(DISTINCT orders where you have items)\n(from ${phrase})`,
      explanation: `Unique orders you added items to ${phrase}.`,
    },
    avg_order_value: {
      title: 'Avg Order Value',
      formula: `Sum(order.total_cost) / COUNT(orders participated)\n(from ${phrase})`,
      explanation: `Average total cost (items + all fees) of orders you participated in ${phrase}.`,
    },
    total_fees_paid: {
      title: 'Fees Paid',
      formula: `Total Spend − Your Item Costs\n(from ${phrase})`,
      explanation: `Amount you paid purely in delivery, tip, and service fees ${phrase} — excludes food cost.`,
    },
    payment_completion_rate: {
      title: 'Payment Rate',
      formula: `(Paid Payments / Total Payments) × 100\n(from ${phrase})`,
      explanation: `Percentage of your payment obligations you have marked as paid ${phrase}. 100% = fully settled.`,
    },
    total_pending: {
      title: 'Total Pending',
      formula: `Sum of unpaid payment amounts\n(from ${phrase})`,
      explanation: `Total money you still owe for locked/closed orders ${phrase}.`,
    },
    total_owed_to_user: {
      title: 'Owed to You',
      formula: `Sum of unpaid payments from others\nwhere you were collector\n(from ${phrase})`,
      explanation: `Total others owe you for orders you collected ${phrase} that haven't been settled.`,
    },
    most_ordered_restaurant: {
      title: 'Favourite Restaurant',
      formula: `Restaurant with MAX(COUNT(DISTINCT orders))\nwhere you have items\n(from ${phrase})`,
      explanation: `The restaurant you ordered from most frequently ${phrase}, counted by distinct orders.`,
    },
  }
})

const currentDetail = computed(() => detailKey.value ? details.value[detailKey.value] : null)

function openDetail(key) { detailKey.value = key }

onMounted(async () => {
  if (authStore.isManager || authStore.isAdmin) {
    try {
      const res = await api.get('/users/')
      users.value = (res.data.results || res.data).filter(u => u.id !== authStore.user?.id)
    } catch {}
  }
  await fetchReport()
})

async function fetchReport() {
  if (!selectedUserId.value) return
  loading.value = true
  const result = await ordersStore.getReport(selectedUserId.value, selectedPeriod.value)
  if (result.success) report.value = result.data
  loading.value = false
}

// ── MetricCard component ───────────────────────────────────────
const colorMap = {
  blue:    { bg: 'bg-blue-50 dark:bg-blue-900/20',    text: 'text-indigo-600 dark:text-indigo-400',    hover: 'hover:bg-blue-100 dark:hover:bg-blue-900/40' },
  green:   { bg: 'bg-green-50 dark:bg-green-900/20',  text: 'text-green-600 dark:text-green-400',  hover: 'hover:bg-green-100 dark:hover:bg-green-900/40' },
  red:     { bg: 'bg-red-50 dark:bg-red-900/20',      text: 'text-red-600 dark:text-red-400',      hover: 'hover:bg-red-100 dark:hover:bg-red-900/40' },
  purple:  { bg: 'bg-purple-50 dark:bg-purple-900/20',text: 'text-purple-600 dark:text-purple-400',hover: 'hover:bg-purple-100 dark:hover:bg-purple-900/40' },
  indigo:  { bg: 'bg-indigo-50 dark:bg-indigo-900/20',text: 'text-indigo-600 dark:text-indigo-400',hover: 'hover:bg-indigo-100 dark:hover:bg-indigo-900/40' },
  teal:    { bg: 'bg-teal-50 dark:bg-teal-900/20',    text: 'text-teal-600 dark:text-teal-400',    hover: 'hover:bg-teal-100 dark:hover:bg-teal-900/40' },
  orange:  { bg: 'bg-orange-50 dark:bg-orange-900/20',text: 'text-orange-600 dark:text-orange-400',hover: 'hover:bg-orange-100 dark:hover:bg-orange-900/40' },
  cyan:    { bg: 'bg-cyan-50 dark:bg-cyan-900/20',    text: 'text-cyan-600 dark:text-cyan-400',    hover: 'hover:bg-cyan-100 dark:hover:bg-cyan-900/40' },
  pink:    { bg: 'bg-pink-50 dark:bg-pink-900/20',    text: 'text-pink-600 dark:text-pink-400',    hover: 'hover:bg-pink-100 dark:hover:bg-pink-900/40' },
  yellow:  { bg: 'bg-yellow-50 dark:bg-yellow-900/20',text: 'text-yellow-600 dark:text-yellow-400',hover: 'hover:bg-yellow-100 dark:hover:bg-yellow-900/40' },
  emerald: { bg: 'bg-emerald-50 dark:bg-emerald-900/20',text:'text-emerald-600 dark:text-emerald-400',hover:'hover:bg-emerald-100 dark:hover:bg-emerald-900/40' },
}

const MetricCard = defineComponent({
  props: { label: String, value: [String, Number], sub: String, color: String },
  emits: ['click'],
  setup(props, { emit }) {
    return () => {
      const c = colorMap[props.color] || colorMap.blue
      return h('button', {
        onClick: () => emit('click'),
        class: `w-full text-left rounded-2xl p-5 transition-colors ring-1 ring-black/5 dark:ring-white/10 ${c.bg} ${c.hover}`,
      }, [
        h('p', { class: 'text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-2' }, props.label),
        h('p', { class: `text-2xl font-bold leading-none mb-1 ${c.text}` }, String(props.value)),
        h('p', { class: 'text-xs text-gray-400 dark:text-gray-500' }, props.sub),
      ])
    }
  }
})
</script>

<style scoped>
.dialog-enter-active, .dialog-leave-active { transition: opacity 0.15s ease; }
.dialog-enter-from, .dialog-leave-to { opacity: 0; }
</style>
