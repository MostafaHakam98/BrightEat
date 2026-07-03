<template>
  <div v-if="canManage && hasAnyAction">
    <!-- Desktop: inline card in the right column -->
    <div class="hidden md:block bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200 dark:ring-gray-700 p-6">
      <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Actions</h2>
      <div class="space-y-2">
        <BaseButton
          v-if="primaryAction"
          block
          :variant="primaryAction.variant"
          :loading="busy"
          @click="$emit(primaryAction.event)"
        >
          {{ primaryAction.label }}
        </BaseButton>
        <BaseButton
          v-for="action in secondaryActions"
          :key="action.event"
          block
          variant="secondary"
          :disabled="busy"
          @click="$emit(action.event)"
        >
          {{ action.label }}
        </BaseButton>

        <!-- Transfer collector (collector only, OPEN, more than one participant) -->
        <div v-if="showTransfer" class="pt-4 mt-2 border-t border-gray-200 dark:border-gray-700">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Transfer Collector Role</label>
          <select
            v-model="transferTo"
            class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-purple-500 dark:bg-gray-700 dark:text-white"
          >
            <option value="">Select new collector</option>
            <option
              v-for="participant in transferCandidates"
              :key="participant.id"
              :value="participant.id"
            >
              {{ participant.username }}
            </option>
          </select>
          <BaseButton block variant="secondary" :disabled="!transferTo || busy" @click="emitTransfer">
            Transfer Collector Role
          </BaseButton>
        </div>

        <BaseButton
          v-if="canDelete"
          block
          variant="ghost"
          class="text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20"
          :disabled="busy"
          @click="$emit('delete')"
        >
          🗑️ Delete Order
        </BaseButton>
      </div>
    </div>

    <!-- Mobile: fixed bottom bar (parent view pads the page bottom so content is never covered) -->
    <div class="md:hidden fixed bottom-0 inset-x-0 z-40 bg-white/95 dark:bg-gray-800/95 backdrop-blur border-t border-gray-200 dark:border-gray-700">
      <div class="px-4 pt-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))] flex items-center gap-2">
        <BaseButton
          v-if="primaryAction"
          class="flex-1"
          :variant="primaryAction.variant"
          :loading="busy"
          @click="$emit(primaryAction.event)"
        >
          {{ primaryAction.label }}
        </BaseButton>
        <p v-else class="flex-1 text-sm text-center text-gray-500 dark:text-gray-400">
          Order is {{ (order?.status || '').toLowerCase() }}
        </p>

        <div v-if="hasOverflow" class="relative">
          <BaseButton
            variant="secondary"
            aria-label="More actions"
            :aria-expanded="overflowOpen ? 'true' : 'false'"
            @click="overflowOpen = !overflowOpen"
          >
            ⋯
          </BaseButton>
          <div
            v-if="overflowOpen"
            class="absolute bottom-full right-0 mb-2 w-60 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl shadow-lg p-2 space-y-1"
          >
            <button
              v-for="action in secondaryActions"
              :key="action.event"
              type="button"
              class="w-full text-left px-3 py-2 text-sm rounded-lg text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700"
              :disabled="busy"
              @click="emitOverflow(action.event)"
            >
              {{ action.label }}
            </button>

            <div v-if="showTransfer" class="px-3 py-2 border-t border-gray-100 dark:border-gray-700">
              <p class="text-xs font-medium text-gray-500 dark:text-gray-400 mb-1.5">Transfer Collector Role</p>
              <select
                v-model="transferTo"
                class="w-full mb-2 px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
              >
                <option value="">Select new collector</option>
                <option
                  v-for="participant in transferCandidates"
                  :key="participant.id"
                  :value="participant.id"
                >
                  {{ participant.username }}
                </option>
              </select>
              <BaseButton block size="sm" variant="secondary" :disabled="!transferTo || busy" @click="emitTransfer">
                Transfer
              </BaseButton>
            </div>

            <button
              v-if="canDelete"
              type="button"
              class="w-full text-left px-3 py-2 text-sm rounded-lg text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20"
              :disabled="busy"
              @click="emitOverflow('delete')"
            >
              🗑️ Delete Order
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import BaseButton from '../ui/BaseButton.vue'

const props = defineProps({
  order: { type: Object, default: null },
  canManage: { type: Boolean, default: false },
  isCollector: { type: Boolean, default: false },
  canDelete: { type: Boolean, default: false },
  busy: { type: Boolean, default: false },
})

const emit = defineEmits(['lock', 'unlock', 'mark-ordered', 'close', 'delete', 'transfer'])

const transferTo = ref('')
const overflowOpen = ref(false)

const primaryAction = computed(() => {
  switch (props.order?.status) {
    case 'OPEN':
      return { label: '🔒 Lock Order', event: 'lock', variant: 'primary' }
    case 'LOCKED':
      return { label: '✅ Mark as Ordered', event: 'mark-ordered', variant: 'primary' }
    case 'ORDERED':
      return { label: '🔚 Close Order', event: 'close', variant: 'success' }
    default:
      return null
  }
})

const secondaryActions = computed(() => {
  if (props.order?.status === 'LOCKED') {
    return [{ label: '🔓 Unlock Order', event: 'unlock' }]
  }
  return []
})

const transferCandidates = computed(() =>
  (props.order?.participants || []).filter(p => p.id !== props.order?.collector)
)

const showTransfer = computed(() =>
  props.order?.status === 'OPEN' &&
  props.isCollector &&
  (props.order?.participants?.length || 0) > 1
)

const hasOverflow = computed(() =>
  secondaryActions.value.length > 0 || showTransfer.value || props.canDelete
)

const hasAnyAction = computed(() =>
  !!primaryAction.value || hasOverflow.value
)

function emitTransfer() {
  if (!transferTo.value) return
  emit('transfer', transferTo.value)
  transferTo.value = ''
  overflowOpen.value = false
}

function emitOverflow(event) {
  overflowOpen.value = false
  emit(event)
}
</script>
