<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-6">
      <h1 class="text-3xl font-bold text-gray-900">Recommendations</h1>
      <p class="text-gray-600 mt-2">Share your favorite restaurants and dishes</p>
    </div>

    <!-- Add Recommendation Form -->
    <div class="bg-white rounded-lg shadow p-6 mb-6">
      <h2 class="text-xl font-semibold mb-4">Add Recommendation</h2>
      <form @submit.prevent="addRecommendation" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Restaurant (Optional)</label>
          <select
            v-model="newRecommendation.restaurant"
            class="w-full px-3 py-2 border border-gray-300 rounded-md"
          >
            <option :value="null">General Recommendation</option>
            <option v-for="restaurant in restaurants" :key="restaurant.id" :value="restaurant.id">
              {{ restaurant.name }}
            </option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Your Recommendation</label>
          <textarea
            v-model="newRecommendation.text"
            required
            rows="4"
            placeholder="Share your favorite dish, restaurant tip, or food recommendation..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md"
          ></textarea>
        </div>
        <button
          type="submit"
          :disabled="submitting"
          class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50"
        >
          {{ submitting ? 'Submitting...' : 'Add Recommendation' }}
        </button>
      </form>
    </div>

    <!-- Recommendations List -->
    <div v-if="loading" class="text-center py-8">
      <p class="text-lg">Loading recommendations...</p>
    </div>
    <div v-else-if="recommendations.length === 0" class="text-center py-8 text-gray-500">
      <p class="text-lg">No recommendations yet</p>
      <p class="text-sm mt-2">Be the first to share a recommendation!</p>
    </div>
    <div v-else class="space-y-4">
      <div
        v-for="rec in recommendations"
        :key="rec.id"
        class="bg-white rounded-lg shadow p-6"
      >
        <div class="flex justify-between items-start mb-2">
          <div>
            <p class="font-semibold text-lg">{{ rec.user_name }}</p>
            <p v-if="rec.restaurant_name" class="text-sm text-blue-600">{{ rec.restaurant_name }}</p>
            <p v-else class="text-sm text-gray-500">General Recommendation</p>
          </div>
          <p class="text-sm text-gray-500">{{ new Date(rec.created_at).toLocaleDateString() }}</p>
        </div>
        <p class="text-gray-700 whitespace-pre-wrap">{{ rec.text }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '../api'
import { useOrdersStore } from '../stores/orders'

const ordersStore = useOrdersStore()
const loading = ref(true)
const submitting = ref(false)
const recommendations = ref([])
const restaurants = ref([])

const newRecommendation = ref({
  restaurant: null,
  text: '',
})

async function fetchRecommendations() {
  loading.value = true
  try {
    const response = await api.get('/recommendations/')
    recommendations.value = response.data.results || response.data
  } catch (error) {
    console.error('Failed to fetch recommendations:', error)
    alert('Failed to load recommendations: ' + (error.response?.data?.error || error.message))
  } finally {
    loading.value = false
  }
}

async function addRecommendation() {
  if (!newRecommendation.value.text.trim()) {
    alert('Please enter a recommendation')
    return
  }
  
  submitting.value = true
  try {
    const data = {
      text: newRecommendation.value.text,
    }
    if (newRecommendation.value.restaurant) {
      data.restaurant = newRecommendation.value.restaurant
    }
    
    await api.post('/recommendations/', data)
    newRecommendation.value = { restaurant: null, text: '' }
    await fetchRecommendations()
    alert('Recommendation added successfully!')
  } catch (error) {
    alert('Failed to add recommendation: ' + (error.response?.data?.error || error.message))
  } finally {
    submitting.value = false
  }
}

onMounted(async () => {
  await ordersStore.fetchRestaurants()
  restaurants.value = ordersStore.restaurants
  await fetchRecommendations()
})
</script>

