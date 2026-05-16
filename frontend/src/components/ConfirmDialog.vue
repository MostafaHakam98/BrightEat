<template>
  <teleport to="body">
    <transition name="dialog">
      <div
        v-if="visible"
        class="fixed inset-0 z-[9998] flex items-center justify-center p-4"
        @keydown.esc="cancel"
        tabindex="-1"
        ref="overlayRef"
      >
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/40 dark:bg-black/60 backdrop-blur-sm" @click="cancel" />
        <!-- Panel -->
        <div class="relative bg-white dark:bg-gray-800 rounded-2xl shadow-2xl ring-1 ring-black/5 dark:ring-white/10 w-full max-w-sm p-6 flex flex-col gap-4">
          <h3 class="text-base font-semibold text-gray-900 dark:text-white">{{ dialogOptions.title }}</h3>
          <p class="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">{{ dialogOptions.message }}</p>
          <div class="flex gap-3 justify-end mt-1">
            <button
              @click="cancel"
              class="px-4 py-2 rounded-lg text-sm font-medium border border-gray-200 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
            >
              Cancel
            </button>
            <button
              @click="accept"
              class="px-4 py-2 rounded-lg text-sm font-medium bg-indigo-600 dark:bg-indigo-500 text-white hover:bg-indigo-700 dark:hover:bg-indigo-600 transition-colors"
            >
              Confirm
            </button>
          </div>
        </div>
      </div>
    </transition>
  </teleport>
</template>

<script setup>
import { watch, ref, nextTick } from 'vue'
import { useConfirm } from '../composables/useConfirm'

const { visible, dialogOptions, accept, cancel } = useConfirm()
const overlayRef = ref(null)

watch(visible, (v) => {
  if (v) nextTick(() => overlayRef.value?.focus())
})
</script>

<style scoped>
.dialog-enter-active,
.dialog-leave-active {
  transition: opacity 0.15s ease;
}
.dialog-enter-from,
.dialog-leave-to {
  opacity: 0;
}
.dialog-enter-active .relative,
.dialog-leave-active .relative {
  transition: transform 0.15s ease, opacity 0.15s ease;
}
.dialog-enter-from .relative,
.dialog-leave-to .relative {
  transform: scale(0.95);
  opacity: 0;
}
</style>
