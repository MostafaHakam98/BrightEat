<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div v-if="loading" class="text-center py-8">
      <p class="text-lg">Loading order...</p>
    </div>
    <div v-else-if="error" class="text-center py-8">
      <p class="text-red-600 mb-4">{{ error }}</p>
      <router-link to="/" class="text-blue-600 hover:text-blue-800">Go Home</router-link>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useOrdersStore } from '../stores/orders'

const route = useRoute()
const router = useRouter()
const ordersStore = useOrdersStore()
const loading = ref(true)
const error = ref(null)

onMounted(async () => {
  const code = route.params.code.toUpperCase()
  
  try {
    const result = await ordersStore.fetchOrderByCode(code)
    
    if (result.success) {
      // Redirect to order detail page
      router.replace(`/orders/${code}`)
    } else {
      error.value = result.error?.detail || 'Order not found'
      loading.value = false
    }
  } catch (err) {
    error.value = 'Failed to load order'
    loading.value = false
  }
})
</script>

