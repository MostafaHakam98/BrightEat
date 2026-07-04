<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900 px-4 py-12">
    <!-- Guest quick-join hero (no account needed) -->
    <div v-if="!authStore.isAuthenticated" class="w-full max-w-md">
      <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-xl overflow-hidden">
        <div class="bg-gradient-to-r from-blue-600 to-indigo-600 px-6 py-6 text-white text-center">
          <h1 class="text-2xl font-bold">Join the food order 🍽</h1>
          <p class="text-sm opacity-90 mt-2">
            Your team is ordering together on OrderQ. Type your name and you're in —
            no sign-up, no password.
          </p>
        </div>
        <form @submit.prevent="quickJoin" class="px-6 py-6 space-y-4">
          <div>
            <label for="quick-join-name" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Your name
            </label>
            <input
              id="quick-join-name"
              ref="nameInput"
              v-model="guestName"
              type="text"
              required
              autofocus
              autocomplete="name"
              placeholder="e.g. Sara"
              class="w-full px-3 py-2.5 border border-gray-300 dark:border-gray-600 rounded-lg dark:bg-gray-700 dark:text-white dark:placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>
          <p v-if="quickJoinError" class="text-sm text-red-600 dark:text-red-400">{{ quickJoinError }}</p>
          <BaseButton type="submit" block size="lg" :loading="quickJoining" :disabled="!guestName.trim()">
            Join in seconds
          </BaseButton>
          <p class="text-center text-xs text-gray-400 dark:text-gray-500">
            <router-link
              :to="`/login?next=/join/${routeCode}`"
              class="hover:text-indigo-600 dark:hover:text-indigo-400 underline"
            >
              Have an account? Sign in
            </router-link>
          </p>
        </form>
      </div>
    </div>

    <!-- Loading -->
    <div v-else-if="loading" class="text-center">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
      <p class="text-gray-600 dark:text-gray-400">Loading order...</p>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="text-center max-w-sm">
      <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-lg p-8">
        <div class="text-5xl mb-4">❌</div>
        <h2 class="text-xl font-bold text-gray-900 dark:text-white mb-2">Order Not Found</h2>
        <p class="text-gray-600 dark:text-gray-400 mb-6">{{ error }}</p>
        <router-link
          to="/"
          class="inline-block bg-indigo-600 text-white px-6 py-3 rounded-lg hover:bg-indigo-700 font-medium"
        >
          Go Home
        </router-link>
      </div>
    </div>

    <!-- Order preview card -->
    <div v-else-if="order" class="w-full max-w-md">
      <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-xl overflow-hidden">
        <!-- Header band -->
        <div class="bg-gradient-to-r from-blue-600 to-indigo-600 px-6 py-5 text-white">
          <p class="text-xs font-semibold uppercase tracking-wider opacity-80 mb-1">You've been invited to join</p>
          <h1 class="text-2xl font-bold">{{ order.restaurant_name }}</h1>
          <p class="text-sm opacity-80 mt-1">Order <span class="font-mono font-semibold">{{ order.code }}</span></p>
        </div>

        <div class="px-6 py-5 space-y-4">
          <!-- Meta info -->
          <div class="grid grid-cols-2 gap-4 text-sm">
            <div>
              <p class="text-gray-500 dark:text-gray-400 text-xs uppercase tracking-wide font-medium">Collector</p>
              <p class="font-semibold dark:text-white mt-0.5">{{ order.collector_name }}</p>
            </div>
            <div>
              <p class="text-gray-500 dark:text-gray-400 text-xs uppercase tracking-wide font-medium">Status</p>
              <span :class="statusBadgeClass" class="inline-block text-xs font-semibold px-2 py-0.5 rounded-full mt-0.5">
                {{ order.status }}
              </span>
            </div>
            <div v-if="order.cutoff_time">
              <p class="text-gray-500 dark:text-gray-400 text-xs uppercase tracking-wide font-medium">Cutoff</p>
              <p class="font-semibold dark:text-white mt-0.5 text-xs">{{ formatCutoff(order.cutoff_time) }}</p>
            </div>
            <div>
              <p class="text-gray-500 dark:text-gray-400 text-xs uppercase tracking-wide font-medium">Participants</p>
              <p class="font-semibold dark:text-white mt-0.5">{{ order.participants?.length ?? 0 }}</p>
            </div>
          </div>

          <!-- Items summary -->
          <div v-if="order.items?.length" class="border-t border-gray-100 dark:border-gray-700 pt-4">
            <p class="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-2">
              Items so far ({{ order.items.length }})
            </p>
            <ul class="space-y-1 max-h-32 overflow-y-auto text-sm text-gray-700 dark:text-gray-300">
              <li
                v-for="item in order.items.slice(0, 6)"
                :key="item.id"
                class="flex justify-between"
              >
                <span class="truncate mr-2">{{ item.item_name }}</span>
                <span class="shrink-0 text-gray-500 dark:text-gray-400">{{ item.user_name }}</span>
              </li>
              <li v-if="order.items.length > 6" class="text-gray-400 dark:text-gray-500 text-xs">
                + {{ order.items.length - 6 }} more…
              </li>
            </ul>
          </div>
          <div v-else class="border-t border-gray-100 dark:border-gray-700 pt-4 text-sm text-gray-500 dark:text-gray-400">
            No items added yet — be the first!
          </div>

          <!-- Closed warning -->
          <div v-if="order.status === 'CLOSED'" class="bg-gray-50 dark:bg-gray-700/50 border border-gray-200 dark:border-gray-600 rounded-lg p-3 text-sm text-gray-600 dark:text-gray-300">
            This order is closed. You can view the summary but cannot add items.
          </div>
          <div v-else-if="order.status !== 'OPEN'" class="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-700 rounded-lg p-3 text-sm text-yellow-700 dark:text-yellow-300">
            This order is {{ order.status.toLowerCase() }}. You can view it but may not be able to add items.
          </div>

          <!-- CTA button -->
          <button
            @click="joinOrder"
            class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-3 rounded-xl transition-colors"
          >
            {{ order.status === 'OPEN' ? '→ Join & Add Items' : '→ View Order' }}
          </button>

          <p class="text-center text-xs text-gray-400 dark:text-gray-500">
            You'll be taken to the full order page
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useOrdersStore } from '../stores/orders'
import { useAuthStore } from '../stores/auth'
import { useToast } from '../composables/useToast'
import BaseButton from '../components/ui/BaseButton.vue'

const route = useRoute()
const router = useRouter()
const ordersStore = useOrdersStore()
const authStore = useAuthStore()
const toast = useToast()

const loading = ref(true)
const error = ref(null)
const order = ref(null)

const routeCode = computed(() => (route.params.code || '').toUpperCase())

// Guest quick-join (unauthenticated) state
const nameInput = ref(null)
const guestName = ref('')
const quickJoining = ref(false)
const quickJoinError = ref(null)

async function quickJoin() {
  const name = guestName.value.trim()
  if (!name || quickJoining.value) return
  quickJoining.value = true
  quickJoinError.value = null
  const result = await authStore.quickJoin(name, routeCode.value)
  quickJoining.value = false
  if (result.success) {
    // isAuthenticated just flipped — keep the spinner up while we navigate
    loading.value = true
    router.push(`/orders/${result.order_code}`)
  } else {
    quickJoinError.value = result.error
    toast.error(result.error)
  }
}

const statusBadgeClass = computed(() => {
  const s = order.value?.status
  if (s === 'OPEN') return 'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300'
  if (s === 'LOCKED') return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-300'
  if (s === 'ORDERED') return 'bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300'
  return 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
})

function formatCutoff(dt) {
  return new Date(dt).toLocaleString('en-EG', { dateStyle: 'medium', timeStyle: 'short' })
}

const joining = ref(false)

async function joinOrder() {
  // Actually register participation (roster + collector notification) before
  // navigating — previously "join" was only a redirect and you stayed
  // invisible until you added an item.
  if (order.value.status === 'OPEN' && !joining.value) {
    joining.value = true
    await ordersStore.joinOrder(order.value.id)
    joining.value = false
  }
  router.push(`/orders/${order.value.code}`)
}

onMounted(async () => {
  // Guests can't fetch the order preview — show the quick-join hero instead
  if (!authStore.isAuthenticated) {
    loading.value = false
    await nextTick()
    nameInput.value?.focus()
    return
  }

  const code = routeCode.value
  if (!code) {
    error.value = 'No order code provided.'
    loading.value = false
    return
  }

  const result = await ordersStore.fetchOrderByCode(code)
  if (result.success) {
    order.value = result.data
  } else {
    error.value = result.error?.detail || 'Order not found.'
  }
  loading.value = false
})
</script>
