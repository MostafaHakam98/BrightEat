<template>
  <div
    :class="[
      'animate-pulse bg-gray-200 dark:bg-gray-700',
      rounded === 'full' ? 'rounded-full' : 'rounded-lg',
    ]"
    :style="{ width, height }"
    aria-hidden="true"
  />
</template>

<script setup>
defineProps({
  width: { type: String, default: '100%' },
  height: { type: String, default: '1rem' },
  rounded: { type: String, default: 'lg' }, // lg | full
})
</script>
