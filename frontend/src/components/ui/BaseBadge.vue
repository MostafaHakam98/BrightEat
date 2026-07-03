<template>
  <span :class="['inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold', colorClasses]">
    <slot />
  </span>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  // Semantic colors, plus order statuses mapped directly (OPEN/LOCKED/…)
  color: { type: String, default: 'gray' },
})

const MAP = {
  green:  'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300',
  yellow: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-300',
  blue:   'bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300',
  red:    'bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300',
  gray:   'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300',
  OPEN:    'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300',
  LOCKED:  'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-300',
  ORDERED: 'bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300',
  CLOSED:  'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300',
}

const colorClasses = computed(() => MAP[props.color] || MAP.gray)
</script>
