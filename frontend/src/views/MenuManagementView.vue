<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-6">
      <button
        @click="$router.push('/restaurants')"
        class="text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-blue-300 mb-4"
      >
        ← Back to Restaurants
      </button>
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">{{ restaurant?.name || 'Menu Management' }}</h1>
      <p class="text-gray-600 dark:text-gray-400 mt-2">{{ restaurant?.description || '' }}</p>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Menus List -->
      <div class="lg:col-span-1 space-y-4">
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-4">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-lg font-semibold dark:text-white">Menus</h2>
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
                  ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/30 dark:border-blue-400'
                  : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-500'
              ]"
            >
              <div class="flex justify-between items-center mb-2">
                <span
                  @click="selectMenu(menu)"
                  class="font-medium cursor-pointer flex-1 dark:text-white"
                >
                  {{ menu.name }}
                </span>
                <span
                  :class="[
                    'text-xs px-2 py-1 rounded',
                    menu.is_active ? 'bg-green-100 dark:bg-green-900/40 text-green-800 dark:text-green-300' : 'bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-300'
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
        <div v-if="!selectedMenu" class="bg-white dark:bg-gray-800 rounded-lg shadow p-8 text-center text-gray-500 dark:text-gray-400">
          Select a menu to manage items
        </div>
        <div v-else class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-4">
            <div>
              <h2 class="text-xl font-semibold dark:text-white">
                {{ selectedMenu.name }} Items
                <span class="text-sm font-normal text-gray-500 dark:text-gray-400 ml-1">({{ menuItems.length }})</span>
              </h2>
              <p v-if="selectedMenu.last_synced_at" class="text-xs mt-0.5" :class="pricesAreStale ? 'text-amber-600 dark:text-amber-400' : 'text-gray-400 dark:text-gray-500'">
                <span v-if="pricesAreStale">⚠ </span>Prices last synced {{ syncedLabel }}
              </p>
            </div>
            <button
              @click="showCreateItemModal = true"
              class="bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700 shrink-0"
            >
              + Add Item
            </button>
          </div>

          <!-- Search bar -->
          <div v-if="menuItems.length > 0" class="mb-4">
            <input
              v-model="itemSearch"
              type="text"
              placeholder="Search items…"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
            />
          </div>

          <div v-if="loadingItems" class="text-center py-8 text-gray-600 dark:text-gray-400">Loading...</div>
          <div v-else-if="menuItems.length === 0" class="text-center py-8 text-gray-500 dark:text-gray-400">
            No items in this menu
          </div>
          <div v-else-if="groupedMenuItems.length === 0" class="text-center py-6 text-gray-500 dark:text-gray-400 text-sm">
            No items match "{{ itemSearch }}"
          </div>
          <div v-else class="space-y-6">
            <div v-for="section in groupedMenuItems" :key="section.name">
              <!-- Section header -->
              <div class="flex items-center gap-2 mb-2">
                <span class="text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">{{ section.name }}</span>
                <div class="flex-1 h-px bg-gray-200 dark:bg-gray-700"></div>
                <span class="text-xs text-gray-400 dark:text-gray-500">{{ section.items.length }}</span>
              </div>
              <div class="space-y-2">
                <div
                  v-for="item in section.items"
                  :key="item.id"
                  class="flex justify-between items-start p-4 border border-gray-200 dark:border-gray-700 rounded-lg hover:shadow-md transition"
                >
                  <!-- Thumbnail -->
                  <img
                    v-if="item.image_url"
                    :src="item.image_url"
                    :alt="item.name"
                    class="w-14 h-14 object-cover rounded-lg shrink-0 mr-3 bg-gray-100 dark:bg-gray-700"
                    loading="lazy"
                    @error="$event.target.style.display='none'"
                  />
                  <div class="flex-1 min-w-0">
                    <h3 class="font-semibold dark:text-white">{{ item.name }}</h3>
                    <p class="text-gray-600 dark:text-gray-400 text-sm mt-1">{{ item.description || '' }}</p>
                    <div class="flex items-center space-x-4 mt-2">
                      <span class="font-bold text-indigo-600 dark:text-indigo-400">{{ item.price }} EGP</span>
                      <span
                        :class="[
                          'text-xs px-2 py-1 rounded',
                          item.is_available
                            ? 'bg-green-100 dark:bg-green-900/40 text-green-800 dark:text-green-300'
                            : 'bg-red-100 dark:bg-red-900/40 text-red-800 dark:text-red-300'
                        ]"
                      >
                        {{ item.is_available ? 'Available' : 'Unavailable' }}
                      </span>
                    </div>
                  </div>
                  <div class="flex space-x-2 ml-4">
                    <button
                      @click="openOptions(item)"
                      class="bg-indigo-600 text-white px-3 py-1 rounded text-sm hover:bg-indigo-700"
                    >
                      Options<span v-if="item.option_groups?.length"> ({{ item.option_groups.length }})</span>
                    </button>
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
      </div>
    </div>

    <!-- Create/Edit Menu Modal -->
    <div
      v-if="showCreateMenuModal || editingMenu"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click="closeMenuModal"
    >
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4 shadow-xl" @click.stop>
        <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">
          {{ editingMenu ? 'Edit Menu' : 'Add Menu' }}
        </h2>
        <form @submit.prevent="saveMenu" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Menu Name</label>
            <input
              v-model="newMenu.name"
              type="text"
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-green-500 dark:bg-gray-700 dark:text-white"
            />
          </div>
          <div>
            <label class="flex items-center">
              <input
                v-model="newMenu.is_active"
                type="checkbox"
                class="mr-2"
              />
              <span class="text-sm text-gray-700 dark:text-gray-300">Active</span>
            </label>
          </div>
          <div class="flex space-x-2">
            <button
              type="button"
              @click="closeMenuModal"
              class="flex-1 bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-200 px-4 py-2 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
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
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4" @click.stop>
        <h2 class="text-xl font-semibold mb-4 dark:text-white">
          {{ editingItem ? 'Edit Item' : 'Add Menu Item' }}
        </h2>
        <form @submit.prevent="saveItem" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Item Name</label>
            <input
              v-model="newItem.name"
              type="text"
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Description</label>
            <textarea
              v-model="newItem.description"
              rows="3"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
            ></textarea>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Price (EGP)</label>
            <input
              v-model.number="newItem.price"
              type="number"
              step="0.01"
              min="0"
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
            />
          </div>
          <div>
            <label class="flex items-center">
              <input
                v-model="newItem.is_available"
                type="checkbox"
                class="mr-2"
              />
              <span class="text-sm text-gray-700 dark:text-gray-300">Available</span>
            </label>
          </div>
          <div class="flex space-x-2">
            <button
              type="button"
              @click="closeItemModal"
              class="flex-1 bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-200 px-4 py-2 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="savingItem"
              class="flex-1 bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700 disabled:opacity-50"
            >
              {{ savingItem ? 'Saving...' : (editingItem ? 'Update' : 'Create') }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Manage Options Modal -->
    <div
      v-if="optionsItem"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
      @click="closeOptions"
    >
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-lg w-full max-h-[90vh] overflow-y-auto" @click.stop>
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold dark:text-white">Options — {{ optionsItem.name }}</h2>
          <button @click="closeOptions" class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 text-2xl leading-none">&times;</button>
        </div>

        <!-- Existing groups -->
        <div v-if="!optionsItem.option_groups?.length" class="text-sm text-gray-500 dark:text-gray-400 mb-4">
          No option groups yet. Add one below (e.g. "Size" or "Add-ons").
        </div>
        <div v-for="group in optionsItem.option_groups || []" :key="group.id" class="border border-gray-200 dark:border-gray-700 rounded-lg p-3 mb-3">
          <div class="flex items-center justify-between">
            <div>
              <span class="font-medium dark:text-white">{{ group.name }}</span>
              <span class="text-xs text-gray-500 dark:text-gray-400 ml-2">
                {{ group.is_required ? 'Required' : 'Optional' }} ·
                {{ group.max_select === 1 ? 'single choice' : `up to ${group.max_select}` }}
              </span>
            </div>
            <button @click="deleteGroup(group.id)" class="text-red-600 hover:text-red-700 text-sm">Delete</button>
          </div>

          <!-- Options within the group -->
          <div class="mt-2 space-y-1">
            <div v-for="opt in group.options || []" :key="opt.id" class="flex items-center justify-between text-sm bg-gray-50 dark:bg-gray-700/50 rounded px-2 py-1">
              <span class="dark:text-gray-200">
                {{ opt.name }}
                <span class="text-gray-500 dark:text-gray-400">
                  {{ parseFloat(opt.price_delta) > 0 ? '+' : '' }}{{ opt.price_delta }} EGP
                </span>
                <span v-if="opt.is_default" class="text-xs text-indigo-600 dark:text-indigo-400 ml-1">(default)</span>
                <span v-if="!opt.is_available" class="text-xs text-red-500 ml-1">(unavailable)</span>
              </span>
              <button @click="deleteOption(opt.id, optionsItem.id)" class="text-red-500 hover:text-red-600">Remove</button>
            </div>
          </div>

          <!-- Add option to this group -->
          <div class="flex gap-2 mt-2">
            <input v-model="optionDrafts[group.id].name" placeholder="Option name" class="flex-1 px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded dark:bg-gray-700 dark:text-white" />
            <input v-model.number="optionDrafts[group.id].price_delta" type="number" step="0.01" placeholder="±price" class="w-24 px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded dark:bg-gray-700 dark:text-white" />
            <button @click="addOption(group)" :disabled="!optionDrafts[group.id].name" class="bg-green-600 text-white px-3 py-1 rounded text-sm hover:bg-green-700 disabled:opacity-50">Add</button>
          </div>
        </div>

        <!-- Add a new group -->
        <div class="border-t dark:border-gray-700 pt-3 mt-3">
          <p class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Add option group</p>
          <div class="space-y-2">
            <input v-model="newGroup.name" placeholder="Group name (e.g. Size)" class="w-full px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded dark:bg-gray-700 dark:text-white" />
            <div class="flex items-center gap-4 text-sm">
              <label class="flex items-center gap-1 dark:text-gray-300">
                <input v-model="newGroup.is_required" type="checkbox" /> Required
              </label>
              <label class="flex items-center gap-1 dark:text-gray-300">
                Max choices
                <input v-model.number="newGroup.max_select" type="number" min="1" class="w-16 px-2 py-1 border border-gray-300 dark:border-gray-600 rounded dark:bg-gray-700 dark:text-white" />
              </label>
            </div>
            <button @click="addGroup" :disabled="!newGroup.name || savingGroup" class="bg-indigo-600 text-white px-4 py-2 rounded text-sm hover:bg-indigo-700 disabled:opacity-50">
              {{ savingGroup ? 'Adding...' : 'Add Group' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useOrdersStore } from '../stores/orders'
import api from '../api'
import { useToast } from '../composables/useToast'
import { useConfirm } from '../composables/useConfirm'

const toast = useToast()
const { confirm: $confirm } = useConfirm()

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
const itemSearch = ref('')

const groupedMenuItems = computed(() => {
  const q = itemSearch.value.toLowerCase()
  const filtered = menuItems.value.filter(item =>
    !q || item.name.toLowerCase().includes(q) || (item.section_name || '').toLowerCase().includes(q)
  )
  const sectionMap = {}
  for (const item of filtered) {
    const sec = item.section_name || 'Other'
    if (!sectionMap[sec]) sectionMap[sec] = []
    sectionMap[sec].push(item)
  }
  return Object.entries(sectionMap).map(([name, items]) => ({ name, items }))
})

// Relative "synced X ago" label + a staleness flag for the base-price
// accuracy hint (Talabat sync can drift from the shop's real prices).
const STALE_AFTER_MS = 14 * 24 * 60 * 60 * 1000  // 2 weeks
const syncedLabel = computed(() => {
  const ts = selectedMenu.value?.last_synced_at
  if (!ts) return ''
  const diff = Date.now() - new Date(ts).getTime()
  const days = Math.floor(diff / (24 * 60 * 60 * 1000))
  if (days >= 1) return `${days} day${days === 1 ? '' : 's'} ago`
  const hours = Math.floor(diff / (60 * 60 * 1000))
  if (hours >= 1) return `${hours} hour${hours === 1 ? '' : 's'} ago`
  return 'recently'
})
const pricesAreStale = computed(() => {
  const ts = selectedMenu.value?.last_synced_at
  return ts ? (Date.now() - new Date(ts).getTime()) > STALE_AFTER_MS : false
})

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
    toast.error('Failed to save menu: ' + (error.response?.data?.detail || JSON.stringify(error.response?.data)))
  }
  creatingMenu.value = false
}

async function deleteMenu(menuId) {
  if (!(await $confirm('Are you sure you want to delete this menu? This will also delete all menu items. This action cannot be undone.', 'Delete Menu'))) return

  try {
    await api.delete(`/menus/${menuId}/`)
    await loadMenus()
    if (selectedMenu.value?.id === menuId) {
      selectedMenu.value = null
      menuItems.value = []
    }
  } catch (error) {
    toast.error('Failed to delete menu: ' + (error.response?.data?.detail || JSON.stringify(error.response?.data)))
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
    toast.error('Failed to save item: ' + (error.response?.data?.detail || JSON.stringify(error.response?.data)))
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
  if (!(await $confirm('Are you sure you want to delete this item?', 'Delete Item'))) return

  try {
    await api.delete(`/menu-items/${itemId}/`)
    await selectMenu(selectedMenu.value)
  } catch (error) {
    toast.error('Failed to delete item')
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

// ── Option groups / options management ───────────────────────────
const optionsItem = ref(null)
const optionDrafts = ref({})  // { [groupId]: { name, price_delta } }
const newGroup = ref({ name: '', is_required: false, max_select: 1 })
const savingGroup = ref(false)

// Ensure every current group has an "add option" draft the template can bind to.
function initOptionDrafts() {
  const drafts = {}
  for (const g of optionsItem.value?.option_groups || []) {
    drafts[g.id] = optionDrafts.value[g.id] || { name: '', price_delta: 0 }
  }
  optionDrafts.value = drafts
}

function openOptions(item) {
  optionsItem.value = item
  newGroup.value = { name: '', is_required: false, max_select: 1 }
  initOptionDrafts()
}

function closeOptions() {
  optionsItem.value = null
  optionDrafts.value = {}
}

// Re-fetch the menu (which nests option_groups) and re-point the modal at the
// refreshed item so newly added/removed groups and options render.
async function reloadOptions(itemId) {
  await selectMenu(selectedMenu.value)
  optionsItem.value = menuItems.value.find(i => i.id === itemId) || null
  initOptionDrafts()
}

async function addGroup() {
  if (!newGroup.value.name) return
  savingGroup.value = true
  const itemId = optionsItem.value.id
  try {
    await api.post('/menu-item-option-groups/', {
      menu_item: itemId,
      name: newGroup.value.name,
      is_required: newGroup.value.is_required,
      min_select: newGroup.value.is_required ? 1 : 0,
      max_select: Math.max(1, newGroup.value.max_select || 1),
    })
    newGroup.value = { name: '', is_required: false, max_select: 1 }
    await reloadOptions(itemId)
  } catch (error) {
    toast.error('Failed to add group: ' + (error.response?.data?.detail || JSON.stringify(error.response?.data)))
  }
  savingGroup.value = false
}

async function deleteGroup(groupId) {
  if (!(await $confirm('Delete this option group and all its options?', 'Delete Group'))) return
  const itemId = optionsItem.value.id
  try {
    await api.delete(`/menu-item-option-groups/${groupId}/`)
    await reloadOptions(itemId)
  } catch (error) {
    toast.error('Failed to delete group')
  }
}

async function addOption(group) {
  const draft = optionDrafts.value[group.id]
  if (!draft?.name) return
  const itemId = optionsItem.value.id
  try {
    await api.post('/menu-item-options/', {
      group: group.id,
      name: draft.name,
      price_delta: draft.price_delta || 0,
    })
    await reloadOptions(itemId)
  } catch (error) {
    toast.error('Failed to add option: ' + (error.response?.data?.detail || JSON.stringify(error.response?.data)))
  }
}

async function deleteOption(optionId, itemId) {
  try {
    await api.delete(`/menu-item-options/${optionId}/`)
    await reloadOptions(itemId)
  } catch (error) {
    toast.error('Failed to delete option')
  }
}
</script>

