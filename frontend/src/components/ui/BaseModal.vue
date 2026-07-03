<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-if="open"
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50"
        @mousedown.self="closeOnBackdrop && $emit('close')"
      >
        <div
          ref="panel"
          role="dialog"
          aria-modal="true"
          :aria-label="title || undefined"
          :class="['bg-white dark:bg-gray-800 rounded-2xl shadow-xl w-full flex flex-col max-h-[90vh]', sizeClass]"
          @keydown="onKeydown"
        >
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-700">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">{{ title }}</h3>
            <button
              class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 rounded-lg p-1 focus:outline-none focus:ring-2 focus:ring-blue-500"
              aria-label="Close dialog"
              @click="$emit('close')"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <div class="px-5 py-4 overflow-y-auto">
            <slot />
          </div>
          <div v-if="$slots.footer" class="px-5 py-4 border-t border-gray-100 dark:border-gray-700">
            <slot name="footer" />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { ref, watch, nextTick, computed } from 'vue'

const props = defineProps({
  open: Boolean,
  title: { type: String, default: '' },
  size: { type: String, default: 'md' }, // sm | md | lg
  closeOnBackdrop: { type: Boolean, default: true },
})
const emit = defineEmits(['close'])

const panel = ref(null)
let previouslyFocused = null

const sizeClass = computed(() => ({
  sm: 'max-w-sm', md: 'max-w-lg', lg: 'max-w-2xl',
}[props.size]))

const FOCUSABLE = 'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'

watch(() => props.open, async (open) => {
  if (open) {
    previouslyFocused = document.activeElement
    await nextTick()
    const first = panel.value?.querySelector(FOCUSABLE)
    ;(first || panel.value)?.focus()
  } else {
    previouslyFocused?.focus?.()
  }
})

function onKeydown(e) {
  if (e.key === 'Escape') {
    emit('close')
    return
  }
  if (e.key !== 'Tab' || !panel.value) return
  // Keep Tab focus inside the dialog
  const nodes = [...panel.value.querySelectorAll(FOCUSABLE)].filter(n => !n.disabled)
  if (!nodes.length) return
  const first = nodes[0]
  const last = nodes[nodes.length - 1]
  if (e.shiftKey && document.activeElement === first) {
    e.preventDefault(); last.focus()
  } else if (!e.shiftKey && document.activeElement === last) {
    e.preventDefault(); first.focus()
  }
}
</script>

<style scoped>
.modal-enter-active, .modal-leave-active { transition: opacity 0.15s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
</style>
