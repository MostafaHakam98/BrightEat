<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Welcome to OrderQ</h1>
      <p class="mt-2 text-gray-600 dark:text-gray-400">Your internal food ordering portal</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
      <div id="create-order-form" class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200/80 dark:ring-gray-700/50 shadow-sm hover:shadow-md transition-shadow p-6">
        <div class="flex items-center gap-2 mb-4">
          <h2 class="text-xl font-semibold dark:text-white">Create New Order</h2>
          <span
            v-if="reorderBanner"
            class="text-xs bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 px-2 py-0.5 rounded-full"
          >
            ↺ {{ reorderBanner }}
          </span>
        </div>
        <form @submit.prevent="createOrder" class="space-y-4">
          <div class="relative" ref="restaurantDropdownRef">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Restaurant</label>
            <input
              v-model="restaurantSearch"
              @focus="restaurantOpen = true"
              @input="restaurantOpen = true"
              type="text"
              autocomplete="off"
              placeholder="Search restaurant…"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
            />
            <ul
              v-if="restaurantOpen && filteredRestaurants.length"
              class="absolute z-20 mt-1 w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-md shadow-lg max-h-48 overflow-y-auto"
            >
              <li
                v-for="r in filteredRestaurants"
                :key="r.id"
                @mousedown.prevent="selectRestaurant(r)"
                class="px-3 py-2 cursor-pointer text-sm text-gray-800 dark:text-gray-100 hover:bg-blue-50 dark:hover:bg-gray-600"
              >{{ r.name }}</li>
            </ul>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Menu
              <span v-if="availableMenus.length > 0" class="text-red-500 dark:text-red-400">*</span>
            </label>
            <div v-if="loadingMenus" class="mt-1 text-sm text-gray-500 dark:text-gray-400">Loading menus...</div>
            <select
              v-else
              v-model="newOrder.menu"
              :required="availableMenus.length > 0"
              :disabled="!newOrder.restaurant || availableMenus.length === 0"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 disabled:bg-gray-100 dark:disabled:bg-gray-600 disabled:cursor-not-allowed dark:bg-gray-700 dark:text-white"
            >
              <option :value="null">
                {{ availableMenus.length === 0 ? 'No menus available for this restaurant' : 'Select a menu' }}
              </option>
              <option v-for="menu in availableMenus" :key="menu.id" :value="menu.id">
                {{ menu.name }}
              </option>
            </select>
            <p v-if="availableMenus.length > 0" class="mt-1 text-xs text-gray-500 dark:text-gray-400">Select a menu for this order</p>
            <p v-else-if="newOrder.restaurant" class="mt-1 text-xs text-gray-500 dark:text-gray-400">No menus available. You can still create the order and add items manually.</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Cutoff Time</label>
            <input
              v-model="newOrder.cutoff_time"
              type="datetime-local"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
            />
          </div>

          <!-- Fee Preset -->
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Fee Preset</label>
            <select
              v-model="selectedPresetId"
              @change="applyPreset"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
            >
              <option :value="null">— Custom / No Preset —</option>
              <option v-for="p in ordersStore.feePresets" :key="p.id" :value="p.id">
                {{ p.name }} (delivery {{ p.delivery_fee }}, tip {{ p.tip }})
              </option>
            </select>
          </div>

          <!-- Fee fields (shown collapsed by default, expanded when preset applied or toggled) -->
          <div>
            <button
              type="button"
              @click="showFeeFields = !showFeeFields"
              class="text-xs text-blue-600 dark:text-blue-400 hover:underline"
            >
              {{ showFeeFields ? 'Hide fee details ▲' : 'Edit fee details ▼' }}
            </button>
            <div v-if="showFeeFields" class="mt-2 grid grid-cols-3 gap-2">
              <div>
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Delivery</label>
                <input v-model.number="newOrder.delivery_fee" type="number" min="0" step="0.01"
                  class="mt-1 block w-full px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Tip</label>
                <input v-model.number="newOrder.tip" type="number" min="0" step="0.01"
                  class="mt-1 block w-full px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Service</label>
                <input v-model.number="newOrder.service_fee" type="number" min="0" step="0.01"
                  class="mt-1 block w-full px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
              </div>
              <div class="col-span-3">
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Fee Split</label>
                <select v-model="newOrder.fee_split_rule"
                  class="mt-1 block w-full px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white">
                  <option value="equal">Equal</option>
                  <option value="proportional">Proportional</option>
                  <option value="collector_pays">Collector Pays</option>
                </select>
              </div>
            </div>
          </div>

          <div class="flex items-center">
            <input
              v-model="newOrder.is_private"
              type="checkbox"
              id="is_private"
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <label for="is_private" class="ml-2 block text-sm text-gray-700 dark:text-gray-300">
              Make this order private (only participants can see it)
            </label>
          </div>
          <button
            type="submit"
            :disabled="loading"
            class="w-full bg-indigo-600 dark:bg-indigo-500 text-white px-4 py-2 rounded-md hover:bg-indigo-700 dark:hover:bg-indigo-600 disabled:opacity-50 font-medium transition-colors"
          >
            {{ loading ? 'Creating...' : 'Create Order' }}
          </button>
        </form>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200/80 dark:ring-gray-700/50 shadow-sm hover:shadow-md transition-shadow p-6">
        <h2 class="text-xl font-semibold mb-4 dark:text-white">Join Order</h2>
        <form @submit.prevent="joinOrder" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Order Code</label>
            <input
              v-model="joinCode"
              type="text"
              placeholder="Enter order code"
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
            />
          </div>
          <button
            type="submit"
            :disabled="loading"
            class="w-full bg-green-600 dark:bg-green-500 text-white px-4 py-2 rounded-md hover:bg-green-700 dark:hover:bg-green-600 disabled:opacity-50"
          >
            {{ loading ? 'Joining...' : 'Join Order' }}
          </button>
        </form>
      </div>
    </div>

    <div class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200/80 dark:ring-gray-700/50 shadow-sm">
      <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
        <h2 class="text-xl font-semibold dark:text-white">Active Orders</h2>
      </div>
      <div class="p-6">
        <div v-if="loadingOrders" class="text-center py-8 text-gray-600 dark:text-gray-400">Loading...</div>
        <div v-else-if="activeOrders.length === 0" class="text-center py-8 text-gray-500 dark:text-gray-400">
          No active orders
        </div>
        <div v-else class="space-y-4">
          <div
            v-for="order in activeOrders"
            :key="order.id"
            :class="[
              'border-l-4 rounded-lg p-4 pl-5 hover:shadow-md transition dark:bg-gray-700 border border-gray-200 dark:border-gray-600',
              order.status === 'OPEN' ? 'border-l-green-500' : '',
              order.status === 'LOCKED' ? 'border-l-amber-500' : '',
              order.status === 'ORDERED' ? 'border-l-blue-500' : '',
              order.status === 'CLOSED' ? 'border-l-gray-400' : '',
            ]"
          >
            <div class="flex justify-between items-start">
              <div>
                <h3 class="text-lg font-semibold dark:text-white">{{ order.restaurant_name }}</h3>
                <p class="text-sm text-gray-600 dark:text-gray-400">Code: {{ order.code }}</p>
                <p class="text-sm text-gray-600 dark:text-gray-400">Collector: {{ order.collector_name }}</p>
                <p class="text-sm text-gray-600 dark:text-gray-400">Status:
                  <span :class="{
                    'text-green-600 dark:text-green-400': order.status === 'OPEN',
                    'text-yellow-600 dark:text-yellow-400': order.status === 'LOCKED',
                    'text-blue-600 dark:text-blue-400': order.status === 'ORDERED',
                    'text-gray-600 dark:text-gray-400': order.status === 'CLOSED',
                  }">
                    {{ order.status }}
                  </span>
                </p>
                <p v-if="countdown(order.cutoff_time)" class="mt-1">
                  <span
                    class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium"
                    :class="{
                      'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400': countdown(order.cutoff_time).urgency === 'normal',
                      'bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300': countdown(order.cutoff_time).urgency === 'warning',
                      'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-300 animate-pulse': countdown(order.cutoff_time).urgency === 'urgent',
                      'bg-gray-100 dark:bg-gray-700 text-gray-400 dark:text-gray-500': countdown(order.cutoff_time).urgency === 'passed',
                    }"
                  >
                    ⏱ {{ countdown(order.cutoff_time).text }}
                  </span>
                </p>
                <p v-if="getPendingPayment(order.id)" class="text-sm font-semibold text-yellow-600 dark:text-yellow-400 mt-1">
                  Pending: {{ formatPrice(getPendingPayment(order.id).amount) }} EGP
                </p>
              </div>
              <div class="flex flex-col gap-2">
                <router-link
                  :to="`/orders/${order.code}`"
                  class="bg-indigo-600 dark:bg-indigo-500 text-white px-4 py-2 rounded-md hover:bg-indigo-700 dark:hover:bg-indigo-600 text-center text-sm font-medium transition-colors"
                >
                  View
                </router-link>
                <button
                  v-if="getPendingPayment(order.id)"
                  @click="markAsPaid(getPendingPayment(order.id).payment_id, order.id)"
                  :disabled="markingPaid === getPendingPayment(order.id).payment_id"
                  class="bg-green-600 dark:bg-green-500 text-white px-4 py-2 rounded-md hover:bg-green-700 dark:hover:bg-green-600 disabled:opacity-50 text-sm"
                >
                  {{ markingPaid === getPendingPayment(order.id).payment_id ? 'Paying...' : 'Pay' }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, onBeforeUnmount } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useOrdersStore } from '../stores/orders'
import { useAuthStore } from '../stores/auth'
import { useNotificationsStore } from '../stores/notifications'
import { formatCountdown, useTick } from '../composables/useCountdown'
import { useToast } from '../composables/useToast'
import { useConfirm } from '../composables/useConfirm'
import api from '../api'

const toast = useToast()
const { confirm: $confirm } = useConfirm()

const router = useRouter()
const route = useRoute()
const ordersStore = useOrdersStore()
const authStore = useAuthStore()

const tick = useTick()
function countdown(cutoffTime) {
  void tick.value
  return formatCountdown(cutoffTime)
}

const newOrder = ref({
  restaurant: '',
  menu: null,
  cutoff_time: '',
  is_private: false,
  delivery_fee: 30,
  tip: 30,
  service_fee: 0,
  fee_split_rule: 'equal',
})
const joinCode = ref('')
const loading = ref(false)
const loadingOrders = ref(false)
const availableMenus = ref([])
const loadingMenus = ref(false)
const pendingPayments = ref([])
const markingPaid = ref(null)
const selectedPresetId = ref(null)
const showFeeFields = ref(false)

function applyPreset() {
  const preset = ordersStore.feePresets.find(p => p.id === selectedPresetId.value)
  if (preset) {
    newOrder.value.delivery_fee = parseFloat(preset.delivery_fee)
    newOrder.value.tip = parseFloat(preset.tip)
    newOrder.value.service_fee = parseFloat(preset.service_fee)
    newOrder.value.fee_split_rule = preset.fee_split_rule || 'equal'
    showFeeFields.value = true
  }
}

const activeOrders = computed(() => {
  return ordersStore.orders.filter(o => o.status !== 'CLOSED')
})

function formatPrice(value) {
  if (value === null || value === undefined) return '0.00'
  const num = typeof value === 'string' ? parseFloat(value) : value
  return isNaN(num) ? '0.00' : num.toFixed(2)
}

function getPendingPayment(orderId) {
  return pendingPayments.value.find(p => p.order_id === orderId)
}

async function fetchPendingPayments() {
  try {
    const response = await api.get('/orders/pending_payments/')
    pendingPayments.value = response.data
  } catch (error) {
    console.error('Failed to fetch pending payments:', error)
  }
}

async function markAsPaid(paymentId, orderId) {
  if (!(await $confirm('Mark this payment as paid?', 'Confirm Payment'))) return

  markingPaid.value = paymentId
  try {
    await api.post(`/payments/${paymentId}/mark_paid/`)
    pendingPayments.value = pendingPayments.value.filter(p => p.payment_id !== paymentId)
    toast.success('Payment marked as paid!')
  } catch (error) {
    toast.error('Failed to mark payment as paid: ' + (error.response?.data?.error || error.message))
  } finally {
    markingPaid.value = null
  }
}

async function onRestaurantChange() {
  if (!newOrder.value.restaurant) {
    availableMenus.value = []
    newOrder.value.menu = null
    return
  }
  
  loadingMenus.value = true
  try {
    const result = await ordersStore.fetchMenus(parseInt(newOrder.value.restaurant))
    if (result.success) {
      availableMenus.value = result.data.filter(menu => menu.is_active)
    } else {
      availableMenus.value = []
    }
    newOrder.value.menu = null
  } catch (error) {
    console.error('Error fetching menus:', error)
    availableMenus.value = []
  } finally {
    loadingMenus.value = false
  }
}

const reorderBanner = ref('')

// Restaurant type-ahead search
const restaurantSearch = ref('')
const restaurantOpen = ref(false)
const restaurantDropdownRef = ref(null)

const filteredRestaurants = computed(() => {
  const q = restaurantSearch.value.toLowerCase()
  return ordersStore.restaurants.filter(r => r.name.toLowerCase().includes(q))
})

function selectRestaurant(r) {
  newOrder.value.restaurant = String(r.id)
  restaurantSearch.value = r.name
  restaurantOpen.value = false
  onRestaurantChange()
}

function handleOutsideClick(e) {
  if (restaurantDropdownRef.value && !restaurantDropdownRef.value.contains(e.target)) {
    restaurantOpen.value = false
  }
}
onMounted(() => document.addEventListener('mousedown', handleOutsideClick))
onBeforeUnmount(() => document.removeEventListener('mousedown', handleOutsideClick))

// Keep "Active Orders" live: refetch when any order is created/updated elsewhere
const notifStore = useNotificationsStore()
let offOrderEvents = null
onMounted(() => {
  offOrderEvents = notifStore.onOrderEvent(() => ordersStore.fetchOrders())
})
onBeforeUnmount(() => { if (offOrderEvents) offOrderEvents() })

onMounted(async () => {
  loadingOrders.value = true
  await Promise.all([
    ordersStore.fetchRestaurants(),
    ordersStore.fetchOrders(),
    ordersStore.fetchFeePresets(),
    fetchPendingPayments(),
  ])
  loadingOrders.value = false

  // Pre-fill form when navigated here via ↺ Reorder
  if (route.query.restaurant) {
    newOrder.value.restaurant = String(route.query.restaurant)
    await onRestaurantChange()
    if (route.query.menu) {
      newOrder.value.menu = parseInt(route.query.menu)
    }
    const restaurant = ordersStore.restaurants.find(r => r.id === parseInt(route.query.restaurant))
    if (restaurant) restaurantSearch.value = restaurant.name
    reorderBanner.value = restaurant ? `Re-ordering from ${restaurant.name}` : 'Re-ordering'
    document.getElementById('create-order-form')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
})

async function createOrder() {
  if (!newOrder.value.restaurant) {
    toast.warning('Please select a restaurant')
    return
  }

  if (availableMenus.value.length > 0 && !newOrder.value.menu) {
    toast.warning('Please select a menu for this restaurant')
    return
  }
  
  loading.value = true
  const orderData = {
    restaurant: parseInt(newOrder.value.restaurant),
    is_private: newOrder.value.is_private,
    delivery_fee: newOrder.value.delivery_fee,
    tip: newOrder.value.tip,
    service_fee: newOrder.value.service_fee,
    fee_split_rule: newOrder.value.fee_split_rule,
  }

  if (newOrder.value.menu) {
    orderData.menu = parseInt(newOrder.value.menu)
  }

  if (newOrder.value.cutoff_time) {
    orderData.cutoff_time = newOrder.value.cutoff_time
  }

  const result = await ordersStore.createOrder(orderData)

  if (result.success) {
    router.push(`/orders/${result.data.code}`)
    newOrder.value = { restaurant: '', menu: null, cutoff_time: '', is_private: false, delivery_fee: 30, tip: 30, service_fee: 0, fee_split_rule: 'equal' }
    selectedPresetId.value = null
    showFeeFields.value = false
    availableMenus.value = []
  } else {
    toast.error('Failed to create order: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  loading.value = false
}

async function joinOrder() {
  loading.value = true
  const result = await ordersStore.fetchOrderByCode(joinCode.value.toUpperCase())
  
  if (result.success) {
    router.push(`/orders/${joinCode.value.toUpperCase()}`)
  } else {
    toast.error('Order not found')
  }
  loading.value = false
}
</script>

