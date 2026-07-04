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
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 dark:text-white"
            />
            <ul
              v-if="restaurantOpen && filteredRestaurants.length"
              class="absolute z-20 mt-1 w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-md shadow-lg max-h-48 overflow-y-auto"
            >
              <li
                v-for="r in filteredRestaurants"
                :key="r.id"
                @mousedown.prevent="selectRestaurant(r)"
                class="px-3 py-2 cursor-pointer text-sm text-gray-800 dark:text-gray-100 hover:bg-indigo-50 dark:hover:bg-gray-600"
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
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 disabled:bg-gray-100 dark:disabled:bg-gray-600 disabled:cursor-not-allowed dark:bg-gray-700 dark:text-white"
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
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 dark:text-white"
            />
          </div>

          <!-- Fee Preset -->
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Fee Preset</label>
            <select
              v-model="selectedPresetId"
              @change="applyPreset"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 dark:text-white"
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
              class="text-xs text-indigo-600 dark:text-indigo-400 hover:underline"
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
              class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
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

      <BaseCard title="⏰ Scheduled orders">
        <div v-if="loadingSchedules" class="text-sm text-gray-500 dark:text-gray-400 py-2">Loading schedules…</div>
        <div v-else-if="schedules.length === 0" class="text-sm text-gray-500 dark:text-gray-400 py-2">
          No schedules yet — set one up and the order opens itself.
        </div>
        <div v-else class="space-y-3">
          <div
            v-for="schedule in schedules"
            :key="schedule.id"
            class="flex items-center justify-between gap-3 border border-gray-200 dark:border-gray-700 rounded-lg p-3"
          >
            <div class="min-w-0">
              <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
                {{ schedule.restaurant_name }} · {{ formatScheduleTime(schedule.open_at) }}
              </p>
              <div class="mt-1 flex flex-wrap gap-1">
                <span
                  v-for="day in scheduleWeekdays(schedule.weekdays)"
                  :key="day.value"
                  class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-300"
                >{{ day.label }}</span>
              </div>
            </div>
            <div class="flex items-center gap-2 shrink-0">
              <button
                type="button"
                role="switch"
                :aria-checked="schedule.is_active"
                :disabled="togglingSchedule === schedule.id"
                @click="toggleSchedule(schedule)"
                class="relative inline-flex h-5 w-9 items-center rounded-full transition-colors disabled:opacity-50"
                :class="schedule.is_active ? 'bg-indigo-600' : 'bg-gray-300 dark:bg-gray-600'"
                :title="schedule.is_active ? 'Active — click to pause' : 'Paused — click to activate'"
              >
                <span
                  class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform"
                  :class="schedule.is_active ? 'translate-x-4' : 'translate-x-1'"
                />
              </button>
              <button
                type="button"
                @click="deleteSchedule(schedule)"
                class="text-gray-400 hover:text-red-600 dark:hover:text-red-400 px-1"
                title="Delete schedule"
                aria-label="Delete schedule"
              >✕</button>
            </div>
          </div>
        </div>

        <!-- New schedule (collapsed by default) -->
        <div class="mt-4 pt-3 border-t border-gray-200 dark:border-gray-700">
          <button
            type="button"
            @click="showScheduleForm = !showScheduleForm"
            class="text-xs text-indigo-600 dark:text-indigo-400 hover:underline"
          >
            {{ showScheduleForm ? 'Hide new schedule ▲' : '+ New schedule ▼' }}
          </button>
          <form v-if="showScheduleForm" @submit.prevent="createSchedule" class="mt-3 space-y-3">
            <div>
              <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Restaurant</label>
              <select
                v-model="newSchedule.restaurant"
                @change="onScheduleRestaurantChange"
                required
                class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
              >
                <option value="" disabled>Select a restaurant</option>
                <option v-for="r in ordersStore.restaurants" :key="r.id" :value="r.id">{{ r.name }}</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Menu (optional)</label>
              <select
                v-model="newSchedule.menu"
                :disabled="!newSchedule.restaurant || scheduleMenus.length === 0"
                class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white disabled:bg-gray-100 dark:disabled:bg-gray-600 disabled:cursor-not-allowed"
              >
                <option :value="null">{{ scheduleMenus.length === 0 ? 'No menus available' : 'No specific menu' }}</option>
                <option v-for="menu in scheduleMenus" :key="menu.id" :value="menu.id">{{ menu.name }}</option>
              </select>
            </div>
            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Opens at</label>
                <input
                  v-model="newSchedule.open_at"
                  type="time"
                  required
                  class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Cutoff after (min)</label>
                <input
                  v-model.number="newSchedule.cutoff_after_minutes"
                  type="number"
                  min="0"
                  class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
                />
              </div>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Days</label>
              <div class="mt-1 flex flex-wrap gap-1.5">
                <button
                  v-for="day in weekdayOptions"
                  :key="day.value"
                  type="button"
                  @click="toggleWeekday(day.value)"
                  class="text-xs font-medium px-2 py-1 rounded-full border transition-colors"
                  :class="newSchedule.weekdays.includes(day.value)
                    ? 'bg-indigo-600 border-indigo-600 text-white'
                    : 'bg-white dark:bg-gray-700 border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:border-indigo-400'"
                >
                  {{ day.label }}
                </button>
              </div>
            </div>
            <div class="grid grid-cols-3 gap-2">
              <div>
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Delivery</label>
                <input v-model.number="newSchedule.delivery_fee" type="number" min="0" step="0.01"
                  class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Tip</label>
                <input v-model.number="newSchedule.tip" type="number" min="0" step="0.01"
                  class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Service</label>
                <input v-model.number="newSchedule.service_fee" type="number" min="0" step="0.01"
                  class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
              </div>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Fee Split</label>
              <select
                v-model="newSchedule.fee_split_rule"
                class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
              >
                <option value="equal">Equal</option>
                <option value="proportional">Proportional</option>
                <option value="collector_pays">Collector Pays</option>
              </select>
            </div>
            <BaseButton type="submit" block :loading="creatingSchedule">
              Schedule it
            </BaseButton>
          </form>
        </div>
      </BaseCard>

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
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
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
                    'text-indigo-600 dark:text-indigo-400': order.status === 'ORDERED',
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
import BaseButton from '../components/ui/BaseButton.vue'
import BaseCard from '../components/ui/BaseCard.vue'

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

// --- Scheduled (recurring) orders ---
// Weekday values follow the backend csv convention: 0=Mon … 6=Sun
const weekdayOptions = [
  { value: 0, label: 'Mon' },
  { value: 1, label: 'Tue' },
  { value: 2, label: 'Wed' },
  { value: 3, label: 'Thu' },
  { value: 4, label: 'Fri' },
  { value: 5, label: 'Sat' },
  { value: 6, label: 'Sun' },
]

// Default: Sun–Thu (the local work week), opening at 11:00 with a 45-min cutoff
const defaultSchedule = () => ({
  restaurant: '',
  menu: null,
  open_at: '11:00',
  weekdays: [6, 0, 1, 2, 3],
  cutoff_after_minutes: 45,
  delivery_fee: 30,
  tip: 30,
  service_fee: 0,
  fee_split_rule: 'equal',
})

const schedules = computed(() => ordersStore.recurringOrders)
const loadingSchedules = ref(false)
const showScheduleForm = ref(false)
const creatingSchedule = ref(false)
const togglingSchedule = ref(null)
const scheduleMenus = ref([])
const newSchedule = ref(defaultSchedule())

function formatScheduleTime(openAt) {
  return String(openAt || '').slice(0, 5) // "11:00:00" → "11:00"
}

function scheduleWeekdays(csv) {
  const selected = new Set(String(csv ?? '').split(',').filter(v => v !== '').map(Number))
  return weekdayOptions.filter(day => selected.has(day.value))
}

function toggleWeekday(value) {
  const index = newSchedule.value.weekdays.indexOf(value)
  if (index === -1) newSchedule.value.weekdays.push(value)
  else newSchedule.value.weekdays.splice(index, 1)
}

async function fetchSchedules() {
  loadingSchedules.value = true
  await ordersStore.fetchRecurringOrders()
  loadingSchedules.value = false
}

async function onScheduleRestaurantChange() {
  newSchedule.value.menu = null
  scheduleMenus.value = []
  if (!newSchedule.value.restaurant) return
  const result = await ordersStore.fetchMenus(parseInt(newSchedule.value.restaurant))
  if (result.success) {
    scheduleMenus.value = result.data.filter(menu => menu.is_active)
  }
}

async function createSchedule() {
  if (!newSchedule.value.restaurant) {
    toast.warning('Please select a restaurant')
    return
  }
  if (newSchedule.value.weekdays.length === 0) {
    toast.warning('Pick at least one day')
    return
  }

  creatingSchedule.value = true
  const openAt = newSchedule.value.open_at
  const result = await ordersStore.createRecurringOrder({
    restaurant: parseInt(newSchedule.value.restaurant),
    menu: newSchedule.value.menu ? parseInt(newSchedule.value.menu) : null,
    open_at: openAt.length === 5 ? `${openAt}:00` : openAt,
    weekdays: newSchedule.value.weekdays.join(','),
    cutoff_after_minutes: newSchedule.value.cutoff_after_minutes || null,
    delivery_fee: newSchedule.value.delivery_fee,
    tip: newSchedule.value.tip,
    service_fee: newSchedule.value.service_fee,
    fee_split_rule: newSchedule.value.fee_split_rule,
  })

  if (result.success) {
    toast.success('Scheduled — it will open automatically')
    newSchedule.value = defaultSchedule()
    scheduleMenus.value = []
    showScheduleForm.value = false
    await fetchSchedules()
  } else {
    toast.error('Failed to create schedule: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  creatingSchedule.value = false
}

async function toggleSchedule(schedule) {
  togglingSchedule.value = schedule.id
  const result = await ordersStore.updateRecurringOrder(schedule.id, { is_active: !schedule.is_active })
  if (!result.success) {
    toast.error('Failed to update schedule: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  togglingSchedule.value = null
}

async function deleteSchedule(schedule) {
  if (!(await $confirm(`Delete the ${schedule.restaurant_name} schedule?`, 'Delete Schedule'))) return
  const result = await ordersStore.deleteRecurringOrder(schedule.id)
  if (result.success) {
    toast.success('Schedule deleted')
  } else {
    toast.error('Failed to delete schedule: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
}

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
    fetchSchedules(),
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

