<template>
  <BaseModal :open="open" title="Custom Split — Lock Order" size="md" @close="$emit('close')">
    <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
      Set exactly how much each participant owes. Amounts are prefilled with each
      person's items plus a proportional share of the fees.
    </p>
    <div class="space-y-3">
      <div
        v-for="participant in participants"
        :key="participant.id"
        class="flex items-center justify-between gap-3"
      >
        <label
          :for="`custom-split-${participant.id}`"
          class="text-sm font-medium text-gray-700 dark:text-gray-300 truncate"
        >
          {{ participant.username }}
        </label>
        <div class="flex items-center gap-2 shrink-0">
          <input
            :id="`custom-split-${participant.id}`"
            v-model="amounts[participant.id]"
            type="number"
            step="0.01"
            min="0"
            inputmode="decimal"
            class="w-28 px-3 py-2 text-right text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
          <span class="text-xs text-gray-500 dark:text-gray-400">EGP</span>
        </div>
      </div>
      <p v-if="!participants.length" class="text-sm text-gray-500 dark:text-gray-400 text-center py-2">
        No participants with items to split between.
      </p>
    </div>

    <template #footer>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <p class="text-sm text-gray-600 dark:text-gray-300">
          Allocated <span class="font-semibold text-gray-900 dark:text-white">{{ allocated.toFixed(2) }}</span>
          / Total <span class="font-semibold text-gray-900 dark:text-white">{{ totalCost.toFixed(2) }}</span>
          — Remaining
          <span
            class="font-semibold"
            :class="balanced ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'"
          >
            {{ remaining.toFixed(2) }}
          </span>
        </p>
        <div class="flex gap-2 justify-end">
          <BaseButton variant="secondary" :disabled="submitting" @click="$emit('close')">
            Cancel
          </BaseButton>
          <BaseButton
            variant="primary"
            :disabled="!balanced || !participants.length"
            :loading="submitting"
            @click="confirmLock"
          >
            🔒 Lock Order
          </BaseButton>
        </div>
      </div>
    </template>
  </BaseModal>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import BaseModal from '../ui/BaseModal.vue'
import BaseButton from '../ui/BaseButton.vue'
import { useOrdersStore } from '../../stores/orders'
import { useToast } from '../../composables/useToast'

const props = defineProps({
  open: { type: Boolean, default: false },
  order: { type: Object, default: null },
})

const emit = defineEmits(['close', 'locked'])

const ordersStore = useOrdersStore()
const toast = useToast()

const amounts = ref({})
const submitting = ref(false)

const participants = computed(() => props.order?.participants || [])
const totalCost = computed(() => parseFloat(props.order?.total_cost) || 0)

const allocated = computed(() =>
  Object.values(amounts.value).reduce((sum, v) => sum + (parseFloat(v) || 0), 0)
)
const remaining = computed(() => totalCost.value - allocated.value)
const balanced = computed(() => Math.abs(remaining.value) <= 0.01)

// Prefill proportionally (item cost + proportional fee share) each time the modal opens
watch(() => props.open, (isOpen) => {
  if (isOpen) prefill()
})

function prefill() {
  const order = props.order
  if (!order) return
  const itemCostByUser = {}
  for (const item of order.items || []) {
    itemCostByUser[item.user] = (itemCostByUser[item.user] || 0) + (parseFloat(item.total_price) || 0)
  }
  const totalItems = parseFloat(order.total_items_cost) || 0
  const feesTotal = Math.max(totalCost.value - totalItems, 0)
  const count = participants.value.length

  const next = {}
  for (const participant of participants.value) {
    const cost = itemCostByUser[participant.id] || 0
    const feeShare = totalItems > 0
      ? feesTotal * (cost / totalItems)
      : (count > 0 ? feesTotal / count : 0)
    next[participant.id] = (cost + feeShare).toFixed(2)
  }
  amounts.value = next
}

async function confirmLock() {
  if (!balanced.value || !props.order || submitting.value) return
  submitting.value = true
  try {
    const customAmounts = {}
    for (const [userId, value] of Object.entries(amounts.value)) {
      customAmounts[userId] = (parseFloat(value) || 0).toFixed(2)
    }
    const result = await ordersStore.lockOrder(props.order.id, customAmounts)
    if (result.success) {
      emit('locked')
    } else {
      // Keep the modal open so the user can fix the amounts
      const errorMsg = result.error?.detail || result.error?.error || JSON.stringify(result.error || 'Unknown error')
      toast.error('Failed to lock order: ' + errorMsg)
    }
  } finally {
    submitting.value = false
  }
}
</script>
