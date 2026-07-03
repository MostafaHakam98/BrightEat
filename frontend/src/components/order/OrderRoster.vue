<template>
  <BaseCard :title="`Who's in (${people.length})`">
    <p v-if="!people.length" class="text-sm text-gray-500 dark:text-gray-400 text-center py-2">
      Nobody has joined yet.
    </p>
    <ul v-else class="space-y-2.5">
      <li
        v-for="person in people"
        :key="person.id"
        class="flex items-center justify-between gap-2"
      >
        <div class="flex items-center gap-2 min-w-0">
          <span
            class="w-7 h-7 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 flex items-center justify-center text-xs font-semibold shrink-0"
          >
            {{ initial(person.username) }}
          </span>
          <span class="text-sm font-medium text-gray-800 dark:text-gray-100 truncate">
            {{ person.username }}
          </span>
          <BaseBadge v-if="person.isCollector" color="blue">👑 Collector</BaseBadge>
        </div>
        <div class="flex items-center gap-1.5 shrink-0">
          <template v-if="person.itemCount > 0">
            <BaseBadge color="gray">
              {{ person.itemCount }} item{{ person.itemCount === 1 ? '' : 's' }}
            </BaseBadge>
            <BaseBadge v-if="person.payment" :color="person.payment.is_paid ? 'green' : 'yellow'">
              {{ person.payment.is_paid ? 'paid' : 'unpaid' }}
            </BaseBadge>
          </template>
          <BaseBadge v-else color="yellow">joined — no items yet</BaseBadge>
        </div>
      </li>
    </ul>
  </BaseCard>
</template>

<script setup>
import { computed } from 'vue'
import BaseCard from '../ui/BaseCard.vue'
import BaseBadge from '../ui/BaseBadge.vue'

const props = defineProps({
  order: { type: Object, default: null },
})

function initial(name) {
  return (name || '?').trim().charAt(0).toUpperCase() || '?'
}

const people = computed(() => {
  const order = props.order
  if (!order) return []

  // participants (users with items) ∪ joined_users_details (explicitly joined) ∪ collector
  const map = new Map()
  for (const p of order.participants || []) {
    map.set(p.id, { id: p.id, username: p.username })
  }
  for (const j of order.joined_users_details || []) {
    if (!map.has(j.id)) map.set(j.id, { id: j.id, username: j.username })
  }
  if (order.collector && !map.has(order.collector)) {
    map.set(order.collector, { id: order.collector, username: order.collector_name || 'Collector' })
  }

  const itemCounts = {}
  for (const item of order.items || []) {
    itemCounts[item.user] = (itemCounts[item.user] || 0) + 1
  }
  const paymentsByUser = {}
  for (const payment of order.payments || []) {
    paymentsByUser[payment.user] = payment
  }

  return [...map.values()]
    .map(u => ({
      ...u,
      isCollector: u.id === order.collector,
      itemCount: itemCounts[u.id] || 0,
      payment: paymentsByUser[u.id] || null,
    }))
    .sort((a, b) =>
      (b.isCollector - a.isCollector) ||
      (a.username || '').localeCompare(b.username || '')
    )
})
</script>
