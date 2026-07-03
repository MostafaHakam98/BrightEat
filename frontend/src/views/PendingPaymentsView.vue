<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-6">
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Pending Payments</h1>
      <p class="text-gray-600 dark:text-gray-400 mt-2">Manage payments you owe and payments owed to you</p>
    </div>

    <div v-if="loading" class="text-center py-8">
      <p class="text-lg text-gray-600 dark:text-gray-400">Loading pending payments...</p>
    </div>
    <div v-else>
      <!-- Payments I Owe Section -->
      <div class="mb-8">
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
          Payments I Owe
          <span class="text-sm font-normal text-gray-500 dark:text-gray-400 ml-2">
            ({{ paymentsIOwe.length }})
          </span>
        </h2>
        <div v-if="paymentsIOwe.length === 0" class="text-center py-8 text-gray-500 dark:text-gray-400 bg-white dark:bg-gray-800 rounded-lg">
          <p class="text-lg">No pending payments</p>
          <p class="text-sm mt-2">You're all caught up! 🎉</p>
        </div>
        <div v-else class="space-y-4">
          <div
            v-for="payment in paymentsIOwe"
            :key="`owe-${payment.payment_id}`"
            class="bg-white dark:bg-gray-800 rounded-lg shadow p-6 border-l-4 border-yellow-500 dark:border-yellow-400"
          >
            <div class="flex justify-between items-start">
              <div class="flex-1">
                <div class="flex items-center gap-2 flex-wrap">
                  <h3 class="text-lg font-semibold dark:text-white">{{ payment.restaurant_name }}</h3>
                  <BaseBadge v-if="payment.proof_status === 'claimed'" color="yellow">Awaiting confirmation</BaseBadge>
                  <BaseBadge v-else-if="payment.proof_status === 'rejected'" color="red">Proof rejected — try again</BaseBadge>
                </div>
                <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">Order Code: <span class="font-mono">{{ payment.order_code }}</span></p>
                <p class="text-sm text-gray-600 dark:text-gray-400">Collector: {{ payment.collector_name }}</p>
                <p class="text-sm text-gray-600 dark:text-gray-400">Status:
                  <span :class="{
                    'text-yellow-600 dark:text-yellow-400': payment.order_status === 'LOCKED',
                    'text-indigo-600 dark:text-indigo-400': payment.order_status === 'ORDERED',
                    'text-gray-600 dark:text-gray-400': payment.order_status === 'CLOSED',
                  }">
                    {{ payment.order_status }}
                  </span>
                </p>
                <p class="text-xl font-bold text-gray-900 dark:text-white mt-2">{{ formatPrice(payment.amount) }} EGP</p>

                <!-- Instapay payment section -->
                <div v-if="payment.collector_instapay_link || payment.collector_instapay_qr_code_url" class="mt-3 p-3 bg-blue-50 dark:bg-blue-900/30 rounded-lg border border-blue-200 dark:border-blue-700">
                  <p class="text-xs font-semibold text-blue-700 dark:text-blue-300 mb-2">Pay via Instapay</p>
                  <a
                    v-if="payment.collector_instapay_link"
                    :href="payment.collector_instapay_link"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="inline-flex items-center gap-1 text-sm text-indigo-600 dark:text-indigo-400 hover:underline font-medium"
                  >
                    Open Instapay Link ↗
                  </a>
                  <div v-if="payment.collector_instapay_qr_code_url" class="mt-2">
                    <button
                      @click="toggleQR(payment.payment_id)"
                      class="text-xs text-indigo-600 dark:text-indigo-400 hover:underline"
                    >
                      {{ expandedQR === payment.payment_id ? 'Hide QR Code' : 'Show QR Code' }}
                    </button>
                    <img
                      v-if="expandedQR === payment.payment_id"
                      :src="payment.collector_instapay_qr_code_url"
                      alt="Instapay QR Code"
                      class="mt-2 w-40 h-40 object-contain border border-gray-200 dark:border-gray-600 rounded"
                    />
                  </div>
                </div>
              </div>
              <div class="flex flex-col space-y-2 ml-4">
                <router-link
                  :to="`/orders/${payment.order_code}`"
                  class="bg-indigo-600 dark:bg-indigo-500 text-white px-4 py-2 rounded-md hover:bg-indigo-700 dark:hover:bg-indigo-600 text-sm text-center"
                >
                  View Order
                </router-link>
                <BaseButton
                  variant="secondary"
                  :loading="uploadingProof === payment.payment_id"
                  @click="triggerProofUpload(payment)"
                >
                  {{ payment.proof_status === 'rejected' ? 'Re-upload Proof' : 'Upload Proof' }}
                </BaseButton>
                <BaseButton
                  :variant="payment.proof_status === 'claimed' ? 'ghost' : 'success'"
                  :class="payment.proof_status === 'claimed' ? 'opacity-60' : ''"
                  :loading="markingPaid === payment.payment_id"
                  @click="markAsPaid(payment.payment_id)"
                >
                  Mark as Paid
                </BaseButton>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Payments Owed to Me Section -->
      <div>
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
          Payments Owed to Me
          <span class="text-sm font-normal text-gray-500 dark:text-gray-400 ml-2">
            ({{ paymentsOwedToMe.length }})
          </span>
        </h2>
        <div v-if="paymentsOwedToMe.length === 0" class="text-center py-8 text-gray-500 dark:text-gray-400 bg-white dark:bg-gray-800 rounded-lg">
          <p class="text-lg">No payments owed to you</p>
          <p class="text-sm mt-2">All payments are up to date</p>
        </div>
        <div v-else class="space-y-4">
          <div
            v-for="payment in paymentsOwedToMe"
            :key="`to-me-${payment.payment_id}`"
            class="bg-white dark:bg-gray-800 rounded-lg shadow p-6 border-l-4 border-green-500 dark:border-green-400"
          >
            <div class="flex justify-between items-start">
              <div class="flex-1">
                <h3 class="text-lg font-semibold dark:text-white">{{ payment.restaurant_name }}</h3>
                <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">Order Code: <span class="font-mono">{{ payment.order_code }}</span></p>
                <p class="text-sm text-gray-600 dark:text-gray-400">Payer: {{ payment.payer_name }}</p>
                <p class="text-sm text-gray-600 dark:text-gray-400">Status: 
                  <span :class="{
                    'text-yellow-600 dark:text-yellow-400': payment.order_status === 'LOCKED',
                    'text-indigo-600 dark:text-indigo-400': payment.order_status === 'ORDERED',
                    'text-gray-600 dark:text-gray-400': payment.order_status === 'CLOSED',
                  }">
                    {{ payment.order_status }}
                  </span>
                </p>
                <p class="text-xl font-bold text-green-600 dark:text-green-400 mt-2">{{ formatPrice(payment.amount) }} EGP</p>

                <!-- Payment proof review -->
                <div
                  v-if="payment.proof_status === 'claimed'"
                  class="mt-3 p-3 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg border border-yellow-200 dark:border-yellow-700"
                >
                  <div class="flex items-center gap-2 mb-2 flex-wrap">
                    <BaseBadge color="yellow">Proof submitted</BaseBadge>
                    <span class="text-xs text-gray-600 dark:text-gray-400">{{ payment.payer_name }} claims this payment was made</span>
                  </div>
                  <div class="flex items-center gap-3 flex-wrap">
                    <button
                      v-if="payment.proof_image_url"
                      type="button"
                      class="shrink-0 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      aria-label="View payment proof"
                      @click="openProofModal(payment)"
                    >
                      <img
                        :src="payment.proof_image_url"
                        alt="Payment proof thumbnail"
                        class="w-16 h-16 object-cover rounded-lg border border-gray-200 dark:border-gray-600 hover:opacity-80 transition-opacity"
                      />
                    </button>
                    <div class="flex gap-2">
                      <BaseButton
                        variant="success"
                        size="sm"
                        :loading="confirmingProof === payment.payment_id"
                        :disabled="rejectingProof === payment.payment_id"
                        @click="confirmProof(payment)"
                      >
                        Confirm
                      </BaseButton>
                      <BaseButton
                        variant="danger"
                        size="sm"
                        :loading="rejectingProof === payment.payment_id"
                        :disabled="confirmingProof === payment.payment_id"
                        @click="rejectProof(payment)"
                      >
                        Reject
                      </BaseButton>
                    </div>
                  </div>
                </div>
                <div v-else-if="payment.proof_status === 'rejected'" class="mt-2">
                  <BaseBadge color="red">Proof rejected</BaseBadge>
                </div>
              </div>
              <div class="flex flex-col space-y-2 ml-4">
                <router-link
                  :to="`/orders/${payment.order_code}`"
                  class="bg-indigo-600 dark:bg-indigo-500 text-white px-4 py-2 rounded-md hover:bg-indigo-700 dark:hover:bg-indigo-600 text-sm text-center"
                >
                  View Order
                </router-link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Hidden file input for proof uploads -->
    <input
      ref="proofFileInput"
      type="file"
      accept="image/*"
      class="hidden"
      @change="onProofFileSelected"
    />

    <!-- Full-size proof image modal -->
    <BaseModal
      :open="proofModal.open"
      :title="proofModal.payer ? `Payment proof — ${proofModal.payer}` : 'Payment proof'"
      size="lg"
      @close="closeProofModal"
    >
      <img
        v-if="proofModal.url"
        :src="proofModal.url"
        alt="Payment proof"
        class="w-full max-h-[70vh] object-contain rounded-lg"
      />
    </BaseModal>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import api from '../api'
import { useToast } from '../composables/useToast'
import { useConfirm } from '../composables/useConfirm'
import { useOrdersStore } from '../stores/orders'
import BaseButton from '../components/ui/BaseButton.vue'
import BaseBadge from '../components/ui/BaseBadge.vue'
import BaseModal from '../components/ui/BaseModal.vue'

const toast = useToast()
const { confirm: $confirm } = useConfirm()
const ordersStore = useOrdersStore()

const loading = ref(true)
const pendingPayments = ref([])
const paymentsOwedToMe = ref([])
const markingPaid = ref(null)
const expandedQR = ref(null)

// Payment proof state
const proofFileInput = ref(null)
const proofUploadTarget = ref(null)
const uploadingProof = ref(null)
const confirmingProof = ref(null)
const rejectingProof = ref(null)
const proofModal = ref({ open: false, url: null, payer: '' })

function toggleQR(paymentId) {
  expandedQR.value = expandedQR.value === paymentId ? null : paymentId
}

const paymentsIOwe = computed(() => {
  return pendingPayments.value.filter(p => p.payment_type === 'owed_by_me' || !p.payment_type)
})

function formatPrice(value) {
  if (value === null || value === undefined) return '0.00'
  const num = typeof value === 'string' ? parseFloat(value) : value
  return isNaN(num) ? '0.00' : num.toFixed(2)
}

async function fetchPendingPayments() {
  loading.value = true
  try {
    // Fetch payments I owe
    const response1 = await api.get('/orders/pending_payments/')
    pendingPayments.value = response1.data
    
    // Fetch payments owed to me
    const response2 = await api.get('/orders/pending_payments_to_me/')
    paymentsOwedToMe.value = response2.data
  } catch (error) {
    console.error('Failed to fetch pending payments:', error)
    toast.error('Failed to load pending payments: ' + (error.response?.data?.error || error.message))
  } finally {
    loading.value = false
  }
}

async function markAsPaid(paymentId) {
  if (!(await $confirm('Mark this payment as paid?', 'Confirm Payment'))) return

  markingPaid.value = paymentId
  try {
    await api.post(`/payments/${paymentId}/mark_paid/`)
    await fetchPendingPayments()
    toast.success('Payment marked as paid!')
  } catch (error) {
    toast.error('Failed to mark payment as paid: ' + (error.response?.data?.error || error.message))
  } finally {
    markingPaid.value = null
  }
}

function triggerProofUpload(payment) {
  proofUploadTarget.value = payment
  proofFileInput.value?.click()
}

async function onProofFileSelected(event) {
  const file = event.target.files?.[0]
  event.target.value = '' // allow re-selecting the same file later
  const payment = proofUploadTarget.value
  proofUploadTarget.value = null
  if (!file || !payment) return

  uploadingProof.value = payment.payment_id
  const result = await ordersStore.uploadPaymentProof(payment.payment_id, file)
  uploadingProof.value = null

  if (result.success) {
    payment.proof_status = 'claimed'
    if (result.data?.proof_image_url) payment.proof_image_url = result.data.proof_image_url
    toast.success(`Proof sent to ${payment.collector_name} for confirmation`)
  } else {
    toast.error('Failed to upload proof: ' + (result.error?.error || result.error?.detail || 'Unknown error'))
  }
}

function openProofModal(payment) {
  proofModal.value = { open: true, url: payment.proof_image_url, payer: payment.payer_name }
}

function closeProofModal() {
  proofModal.value = { ...proofModal.value, open: false }
}

async function confirmProof(payment) {
  const ok = await $confirm(
    `Confirm you received ${formatPrice(payment.amount)} EGP from ${payment.payer_name}?`,
    'Confirm Payment Proof'
  )
  if (!ok) return

  confirmingProof.value = payment.payment_id
  const result = await ordersStore.confirmPaymentProof(payment.payment_id)
  confirmingProof.value = null

  if (result.success) {
    paymentsOwedToMe.value = paymentsOwedToMe.value.filter(p => p.payment_id !== payment.payment_id)
    toast.success(`Payment from ${payment.payer_name} confirmed`)
  } else {
    toast.error('Failed to confirm proof: ' + (result.error?.error || result.error?.detail || 'Unknown error'))
  }
}

async function rejectProof(payment) {
  const ok = await $confirm(
    `Reject the payment proof from ${payment.payer_name}? They will be asked to try again.`,
    'Reject Payment Proof'
  )
  if (!ok) return

  rejectingProof.value = payment.payment_id
  const result = await ordersStore.rejectPaymentProof(payment.payment_id)
  rejectingProof.value = null

  if (result.success) {
    payment.proof_status = 'rejected'
    toast.info(`Proof from ${payment.payer_name} rejected`)
  } else {
    toast.error('Failed to reject proof: ' + (result.error?.error || result.error?.detail || 'Unknown error'))
  }
}

onMounted(() => {
  fetchPendingPayments()
})
</script>

