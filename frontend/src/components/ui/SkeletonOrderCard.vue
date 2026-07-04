<template>
  <div
    class="relative overflow-hidden bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200/80 dark:ring-gray-700/50 shadow-sm p-5"
    aria-hidden="true"
  >
    <!-- status accent strip -->
    <div class="absolute inset-x-0 top-0 h-1 bg-gray-200 dark:bg-gray-700 animate-pulse" />

    <div class="flex items-start justify-between gap-3">
      <BaseSkeleton width="55%" height="1.25rem" />
      <BaseSkeleton width="4.25rem" height="1.375rem" rounded="full" />
    </div>

    <div class="mt-3 space-y-2">
      <BaseSkeleton width="38%" height="0.8125rem" />
      <BaseSkeleton width="52%" height="0.8125rem" />
    </div>

    <div class="mt-3">
      <BaseSkeleton width="7.5rem" height="1.375rem" rounded="full" />
    </div>

    <div class="mt-4 flex gap-2">
      <div class="flex-1"><BaseSkeleton height="2.25rem" /></div>
      <div class="w-20"><BaseSkeleton height="2.25rem" /></div>
    </div>
  </div>
</template>

<script setup>
import BaseSkeleton from './BaseSkeleton.vue'
</script>
