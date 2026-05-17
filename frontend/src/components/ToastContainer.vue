<template>
  <teleport to="body">
    <div class="fixed top-4 right-4 z-[9999] flex flex-col gap-2 pointer-events-none" style="max-width: 24rem; width: calc(100vw - 2rem)">
      <transition-group name="toast">
        <div
          v-for="toast in toasts"
          :key="toast.id"
          class="pointer-events-auto flex items-start gap-3 rounded-xl px-4 py-3 shadow-lg ring-1 backdrop-blur-sm text-sm font-medium"
          :class="{
            'bg-green-50/95 dark:bg-green-900/80 text-green-800 dark:text-green-200 ring-green-200 dark:ring-green-700': toast.type === 'success',
            'bg-red-50/95 dark:bg-red-900/80 text-red-800 dark:text-red-200 ring-red-200 dark:ring-red-700': toast.type === 'error',
            'bg-amber-50/95 dark:bg-amber-900/80 text-amber-800 dark:text-amber-200 ring-amber-200 dark:ring-amber-700': toast.type === 'warning',
            'bg-blue-50/95 dark:bg-blue-900/80 text-blue-800 dark:text-blue-200 ring-blue-200 dark:ring-blue-700': toast.type === 'info',
          }"
        >
          <!-- Icon -->
          <span class="shrink-0 mt-0.5 text-base leading-none">
            <span v-if="toast.type === 'success'">✓</span>
            <span v-else-if="toast.type === 'error'">✕</span>
            <span v-else-if="toast.type === 'warning'">⚠</span>
            <span v-else>ℹ</span>
          </span>
          <!-- Message -->
          <span class="flex-1 leading-snug">{{ toast.message }}</span>
          <!-- Close -->
          <button
            class="shrink-0 opacity-60 hover:opacity-100 transition-opacity leading-none"
            @click="remove(toast.id)"
          >✕</button>
        </div>
      </transition-group>
    </div>
  </teleport>
</template>

<script setup>
import { useToast } from '../composables/useToast'

const { toasts, remove } = useToast()
</script>

<style scoped>
.toast-enter-active {
  transition: all 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.toast-leave-active {
  transition: all 0.2s ease-in;
}
.toast-enter-from {
  opacity: 0;
  transform: translateX(1.5rem) scale(0.95);
}
.toast-leave-to {
  opacity: 0;
  transform: translateX(1.5rem) scale(0.95);
}
.toast-move {
  transition: transform 0.2s ease;
}
</style>
