<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-8 flex justify-between items-center">
      <h1 class="text-3xl font-bold text-gray-900">Restaurants</h1>
      <button
        @click="showCreateModal = true"
        class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
      >
        Add Restaurant
      </button>
    </div>

    <div v-if="loading" class="text-center py-8">Loading...</div>
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div
        v-for="restaurant in ordersStore.restaurants"
        :key="restaurant.id"
        class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition border border-gray-100"
      >
        <h3 class="text-xl font-semibold mb-2 text-gray-800">{{ restaurant.name }}</h3>
        <p class="text-gray-600 mb-4">{{ restaurant.description || 'No description' }}</p>
        <div class="flex space-x-2">
          <router-link
            :to="`/restaurants/${restaurant.id}/menus`"
            class="flex-1 text-center bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
          >
            Manage Menus
          </router-link>
          <button
            @click="editRestaurant(restaurant)"
            class="bg-yellow-600 text-white px-4 py-2 rounded-md hover:bg-yellow-700 focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:ring-offset-2 transition-colors"
          >
            Edit
          </button>
          <button
            @click="deleteRestaurant(restaurant.id)"
            class="bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors"
          >
            Delete
          </button>
        </div>
      </div>
    </div>

    <!-- Create/Edit Restaurant Modal -->
    <div
      v-if="showCreateModal || editingRestaurant"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click="closeModal"
    >
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 shadow-xl" @click.stop>
        <h2 class="text-xl font-semibold mb-4 text-gray-800">
          {{ editingRestaurant ? 'Edit Restaurant' : 'Add Restaurant' }}
        </h2>
        <form @submit.prevent="saveRestaurant" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Name</label>
            <input
              v-model="newRestaurant.name"
              type="text"
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Description</label>
            <textarea
              v-model="newRestaurant.description"
              rows="3"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            ></textarea>
          </div>
          <div class="flex space-x-2">
            <button
              type="button"
              @click="closeModal"
              class="flex-1 bg-gray-200 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="creating"
              class="flex-1 bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
            >
              {{ creating ? (editingRestaurant ? 'Updating...' : 'Creating...') : (editingRestaurant ? 'Update' : 'Create') }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useOrdersStore } from '../stores/orders'

const ordersStore = useOrdersStore()
const loading = ref(false)
const showCreateModal = ref(false)
const creating = ref(false)
const editingRestaurant = ref(null)
const newRestaurant = ref({
  name: '',
  description: '',
})

onMounted(async () => {
  loading.value = true
  await ordersStore.fetchRestaurants()
  loading.value = false
})

function editRestaurant(restaurant) {
  editingRestaurant.value = restaurant
  newRestaurant.value = {
    name: restaurant.name,
    description: restaurant.description || '',
  }
}

function closeModal() {
  showCreateModal.value = false
  editingRestaurant.value = null
  newRestaurant.value = { name: '', description: '' }
}

async function saveRestaurant() {
  creating.value = true
  
  if (editingRestaurant.value) {
    const result = await ordersStore.updateRestaurant(editingRestaurant.value.id, newRestaurant.value)
    if (result.success) {
      closeModal()
    } else {
      alert('Failed to update restaurant: ' + (result.error?.detail || JSON.stringify(result.error)))
    }
  } else {
    const result = await ordersStore.createRestaurant(newRestaurant.value)
    if (result.success) {
      closeModal()
    } else {
      alert('Failed to create restaurant: ' + (result.error?.detail || JSON.stringify(result.error)))
    }
  }
  
  creating.value = false
}

async function deleteRestaurant(restaurantId) {
  if (!confirm('Are you sure you want to delete this restaurant? This will also delete all associated menus and menu items. This action cannot be undone.')) {
    return
  }
  
  const result = await ordersStore.deleteRestaurant(restaurantId)
  if (!result.success) {
    alert('Failed to delete restaurant: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
}
</script>

