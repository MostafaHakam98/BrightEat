<template>
  <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-100 dark:border-gray-700">
    <div v-if="title || $slots.header" class="px-5 pt-4 pb-2 flex items-center justify-between">
      <h3 v-if="title" class="text-base font-semibold text-gray-900 dark:text-gray-100">{{ title }}</h3>
      <slot name="header" />
    </div>
    <div :class="padded ? 'px-5 py-4' : ''">
      <slot />
    </div>
  </div>
</template>

<script setup>
defineProps({
  title: { type: String, default: '' },
  padded: { type: Boolean, default: true },
})
</script>
