<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-6">
      <h1 class="text-3xl font-bold text-gray-900">Pending Payments</h1>
      <p class="text-gray-600 mt-2">Orders where you owe money</p>
    </div>

    <div v-if="loading" class="text-center py-8">
      <p class="text-lg">Loading pending payments...</p>
    </div>
    <div v-else-if="pendingPayments.length === 0" class="text-center py-8 text-gray-500">
      <p class="text-lg">No pending payments</p>
      <p class="text-sm mt-2">You're all caught up! 🎉</p>
    </div>
    <div v-else class="space-y-4">
      <div
        v-for="payment in pendingPayments"
        :key="payment.payment_id"
        class="bg-white rounded-lg shadow p-6 border-l-4 border-yellow-500"
      >
        <div class="flex justify-between items-start">
          <div class="flex-1">
            <h3 class="text-lg font-semibold">{{ payment.restaurant_name }}</h3>
            <p class="text-sm text-gray-600 mt-1">Order Code: <span class="font-mono">{{ payment.order_code }}</span></p>
            <p class="text-sm text-gray-600">Collector: {{ payment.collector_name }}</p>
            <p class="text-sm text-gray-600">Status: 
              <span :class="{
                'text-yellow-600': payment.order_status === 'LOCKED',
                'text-blue-600': payment.order_status === 'ORDERED',
                'text-gray-600': payment.order_status === 'CLOSED',
              }">
                {{ payment.order_status }}
              </span>
            </p>
            <p class="text-xl font-bold text-gray-900 mt-2">{{ formatPrice(payment.amount) }} EGP</p>
          </div>
          <div class="flex flex-col space-y-2 ml-4">
            <router-link
              :to="`/orders/${payment.order_code}`"
              class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 text-sm"
            >
              View Order
            </router-link>
            <button
              @click="markAsPaid(payment.payment_id)"
              :disabled="markingPaid === payment.payment_id"
              class="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 disabled:opacity-50 text-sm"
            >
              {{ markingPaid === payment.payment_id ? 'Marking...' : 'Mark as Paid' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '../api'

const loading = ref(true)
const pendingPayments = ref([])
const markingPaid = ref(null)

function formatPrice(value) {
  if (value === null || value === undefined) return '0.00'
  const num = typeof value === 'string' ? parseFloat(value) : value
  return isNaN(num) ? '0.00' : num.toFixed(2)
}

async function fetchPendingPayments() {
  loading.value = true
  try {
    const response = await api.get('/orders/pending_payments/')
    pendingPayments.value = response.data
  } catch (error) {
    console.error('Failed to fetch pending payments:', error)
    alert('Failed to load pending payments: ' + (error.response?.data?.error || error.message))
  } finally {
    loading.value = false
  }
}

async function markAsPaid(paymentId) {
  if (!confirm('Mark this payment as paid?')) return
  
  markingPaid.value = paymentId
  try {
    await api.post(`/payments/${paymentId}/mark_paid/`)
    await fetchPendingPayments()
    alert('Payment marked as paid!')
  } catch (error) {
    alert('Failed to mark payment as paid: ' + (error.response?.data?.error || error.message))
  } finally {
    markingPaid.value = null
  }
}

onMounted(() => {
  fetchPendingPayments()
})
</script>

