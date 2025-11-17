<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-6">
      <button
        @click="$router.push('/restaurants')"
        class="text-blue-600 hover:text-blue-800 mb-4"
      >
        ← Back to Restaurants
      </button>
      <h1 class="text-3xl font-bold text-gray-900">{{ restaurant?.name || 'Menu Management' }}</h1>
      <p class="text-gray-600 mt-2">{{ restaurant?.description || '' }}</p>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Menus List -->
      <div class="lg:col-span-1 space-y-4">
        <div class="bg-white rounded-lg shadow p-4">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-lg font-semibold">Menus</h2>
            <button
              @click="showCreateMenuModal = true"
              class="bg-green-600 text-white px-3 py-1 rounded text-sm hover:bg-green-700"
            >
              + Add Menu
            </button>
          </div>
          <div class="space-y-2">
            <div
              v-for="menu in menus"
              :key="menu.id"
              :class="[
                'p-3 border rounded transition',
                selectedMenu?.id === menu.id
                  ? 'border-blue-500 bg-blue-50'
                  : 'border-gray-200 hover:border-gray-300'
              ]"
            >
              <div class="flex justify-between items-center mb-2">
                <span 
                  @click="selectMenu(menu)"
                  class="font-medium cursor-pointer flex-1"
                >
                  {{ menu.name }}
                </span>
                <span
                  :class="[
                    'text-xs px-2 py-1 rounded',
                    menu.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                  ]"
                >
                  {{ menu.is_active ? 'Active' : 'Inactive' }}
                </span>
              </div>
              <div class="flex space-x-1 mt-2" @click.stop>
                <button
                  @click="editMenu(menu)"
                  class="flex-1 bg-yellow-600 text-white px-2 py-1 rounded text-xs hover:bg-yellow-700 focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:ring-offset-1 transition-colors"
                >
                  Edit
                </button>
                <button
                  @click="deleteMenu(menu.id)"
                  class="flex-1 bg-red-600 text-white px-2 py-1 rounded text-xs hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-1 transition-colors"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Menu Items -->
      <div class="lg:col-span-2">
        <div v-if="!selectedMenu" class="bg-white rounded-lg shadow p-8 text-center text-gray-500">
          Select a menu to manage items
        </div>
        <div v-else class="bg-white rounded-lg shadow p-6">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-semibold">{{ selectedMenu.name }} Items</h2>
            <button
              @click="showCreateItemModal = true"
              class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
            >
              + Add Item
            </button>
          </div>

          <div v-if="loadingItems" class="text-center py-8">Loading...</div>
          <div v-else-if="menuItems.length === 0" class="text-center py-8 text-gray-500">
            No items in this menu
          </div>
          <div v-else class="space-y-3">
            <div
              v-for="item in menuItems"
              :key="item.id"
              class="flex justify-between items-start p-4 border border-gray-200 rounded-lg hover:shadow-md transition"
            >
              <div class="flex-1">
                <h3 class="font-semibold text-lg">{{ item.name }}</h3>
                <p class="text-gray-600 text-sm mt-1">{{ item.description || 'No description' }}</p>
                <div class="flex items-center space-x-4 mt-2">
                  <span class="font-bold text-blue-600">{{ item.price }} EGP</span>
                  <span
                    :class="[
                      'text-xs px-2 py-1 rounded',
                      item.is_available
                        ? 'bg-green-100 text-green-800'
                        : 'bg-red-100 text-red-800'
                    ]"
                  >
                    {{ item.is_available ? 'Available' : 'Unavailable' }}
                  </span>
                </div>
              </div>
              <div class="flex space-x-2">
                <button
                  @click="editItem(item)"
                  class="bg-yellow-600 text-white px-3 py-1 rounded text-sm hover:bg-yellow-700"
                >
                  Edit
                </button>
                <button
                  @click="deleteItem(item.id)"
                  class="bg-red-600 text-white px-3 py-1 rounded text-sm hover:bg-red-700"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Create/Edit Menu Modal -->
    <div
      v-if="showCreateMenuModal || editingMenu"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click="closeMenuModal"
    >
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 shadow-xl" @click.stop>
        <h2 class="text-xl font-semibold mb-4 text-gray-800">
          {{ editingMenu ? 'Edit Menu' : 'Add Menu' }}
        </h2>
        <form @submit.prevent="saveMenu" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Menu Name</label>
            <input
              v-model="newMenu.name"
              type="text"
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-green-500"
            />
          </div>
          <div>
            <label class="flex items-center">
              <input
                v-model="newMenu.is_active"
                type="checkbox"
                class="mr-2"
              />
              <span class="text-sm text-gray-700">Active</span>
            </label>
          </div>
          <div class="flex space-x-2">
            <button
              type="button"
              @click="closeMenuModal"
              class="flex-1 bg-gray-200 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="creatingMenu"
              class="flex-1 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 transition-colors"
            >
              {{ creatingMenu ? (editingMenu ? 'Updating...' : 'Creating...') : (editingMenu ? 'Update' : 'Create') }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Create/Edit Item Modal -->
    <div
      v-if="showCreateItemModal || editingItem"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click="closeItemModal"
    >
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4" @click.stop>
        <h2 class="text-xl font-semibold mb-4">
          {{ editingItem ? 'Edit Item' : 'Add Menu Item' }}
        </h2>
        <form @submit.prevent="saveItem" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Item Name</label>
            <input
              v-model="newItem.name"
              type="text"
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Description</label>
            <textarea
              v-model="newItem.description"
              rows="3"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md"
            ></textarea>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Price (EGP)</label>
            <input
              v-model.number="newItem.price"
              type="number"
              step="0.01"
              min="0"
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md"
            />
          </div>
          <div>
            <label class="flex items-center">
              <input
                v-model="newItem.is_available"
                type="checkbox"
                class="mr-2"
              />
              <span class="text-sm text-gray-700">Available</span>
            </label>
          </div>
          <div class="flex space-x-2">
            <button
              type="button"
              @click="closeItemModal"
              class="flex-1 bg-gray-200 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-300"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="savingItem"
              class="flex-1 bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50"
            >
              {{ savingItem ? 'Saving...' : (editingItem ? 'Update' : 'Create') }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useOrdersStore } from '../stores/orders'
import api from '../api'

const route = useRoute()
const router = useRouter()
const ordersStore = useOrdersStore()

const restaurant = ref(null)
const menus = ref([])
const selectedMenu = ref(null)
const menuItems = ref([])
const loading = ref(false)
const loadingItems = ref(false)
const showCreateMenuModal = ref(false)
const creatingMenu = ref(false)
const editingMenu = ref(null)
const showCreateItemModal = ref(false)
const editingItem = ref(null)
const savingItem = ref(false)

const newMenu = ref({
  name: '',
  is_active: true,
})

const newItem = ref({
  name: '',
  description: '',
  price: 0,
  is_available: true,
})

onMounted(async () => {
  await loadData()
})

async function loadData() {
  loading.value = true
  const restaurantId = route.params.restaurantId
  
  try {
    // Fetch restaurant
    const restaurantResponse = await api.get(`/restaurants/${restaurantId}/`)
    restaurant.value = restaurantResponse.data
    
    // Fetch menus
    await loadMenus()
  } catch (error) {
    console.error('Failed to load restaurant:', error)
  }
  loading.value = false
}

async function loadMenus() {
  try {
    const response = await api.get('/menus/', {
      params: { restaurant: route.params.restaurantId }
    })
    menus.value = response.data.results || response.data
  } catch (error) {
    console.error('Failed to load menus:', error)
  }
}

async function selectMenu(menu) {
  selectedMenu.value = menu
  loadingItems.value = true
  try {
    const response = await api.get('/menu-items/', {
      params: { menu: menu.id }
    })
    menuItems.value = response.data.results || response.data
  } catch (error) {
    console.error('Failed to load menu items:', error)
  }
  loadingItems.value = false
}

function editMenu(menu) {
  editingMenu.value = menu
  newMenu.value = {
    name: menu.name,
    is_active: menu.is_active,
  }
}

function closeMenuModal() {
  showCreateMenuModal.value = false
  editingMenu.value = null
  newMenu.value = { name: '', is_active: true }
}

async function saveMenu() {
  creatingMenu.value = true
  try {
    if (editingMenu.value) {
      await api.patch(`/menus/${editingMenu.value.id}/`, newMenu.value)
    } else {
      await api.post('/menus/', {
        restaurant: route.params.restaurantId,
        name: newMenu.value.name,
        is_active: newMenu.value.is_active,
      })
    }
    await loadMenus()
    closeMenuModal()
  } catch (error) {
    alert('Failed to save menu: ' + (error.response?.data?.detail || JSON.stringify(error.response?.data)))
  }
  creatingMenu.value = false
}

async function deleteMenu(menuId) {
  if (!confirm('Are you sure you want to delete this menu? This will also delete all menu items. This action cannot be undone.')) {
    return
  }
  
  try {
    await api.delete(`/menus/${menuId}/`)
    await loadMenus()
    if (selectedMenu.value?.id === menuId) {
      selectedMenu.value = null
      menuItems.value = []
    }
  } catch (error) {
    alert('Failed to delete menu: ' + (error.response?.data?.detail || JSON.stringify(error.response?.data)))
  }
}

async function saveItem() {
  savingItem.value = true
  try {
    if (editingItem.value) {
      // Update existing item
      await api.patch(`/menu-items/${editingItem.value.id}/`, newItem.value)
    } else {
      // Create new item
      await api.post('/menu-items/', {
        menu: selectedMenu.value.id,
        ...newItem.value,
      })
    }
    await selectMenu(selectedMenu.value)
    closeItemModal()
  } catch (error) {
    alert('Failed to save item: ' + (error.response?.data?.detail || JSON.stringify(error.response?.data)))
  }
  savingItem.value = false
}

function editItem(item) {
  editingItem.value = item
  newItem.value = {
    name: item.name,
    description: item.description || '',
    price: item.price,
    is_available: item.is_available,
  }
}

async function deleteItem(itemId) {
  if (!confirm('Are you sure you want to delete this item?')) return
  
  try {
    await api.delete(`/menu-items/${itemId}/`)
    await selectMenu(selectedMenu.value)
  } catch (error) {
    alert('Failed to delete item')
  }
}

function closeItemModal() {
  showCreateItemModal.value = false
  editingItem.value = null
  newItem.value = {
    name: '',
    description: '',
    price: 0,
    is_available: true,
  }
}
</script>

