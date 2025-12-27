<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <h1 class="text-3xl font-bold text-gray-900 dark:text-white mb-8">Monthly Reports</h1>

    <div v-if="authStore.isManager" class="mb-6">
      <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Select User</label>
      <select
        v-model="selectedUserId"
        @change="fetchReport"
        class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
      >
        <option :value="authStore.user?.id">Me</option>
        <option v-for="user in users" :key="user.id" :value="user.id">
          {{ user.username }}
        </option>
      </select>
    </div>

    <div v-if="loading" class="text-center py-8 text-gray-600 dark:text-gray-400">Loading...</div>
    <div v-else-if="report" class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
      <h2 class="text-xl font-semibold mb-6 dark:text-white">
        Report for {{ report.user.username }} - {{ report.month }}
      </h2>
      
      <!-- Main Metrics Row -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div 
          @click="showCalculation('total_spend')"
          class="bg-blue-50 dark:bg-blue-900/30 rounded-lg p-4 cursor-pointer hover:bg-blue-100 dark:hover:bg-blue-900/50 transition-colors"
        >
          <p class="text-sm text-gray-600 dark:text-gray-400">Total Spend</p>
          <p class="text-2xl font-bold text-blue-600 dark:text-blue-400">{{ report.total_spend.toFixed(2) }} EGP</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Click for details</p>
        </div>
        <div 
          @click="showCalculation('collector_count')"
          class="bg-green-50 dark:bg-green-900/30 rounded-lg p-4 cursor-pointer hover:bg-green-100 dark:hover:bg-green-900/50 transition-colors"
        >
          <p class="text-sm text-gray-600 dark:text-gray-400">Times as Collector</p>
          <p class="text-2xl font-bold text-green-600 dark:text-green-400">{{ report.collector_count }}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Click for details</p>
        </div>
        <div 
          @click="showCalculation('unpaid_count')"
          class="bg-red-50 dark:bg-red-900/30 rounded-lg p-4 cursor-pointer hover:bg-red-100 dark:hover:bg-red-900/50 transition-colors"
        >
          <p class="text-sm text-gray-600 dark:text-gray-400">Unpaid Incidents</p>
          <p class="text-2xl font-bold text-red-600 dark:text-red-400">{{ report.unpaid_count }}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Click for details</p>
        </div>
      </div>

      <!-- Secondary Metrics Row -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div 
          @click="showCalculation('total_collected')"
          class="bg-purple-50 dark:bg-purple-900/30 rounded-lg p-4 cursor-pointer hover:bg-purple-100 dark:hover:bg-purple-900/50 transition-colors"
        >
          <p class="text-sm text-gray-600 dark:text-gray-400">Total Collected</p>
          <p class="text-2xl font-bold text-purple-600 dark:text-purple-400">{{ report.total_collected.toFixed(2) }} EGP</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">When you were collector • Click for details</p>
        </div>
        <div 
          @click="showCalculation('total_orders_participated')"
          class="bg-indigo-50 dark:bg-indigo-900/30 rounded-lg p-4 cursor-pointer hover:bg-indigo-100 dark:hover:bg-indigo-900/50 transition-colors"
        >
          <p class="text-sm text-gray-600 dark:text-gray-400">Orders Participated</p>
          <p class="text-2xl font-bold text-indigo-600 dark:text-indigo-400">{{ report.total_orders_participated }}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Click for details</p>
        </div>
        <div 
          @click="showCalculation('avg_order_value')"
          class="bg-teal-50 dark:bg-teal-900/30 rounded-lg p-4 cursor-pointer hover:bg-teal-100 dark:hover:bg-teal-900/50 transition-colors"
        >
          <p class="text-sm text-gray-600 dark:text-gray-400">Avg Order Value</p>
          <p class="text-2xl font-bold text-teal-600 dark:text-teal-400">{{ report.avg_order_value.toFixed(2) }} EGP</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Click for details</p>
        </div>
      </div>

      <!-- Third Metrics Row -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div 
          @click="showCalculation('total_fees_paid')"
          class="bg-orange-50 dark:bg-orange-900/30 rounded-lg p-4 cursor-pointer hover:bg-orange-100 dark:hover:bg-orange-900/50 transition-colors"
        >
          <p class="text-sm text-gray-600 dark:text-gray-400">Total Fees Paid</p>
          <p class="text-2xl font-bold text-orange-600 dark:text-orange-400">{{ report.total_fees_paid.toFixed(2) }} EGP</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Delivery, tip, service fees • Click for details</p>
        </div>
        <div 
          @click="showCalculation('payment_completion_rate')"
          class="bg-cyan-50 dark:bg-cyan-900/30 rounded-lg p-4 cursor-pointer hover:bg-cyan-100 dark:hover:bg-cyan-900/50 transition-colors"
        >
          <p class="text-sm text-gray-600 dark:text-gray-400">Payment Completion</p>
          <p class="text-2xl font-bold text-cyan-600 dark:text-cyan-400">{{ report.payment_completion_rate.toFixed(1) }}%</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Click for details</p>
        </div>
        <div 
          @click="showCalculation('total_pending')"
          class="bg-pink-50 dark:bg-pink-900/30 rounded-lg p-4 cursor-pointer hover:bg-pink-100 dark:hover:bg-pink-900/50 transition-colors"
        >
          <p class="text-sm text-gray-600 dark:text-gray-400">Total Pending</p>
          <p class="text-2xl font-bold text-pink-600 dark:text-pink-400">{{ report.total_pending.toFixed(2) }} EGP</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Amount you owe • Click for details</p>
        </div>
      </div>

      <!-- Fourth Metrics Row -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div 
          @click="showCalculation('total_owed_to_user')"
          class="bg-yellow-50 dark:bg-yellow-900/30 rounded-lg p-4 cursor-pointer hover:bg-yellow-100 dark:hover:bg-yellow-900/50 transition-colors"
        >
          <p class="text-sm text-gray-600 dark:text-gray-400">Total Owed to You</p>
          <p class="text-2xl font-bold text-yellow-600 dark:text-yellow-400">{{ report.total_owed_to_user.toFixed(2) }} EGP</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">When you were collector • Click for details</p>
        </div>
        <div 
          @click="showCalculation('most_ordered_restaurant')"
          class="bg-emerald-50 dark:bg-emerald-900/30 rounded-lg p-4 cursor-pointer hover:bg-emerald-100 dark:hover:bg-emerald-900/50 transition-colors"
        >
          <p class="text-sm text-gray-600 dark:text-gray-400">Most Ordered Restaurant</p>
          <p class="text-xl font-bold text-emerald-600 dark:text-emerald-400">
            {{ report.most_ordered_restaurant || 'N/A' }}
          </p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            {{ report.most_ordered_restaurant_count }} order{{ report.most_ordered_restaurant_count !== 1 ? 's' : '' }} • Click for details
          </p>
        </div>
      </div>
    </div>

    <!-- Calculation Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeModal">
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div class="p-6">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-xl font-bold text-gray-900 dark:text-white">{{ calculationTitle }}</h3>
            <button 
              @click="closeModal"
              class="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <div class="space-y-4">
            <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
              <p class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">Calculation:</p>
              <p class="text-gray-900 dark:text-white whitespace-pre-line">{{ calculationFormula }}</p>
            </div>
            <div class="bg-blue-50 dark:bg-blue-900/30 rounded-lg p-4">
              <p class="text-sm font-semibold text-blue-700 dark:text-blue-300 mb-2">Explanation:</p>
              <p class="text-gray-700 dark:text-gray-300">{{ calculationExplanation }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useOrdersStore } from '../stores/orders'
import { useAuthStore } from '../stores/auth'
import api from '../api'

const ordersStore = useOrdersStore()
const authStore = useAuthStore()
const loading = ref(false)
const report = ref(null)
const selectedUserId = ref(authStore.user?.id)
const users = ref([])
const showModal = ref(false)
const calculationTitle = ref('')
const calculationFormula = ref('')
const calculationExplanation = ref('')

const calculations = {
  total_spend: {
    title: 'Total Spend Calculation',
    formula: 'Sum of all payment amounts where you are the payer\n\nTotal Spend = Σ(Payment.amount)\nfor all payments where:\n- Payment.user = You\n- Payment.order.created_at >= Start of Month',
    explanation: 'This is the total amount you have spent this month across all orders where you participated. It includes both item costs and your share of fees (delivery, tip, service fees) based on the fee split rule for each order.'
  },
  collector_count: {
    title: 'Times as Collector Calculation',
    formula: 'Count of orders where you are the collector\n\nCollector Count = COUNT(CollectionOrder)\nwhere:\n- CollectionOrder.collector = You\n- CollectionOrder.created_at >= Start of Month',
    explanation: 'This shows how many times you were the collector (person who places and collects the order) this month. As a collector, your own payment is automatically marked as paid.'
  },
  unpaid_count: {
    title: 'Unpaid Incidents Calculation',
    formula: 'Count of unpaid payments\n\nUnpaid Count = COUNT(Payment)\nwhere:\n- Payment.user = You\n- Payment.is_paid = False\n- Payment.order.status IN (LOCKED, ORDERED, CLOSED)\n- Payment.order.created_at >= Start of Month',
    explanation: 'This is the number of payments you still need to make. These are payments for orders that have been locked, ordered, or closed but you haven\'t marked as paid yet.'
  },
  total_collected: {
    title: 'Total Collected Calculation',
    formula: 'Sum of payments from others when you were collector\n\nTotal Collected = Σ(Payment.amount)\nfor all payments where:\n- Payment.order.collector = You\n- Payment.user ≠ You\n- Payment.order.created_at >= Start of Month',
    explanation: 'This is the total amount you collected from other participants when you were the collector. It represents the money others paid you for orders you collected.'
  },
  total_orders_participated: {
    title: 'Orders Participated Calculation',
    formula: 'Count of distinct orders where you have items\n\nOrders Participated = COUNT(DISTINCT CollectionOrder)\nwhere:\n- OrderItem.user = You\n- OrderItem.order.created_at >= Start of Month',
    explanation: 'This is the total number of unique orders you participated in this month (by adding items). It counts each order only once, even if you added multiple items to it.'
  },
  avg_order_value: {
    title: 'Average Order Value Calculation',
    formula: 'Average total cost of orders you participated in\n\nAvg Order Value = Σ(Order.total_cost) / Orders Participated\n\nWhere Order.total_cost = Items Cost + Delivery Fee + Tip + Service Fee',
    explanation: 'This is the average total cost (including all fees) of orders you participated in. It gives you an idea of the typical order size you\'re involved in.'
  },
  total_fees_paid: {
    title: 'Total Fees Paid Calculation',
    formula: 'Sum of fees (delivery, tip, service) you paid\n\nTotal Fees Paid = Total Spend - Total Item Costs\n\nWhere:\n- Total Spend = Sum of all your payments\n- Total Item Costs = Sum of your order items',
    explanation: 'This is the total amount you paid in fees (delivery, tip, and service fees) this month. It\'s calculated by subtracting your item costs from your total spend.'
  },
  payment_completion_rate: {
    title: 'Payment Completion Rate Calculation',
    formula: 'Percentage of payments marked as paid\n\nPayment Completion Rate = (Paid Payments / Total Payments) × 100\n\nWhere:\n- Paid Payments = COUNT(Payment WHERE is_paid = True)\n- Total Payments = COUNT(Payment WHERE order.status IN (LOCKED, ORDERED, CLOSED))',
    explanation: 'This shows what percentage of your payments you have marked as paid. A rate of 100% means you\'ve paid for all your orders this month.'
  },
  total_pending: {
    title: 'Total Pending Calculation',
    formula: 'Sum of unpaid payment amounts\n\nTotal Pending = Σ(Payment.amount)\nwhere:\n- Payment.user = You\n- Payment.is_paid = False\n- Payment.order.status IN (LOCKED, ORDERED, CLOSED)\n- Payment.order.created_at >= Start of Month',
    explanation: 'This is the total amount of money you still owe for orders this month. It\'s the sum of all unpaid payment amounts.'
  },
  total_owed_to_user: {
    title: 'Total Owed to You Calculation',
    formula: 'Sum of unpaid payments from others when you were collector\n\nTotal Owed to You = Σ(Payment.amount)\nwhere:\n- Payment.order.collector = You\n- Payment.user ≠ You\n- Payment.is_paid = False\n- Payment.order.status IN (LOCKED, ORDERED, CLOSED)\n- Payment.order.created_at >= Start of Month',
    explanation: 'This is the total amount others owe you for orders where you were the collector. These are payments that haven\'t been marked as paid yet.'
  },
  most_ordered_restaurant: {
    title: 'Most Ordered Restaurant Calculation',
    formula: 'Restaurant with the most orders you participated in\n\nMost Ordered = Restaurant with MAX(COUNT(DISTINCT Order))\nwhere:\n- OrderItem.user = You\n- Order.created_at >= Start of Month\n\nGrouped by Restaurant',
    explanation: 'This shows which restaurant you ordered from most frequently this month. It counts the number of distinct orders (not items) for each restaurant.'
  }
}

function showCalculation(metric) {
  const calc = calculations[metric]
  if (calc) {
    calculationTitle.value = calc.title
    calculationFormula.value = calc.formula
    calculationExplanation.value = calc.explanation
    showModal.value = true
  }
}

function closeModal() {
  showModal.value = false
}

onMounted(async () => {
  if (authStore.isManager) {
    // Fetch all users for manager
    try {
      const response = await api.get('/users/')
      users.value = response.data.results || response.data
    } catch (error) {
      console.error('Failed to fetch users:', error)
    }
  }
  await fetchReport()
})

async function fetchReport() {
  if (!selectedUserId.value) return
  
  loading.value = true
  const result = await ordersStore.getMonthlyReport(selectedUserId.value)
  
  if (result.success) {
    report.value = result.data
  }
  loading.value = false
}
</script>

