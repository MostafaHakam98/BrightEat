<template>
  <button
    :type="type"
    :disabled="disabled || loading"
    :class="[
      'inline-flex items-center justify-center gap-2 font-semibold rounded-xl transition-colors',
      'focus:outline-none focus:ring-2 focus:ring-offset-1 dark:focus:ring-offset-gray-900',
      'disabled:opacity-50 disabled:cursor-not-allowed',
      sizeClasses,
      variantClasses,
      block ? 'w-full' : '',
    ]"
  >
    <svg v-if="loading" class="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
    </svg>
    <slot />
  </button>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  variant: { type: String, default: 'primary' }, // primary | secondary | danger | success | ghost
  size: { type: String, default: 'md' },         // sm | md | lg
  type: { type: String, default: 'button' },
  disabled: Boolean,
  loading: Boolean,
  block: Boolean,
})

const variantClasses = computed(() => ({
  primary:   'bg-blue-600 hover:bg-blue-700 text-white focus:ring-blue-500',
  secondary: 'bg-gray-100 hover:bg-gray-200 text-gray-800 dark:bg-gray-700 dark:hover:bg-gray-600 dark:text-gray-100 focus:ring-gray-400',
  danger:    'bg-red-600 hover:bg-red-700 text-white focus:ring-red-500',
  success:   'bg-green-600 hover:bg-green-700 text-white focus:ring-green-500',
  ghost:     'bg-transparent hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-600 dark:text-gray-300 focus:ring-gray-400',
}[props.variant]))

const sizeClasses = computed(() => ({
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-sm',
  lg: 'px-5 py-3 text-base',
}[props.size]))
</script>
