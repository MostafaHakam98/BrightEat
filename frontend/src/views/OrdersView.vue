<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-8 flex justify-between items-center">
      <h1 class="text-3xl font-bold text-gray-900">All Orders</h1>
      <div class="flex space-x-2">
        <button
          v-for="status in ['', 'OPEN', 'LOCKED', 'ORDERED', 'CLOSED']"
          :key="status"
          @click="filterStatus = status; fetchOrders()"
          :class="[
            'px-4 py-2 rounded-md',
            filterStatus === status
              ? 'bg-blue-600 text-white'
              : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
          ]"
        >
          {{ status || 'All' }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="text-center py-8">Loading...</div>
    <div v-else-if="ordersStore.orders.length === 0" class="text-center py-8 text-gray-500">
      No orders found
    </div>
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div
        v-for="order in ordersStore.orders"
        :key="order.id"
        class="bg-white rounded-lg shadow p-6 hover:shadow-lg transition"
      >
        <h3 class="text-lg font-semibold mb-2">{{ order.restaurant_name }}</h3>
        <p class="text-sm text-gray-600 mb-1">Code: <span class="font-mono">{{ order.code }}</span></p>
        <p class="text-sm text-gray-600 mb-1">Collector: {{ order.collector_name }}</p>
        <p class="text-sm text-gray-600 mb-1">Status: 
          <span :class="{
            'text-green-600': order.status === 'OPEN',
            'text-yellow-600': order.status === 'LOCKED',
            'text-blue-600': order.status === 'ORDERED',
            'text-gray-600': order.status === 'CLOSED',
          }">
            {{ order.status }}
          </span>
        </p>
        <p class="text-sm text-gray-600 mb-4">Total: {{ order.total_cost.toFixed(2) }} EGP</p>
        <router-link
          :to="`/orders/${order.code}`"
          class="block w-full text-center bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
        >
          View Details
        </router-link>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useOrdersStore } from '../stores/orders'

const ordersStore = useOrdersStore()
const filterStatus = ref('')
const loading = ref(false)

onMounted(() => {
  fetchOrders()
})

async function fetchOrders() {
  loading.value = true
  await ordersStore.fetchOrders(filterStatus.value || null)
  loading.value = false
}
</script>

