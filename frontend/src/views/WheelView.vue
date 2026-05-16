<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-6">
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Restaurant Wheel</h1>
      <p class="mt-2 text-gray-600 dark:text-gray-400">Spin to pick your lunch spot!</p>
    </div>

    <div v-if="loading" class="text-center py-16 text-gray-500 dark:text-gray-400">
      Loading restaurants...
    </div>

    <div v-else class="flex flex-col lg:flex-row gap-8">
      <!-- Left panel: restaurant list -->
      <aside class="w-full lg:w-72 flex-shrink-0">
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-4">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-3">Restaurants</h2>

          <div class="flex gap-2 mb-4">
            <button
              @click="selectAll"
              class="flex-1 text-sm px-3 py-1.5 rounded-md bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600 transition"
            >
              Select All
            </button>
            <button
              @click="deselectAll"
              class="flex-1 text-sm px-3 py-1.5 rounded-md bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600 transition"
            >
              Deselect All
            </button>
          </div>

          <div class="space-y-2 max-h-96 overflow-y-auto pr-1">
            <label
              v-for="restaurant in ordersStore.restaurants"
              :key="restaurant.id"
              class="flex items-center gap-3 p-2 rounded-md cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700 transition"
            >
              <input
                type="checkbox"
                :value="restaurant.id"
                v-model="selectedIds"
                :disabled="spinning"
                class="h-4 w-4 rounded border-gray-300 dark:border-gray-600 text-blue-600 focus:ring-blue-500 cursor-pointer disabled:cursor-not-allowed"
              />
              <span class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300 select-none">
                <span
                  class="inline-block w-3 h-3 rounded-full flex-shrink-0"
                  :style="{ backgroundColor: colorForRestaurant(restaurant.id) }"
                ></span>
                {{ restaurant.name }}
              </span>
            </label>
          </div>

          <p class="mt-3 text-xs text-gray-500 dark:text-gray-400">
            {{ selectedIds.length }} / {{ ordersStore.restaurants.length }} selected
          </p>
        </div>
      </aside>

      <!-- Center: wheel + controls -->
      <div class="flex-1 flex flex-col items-center gap-6">
        <!-- Wheel container -->
        <div class="relative flex items-center justify-center" style="width: 360px; height: 360px;">
          <!-- Pointer arrow at top -->
          <div class="absolute -top-5 z-10 flex flex-col items-center pointer-events-none">
            <svg width="28" height="36" viewBox="0 0 28 36" fill="none" xmlns="http://www.w3.org/2000/svg">
              <polygon points="14,36 0,4 28,4" fill="#EF4444" />
              <polygon points="14,36 0,4 28,4" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round" />
            </svg>
          </div>

          <!-- No restaurants selected placeholder -->
          <div
            v-if="selectedRestaurants.length === 0"
            class="w-full h-full rounded-full border-4 border-dashed border-gray-300 dark:border-gray-600 flex items-center justify-center"
          >
            <p class="text-sm text-gray-400 dark:text-gray-500 text-center px-8">
              Select at least 2 restaurants to spin
            </p>
          </div>

          <!-- The wheel -->
          <div
            v-else
            class="wheel"
            :style="wheelStyle"
          >
            <!-- Segment labels -->
            <div
              v-for="(restaurant, index) in selectedRestaurants"
              :key="restaurant.id"
              class="segment-label"
              :style="labelStyle(index)"
            >
              <span class="label-text">{{ restaurant.name }}</span>
            </div>
          </div>

          <!-- Center cap -->
          <div
            v-if="selectedRestaurants.length > 0"
            class="absolute w-10 h-10 rounded-full bg-white dark:bg-gray-800 border-4 border-gray-200 dark:border-gray-600 shadow z-10"
          ></div>
        </div>

        <!-- Spin button -->
        <button
          @click="spin"
          :disabled="spinning || selectedRestaurants.length < 2"
          class="px-10 py-3 rounded-full text-lg font-bold text-white shadow-lg transition
                 bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600
                 disabled:opacity-40 disabled:cursor-not-allowed"
        >
          {{ spinning ? 'Spinning...' : 'Spin!' }}
        </button>

        <!-- Result card -->
        <transition name="fade">
          <div
            v-if="winner"
            class="w-full max-w-sm bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6 text-center"
          >
            <p class="text-2xl font-bold text-gray-900 dark:text-white mb-1">
              🎉 {{ winner.name }}!
            </p>
            <p class="text-sm text-gray-500 dark:text-gray-400 mb-5">The wheel has spoken.</p>
            <div class="flex flex-col sm:flex-row gap-3 justify-center">
              <button
                @click="createOrder"
                class="px-6 py-2.5 rounded-md bg-green-600 hover:bg-green-700 dark:bg-green-500 dark:hover:bg-green-600 text-white font-semibold transition"
              >
                Create order &rarr;
              </button>
              <button
                @click="spinAgain"
                class="px-6 py-2.5 rounded-md bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 font-semibold transition"
              >
                Spin again
              </button>
            </div>
          </div>
        </transition>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useOrdersStore } from '../stores/orders'

const router = useRouter()
const ordersStore = useOrdersStore()

// ─── State ────────────────────────────────────────────────────────────────────

const loading = ref(false)
const selectedIds = ref([])
const spinning = ref(false)
const winner = ref(null)
const currentRotation = ref(0)   // cumulative degrees, never reset

// ─── Color palette ────────────────────────────────────────────────────────────

const COLORS = [
  '#3B82F6', // blue
  '#10B981', // emerald
  '#F59E0B', // amber
  '#EF4444', // red
  '#8B5CF6', // violet
  '#EC4899', // pink
  '#14B8A6', // teal
  '#F97316', // orange
]

// ─── Derived ──────────────────────────────────────────────────────────────────

const selectedRestaurants = computed(() =>
  ordersStore.restaurants.filter(r => selectedIds.value.includes(r.id))
)

function colorForRestaurant(id) {
  const allIds = ordersStore.restaurants.map(r => r.id)
  const idx = allIds.indexOf(id)
  return COLORS[idx % COLORS.length]
}

const conicGradient = computed(() => {
  const n = selectedRestaurants.value.length
  if (n === 0) return ''
  const step = 360 / n
  const stops = selectedRestaurants.value.map((r, i) => {
    const color = COLORS[i % COLORS.length]
    const start = i * step
    const end = (i + 1) * step
    return `${color} ${start}deg ${end}deg`
  })
  return `conic-gradient(${stops.join(', ')})`
})

const wheelStyle = computed(() => ({
  background: conicGradient.value,
  transform: `rotate(${currentRotation.value}deg)`,
  transition: spinning.value
    ? 'transform 4s cubic-bezier(0.17, 0.67, 0.12, 0.99)'
    : 'none',
}))

function labelStyle(index) {
  const n = selectedRestaurants.value.length
  const step = 360 / n
  // Rotate each label to the midpoint of its segment
  const mid = index * step + step / 2
  return {
    transform: `rotate(${mid}deg)`,
  }
}

// ─── Lifecycle ────────────────────────────────────────────────────────────────

onMounted(async () => {
  if (ordersStore.restaurants.length === 0) {
    loading.value = true
    await ordersStore.fetchRestaurants()
    loading.value = false
  }
  // Default: select all
  selectedIds.value = ordersStore.restaurants.map(r => r.id)
})

// ─── Actions ──────────────────────────────────────────────────────────────────

function selectAll() {
  selectedIds.value = ordersStore.restaurants.map(r => r.id)
}

function deselectAll() {
  selectedIds.value = []
}

function spin() {
  if (spinning.value || selectedRestaurants.value.length < 2) return

  winner.value = null
  spinning.value = true

  const randomOffset = Math.random() * 360
  const totalAdd = 5 * 360 + randomOffset
  currentRotation.value += totalAdd

  setTimeout(() => {
    spinning.value = false
    resolveWinner()
  }, 4000)
}

function resolveWinner() {
  const n = selectedRestaurants.value.length
  const step = 360 / n

  // The pointer is at the top (0deg = 12 o'clock in CSS conic-gradient terms,
  // but conic-gradient starts at 3 o'clock and goes clockwise, so we offset by 90deg)
  // The wheel rotates clockwise. To find which segment is under the top pointer,
  // we need to know the effective angle at the top after rotation.
  //
  // Conic-gradient zero-point is at 3 o'clock (90deg from top).
  // After rotating by `currentRotation` degrees clockwise, the part of the wheel
  // that was originally at angle A is now at screen position (A + currentRotation).
  // The top pointer sits at screen position 270deg from conic start (i.e. 12 o'clock = 270deg in conic space).
  // So: A + currentRotation ≡ 270 (mod 360)  =>  A ≡ 270 - currentRotation (mod 360)
  //
  // Segment i occupies [i*step, (i+1)*step). We check which segment contains A.

  const rawAngle = (270 - currentRotation.value % 360 + 360 * 10) % 360
  const segmentIndex = Math.floor(rawAngle / step) % n
  winner.value = selectedRestaurants.value[segmentIndex]
}

function spinAgain() {
  winner.value = null
}

function createOrder() {
  if (!winner.value) return
  router.push({ path: '/', query: { restaurant: winner.value.id } })
}
</script>

<style scoped>
.wheel {
  width: 100%;
  height: 100%;
  border-radius: 50%;
  position: relative;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.18);
  will-change: transform;
}

/* Each label is positioned in the center and rotated to its segment midpoint */
.segment-label {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 50%;
  height: 0;
  transform-origin: left center;
  display: flex;
  align-items: center;
  pointer-events: none;
}

.label-text {
  margin-left: 14px;
  max-width: 120px;
  font-size: 11px;
  font-weight: 700;
  color: #fff;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.6);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Fade transition for result card */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.4s ease, transform 0.4s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(10px);
}
</style>
