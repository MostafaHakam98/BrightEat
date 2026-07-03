<template>
  <div
    class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8"
    :class="currentOrder && canManage ? 'pb-28 md:pb-8' : ''"
  >
    <div v-if="loading" class="text-center py-8">
      <p class="text-lg text-gray-900 dark:text-white">Loading order...</p>
      <p class="text-sm text-gray-500 dark:text-gray-400 mt-2">Code: {{ route.params.code }}</p>
    </div>
    <div v-else-if="error" class="text-center py-8">
      <p class="text-red-600 dark:text-red-400 text-lg mb-4">{{ error }}</p>
      <button
        @click="loadOrder()"
        class="bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 mr-2"
      >
        Retry
      </button>
      <button
        @click="router.push('/orders')"
        class="bg-gray-600 dark:bg-gray-500 text-white px-4 py-2 rounded-md hover:bg-gray-700 dark:hover:bg-gray-600"
      >
        Back to Orders
      </button>
    </div>
    <div v-else-if="!currentOrder" class="text-center py-8 text-gray-500 dark:text-gray-400">
      <p class="text-lg mb-4">Order not found</p>
      <button
        @click="loadOrder()"
        class="bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 mr-2"
      >
        Retry
      </button>
      <button
        @click="router.push('/orders')"
        class="bg-gray-600 dark:bg-gray-500 text-white px-4 py-2 rounded-md hover:bg-gray-700 dark:hover:bg-gray-600"
      >
        Back to Orders
      </button>
    </div>
    <div v-else>
      <div class="mb-6" v-if="currentOrder">
        <button
          @click="router.push('/orders')"
          class="flex items-center gap-1.5 text-sm text-gray-500 dark:text-gray-400 hover:text-indigo-600 dark:hover:text-indigo-400 mb-4 transition-colors"
        >
          ← Back to Orders
        </button>
        <div class="flex justify-between items-start">
          <div>
            <h1 class="text-3xl font-bold text-gray-900 dark:text-white">{{ currentOrder?.restaurant_name || 'Unknown Restaurant' }}</h1>
            <p class="text-gray-600 dark:text-gray-400 mt-2 flex items-center gap-2">
              Code:
              <span class="font-mono font-semibold text-blue-600 dark:text-blue-400">{{ currentOrder?.code || 'N/A' }}</span>
              <button
                @click="copyCode"
                class="text-xs px-1.5 py-0.5 rounded border transition-colors"
                :class="codeCopied
                  ? 'border-green-400 text-green-600 dark:text-green-400'
                  : 'border-gray-300 dark:border-gray-600 text-gray-400 hover:text-blue-600 dark:hover:text-blue-400 hover:border-blue-400'"
              >{{ codeCopied ? '✓ Copied' : 'Copy' }}</button>
            </p>
            <p class="text-gray-600 dark:text-gray-400">Collector: <span class="font-semibold">{{ currentOrder?.collector_name || 'N/A' }}</span></p>
            <p v-if="currentOrder?.cutoff_time" class="text-gray-600 dark:text-gray-400">Cutoff: <span class="font-semibold">{{ formatCutoffTime(currentOrder.cutoff_time) }}</span></p>
            <p v-if="currentOrder?.assigned_users_details && currentOrder.assigned_users_details.length > 0" class="text-gray-600 dark:text-gray-400 mt-2">
              <span class="font-semibold">Assigned to:</span> 
              <span class="text-blue-600 dark:text-blue-400">{{ currentOrder.assigned_users_details.map(u => u.username).join(', ') }}</span>
            </p>
            <p v-if="currentOrder?.is_private" class="text-xs text-gray-500 dark:text-gray-400 mt-1">🔒 Private Order</p>
          </div>
          <div class="text-right">
            <BaseBadge :color="currentOrder?.status || 'gray'">
              {{ currentOrder?.status || 'UNKNOWN' }}
            </BaseBadge>
          </div>
        </div>
      </div>

      <!-- Order progress stepper -->
      <OrderStepper v-if="currentOrder" :order="currentOrder" class="mb-6" />

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6" v-if="currentOrder">
        <div class="lg:col-span-2 space-y-6">
          <!-- Assigned Users Notice -->
          <div v-if="currentOrder?.assigned_users_details && currentOrder.assigned_users_details.length > 0" class="bg-blue-50 dark:bg-blue-900/30 border border-blue-200 dark:border-blue-700 rounded-lg p-4">
            <p class="text-sm font-medium text-blue-900 dark:text-blue-300 mb-1">👥 Assigned Order</p>
            <p class="text-xs text-blue-700 dark:text-blue-400">This order is assigned to specific users. Only assigned users can join.</p>
            <p class="text-xs text-blue-600 dark:text-blue-400 mt-1">
              Assigned to: {{ currentOrder.assigned_users_details.map(u => u.username).join(', ') }}
            </p>
          </div>
          
          <!-- Who hasn't ordered yet (collector view, locked/ordered) -->
          <div
            v-if="usersWithoutItems.length > 0"
            class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700 rounded-lg p-4"
          >
            <p class="text-sm font-semibold text-amber-800 dark:text-amber-300 mb-1">
              ⚠ {{ usersWithoutItems.length }} participant{{ usersWithoutItems.length > 1 ? 's' : '' }} haven't added items yet
            </p>
            <p class="text-xs text-amber-700 dark:text-amber-400">
              {{ usersWithoutItems.map(u => u.username).join(', ') }}
            </p>
          </div>

          <!-- Add Items Section (only if OPEN) -->
          <div v-if="currentOrder?.status === 'OPEN'" class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200 dark:ring-gray-700 p-6">
            <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Add Items to Order</h2>
            <div class="space-y-4">
              <div>
                <div class="flex items-center justify-between gap-2 mb-2">
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Menu Item
                    <span v-if="currentOrder?.menu_name" class="text-xs text-gray-500 dark:text-gray-400 font-normal">
                      ({{ currentOrder.menu_name }})
                    </span>
                  </label>
                  <BaseButton
                    size="sm"
                    variant="secondary"
                    :loading="addingUsual"
                    title="Re-add the items from your last order at this restaurant"
                    @click="addMyUsual"
                  >
                    ⚡ Add my usual
                  </BaseButton>
                </div>

                <!-- Searchable section-grouped picker -->
                <div class="relative" ref="menuPickerRef">
                  <!-- Selected item display / search input -->
                  <div
                    class="w-full flex items-center border border-gray-300 dark:border-gray-600 rounded-md overflow-hidden"
                    :class="availableMenuItems.length === 0 ? 'opacity-60 cursor-not-allowed bg-gray-100 dark:bg-gray-700' : 'bg-white dark:bg-gray-700'"
                  >
                    <!-- Thumbnail of selected item -->
                    <img
                      v-if="selectedMenuItemObj?.image_url"
                      :src="selectedMenuItemObj.image_url"
                      :alt="selectedMenuItemObj.name"
                      class="w-9 h-9 object-cover ml-1 rounded shrink-0"
                      @error="$event.target.style.display='none'"
                    />
                    <input
                      v-model="menuItemSearch"
                      @focus="menuPickerOpen = true"
                      @input="menuPickerOpen = true"
                      :disabled="availableMenuItems.length === 0"
                      :placeholder="availableMenuItems.length === 0 ? 'No menu items available' : (selectedMenuItemLabel || 'Search menu items…')"
                      autocomplete="off"
                      class="flex-1 px-3 py-2 bg-transparent text-sm dark:text-white placeholder-gray-400 focus:outline-none disabled:cursor-not-allowed"
                    />
                    <button
                      v-if="selectedMenuItem"
                      type="button"
                      @click.prevent="clearMenuPicker"
                      class="px-2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 text-lg leading-none"
                      title="Clear selection"
                    >×</button>
                  </div>

                  <!-- Dropdown -->
                  <div
                    v-if="menuPickerOpen && filteredMenuSections.length"
                    class="absolute z-30 mt-1 w-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-md shadow-lg max-h-72 overflow-y-auto"
                  >
                    <div v-for="section in filteredMenuSections" :key="section.name">
                      <div class="px-3 py-1.5 text-xs font-semibold text-gray-500 dark:text-gray-400 bg-gray-50 dark:bg-gray-700/60 sticky top-0">
                        {{ section.name }}
                      </div>
                      <button
                        v-for="item in section.items"
                        :key="item.id"
                        type="button"
                        @mousedown.prevent="selectMenuPickerItem(item)"
                        class="w-full text-left px-3 py-2 text-sm hover:bg-blue-50 dark:hover:bg-gray-700 flex items-center gap-3"
                        :class="selectedMenuItem === item.id ? 'bg-blue-50 dark:bg-gray-700 text-blue-700 dark:text-blue-300 font-medium' : 'text-gray-800 dark:text-gray-100'"
                      >
                        <!-- Thumbnail -->
                        <img
                          v-if="item.image_url"
                          :src="item.image_url"
                          :alt="item.name"
                          class="w-10 h-10 object-cover rounded shrink-0 bg-gray-100 dark:bg-gray-700"
                          loading="lazy"
                          @error="$event.target.style.display='none'"
                        />
                        <div v-else class="w-10 h-10 rounded shrink-0 bg-gray-100 dark:bg-gray-700 flex items-center justify-center text-gray-400 text-xs">🍽️</div>
                        <span class="flex-1 min-w-0 truncate">{{ item.name }}</span>
                        <span class="text-gray-500 dark:text-gray-400 shrink-0">{{ item.price }} EGP</span>
                      </button>
                    </div>
                    <div v-if="menuItemSearch && !filteredMenuSections.length" class="px-4 py-3 text-sm text-gray-500 dark:text-gray-400">
                      No items match "{{ menuItemSearch }}"
                    </div>
                  </div>
                </div>

                <p v-if="availableMenuItems.length === 0" class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                  No menu items found for this order's menu. You can still add custom items below.
                </p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Assign to User
                  <span class="text-xs text-gray-500 dark:text-gray-400 font-normal">
                    ({{ selectedItemUser ? 'Assigned to ' + (allUsers.find(u => u.id === selectedItemUser)?.username || 'selected user') : 'You (default)' }})
                  </span>
                </label>
                <select
                  v-model="selectedItemUser"
                  :disabled="currentOrder?.collector !== authStore.user?.id && !authStore.isManager"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white disabled:bg-gray-100 dark:disabled:bg-gray-800 disabled:cursor-not-allowed"
                  @focus="ensureUsersLoaded"
                >
                  <option :value="null">Me ({{ authStore.user?.username }})</option>
                  <option v-for="user in allUsers" :key="user.id" :value="user.id">
                    {{ user.username }}
                  </option>
                </select>
                <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                  <span v-if="currentOrder?.collector === authStore.user?.id || authStore.isManager">
                    You can assign items to other users
                  </span>
                  <span v-else>
                    Only collectors and managers can assign items to other users
                  </span>
                </p>
              </div>
              <div class="flex space-x-2">
                <input
                  v-model.number="itemQuantity"
                  type="number"
                  min="1"
                  placeholder="Quantity"
                  class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                />
                <button
                  @click="addMenuItem"
                  :disabled="!selectedMenuItem || !itemQuantity"
                  class="bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 disabled:opacity-50"
                >
                  Add
                </button>
              </div>
              <div class="mt-2">
                <textarea
                  v-model="itemNote"
                  type="text"
                  placeholder="Add a note (e.g., no lettuce, extra sauce)"
                  rows="2"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white dark:placeholder-gray-400 text-sm"
                ></textarea>
                <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                  Optional: Add special instructions or modifications for this item
                </p>
              </div>
              <div class="border-t dark:border-gray-700 pt-4">
                <p class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Or add custom item:</p>
                <div class="space-y-2">
                  <div class="flex space-x-2">
                    <input
                      v-model="customItemName"
                      type="text"
                      placeholder="Item name"
                      class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                    />
                    <input
                      v-model.number="customItemPrice"
                      type="number"
                      step="0.01"
                      placeholder="Price"
                      class="w-24 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                    />
                    <button
                      @click="addCustomItem"
                      :disabled="!customItemName || !customItemPrice"
                      class="bg-green-600 dark:bg-green-500 text-white px-4 py-2 rounded-md hover:bg-green-700 dark:hover:bg-green-600 disabled:opacity-50"
                    >
                      Add Custom
                    </button>
                  </div>
                  <div>
                    <textarea
                      v-model="customItemNote"
                      type="text"
                      placeholder="Add a note (e.g., no lettuce, extra sauce)"
                      rows="2"
                      class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white dark:placeholder-gray-400 text-sm"
                    ></textarea>
                    <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                      Optional: Add special instructions or modifications for this item
                    </p>
                  </div>
                  <p class="text-xs text-gray-500 dark:text-gray-400">
                    Custom item will be assigned to: {{ selectedItemUser ? (allUsers.find(u => u.id === selectedItemUser)?.username || 'selected user') : authStore.user?.username }}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <!-- Order Items -->
          <div class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200 dark:ring-gray-700 p-6">
            <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Order Items</h2>
            <div v-if="!currentOrder?.items || currentOrder.items.length === 0" class="text-gray-500 dark:text-gray-400 text-center py-4">
              No items yet. {{ currentOrder?.status === 'OPEN' ? 'Add items above!' : '' }}
            </div>
            <div v-else class="space-y-2">
              <div
                v-for="item in currentOrder.items"
                :key="item.id"
                :class="[
                  'flex justify-between items-center p-3 border rounded',
                  item.user === authStore.user?.id ? 'border-blue-300 dark:border-blue-600 bg-blue-50 dark:bg-blue-900/30' : 'border-gray-200 dark:border-gray-700'
                ]"
              >
                <div class="flex-1">
                  <div class="flex items-center space-x-2">
                    <p class="font-medium dark:text-white">{{ item.item_name }}</p>
                    <span v-if="item.user === authStore.user?.id" class="text-xs bg-blue-600 dark:bg-blue-500 text-white px-2 py-0.5 rounded">
                      Your Item
                    </span>
                  </div>
                  <p class="text-sm text-gray-600 dark:text-gray-400">
                    {{ item.user_name }} — {{ formatPrice(item.unit_price) }} EGP × {{ item.quantity }}
                  </p>
                  <p v-if="item.note" class="text-sm text-gray-500 dark:text-gray-500 italic mt-1">
                    📝 Note: {{ item.note }}
                  </p>
                </div>
                <div class="flex items-center space-x-3">
                  <span class="font-semibold dark:text-white">{{ formatPrice(item.total_price) }} EGP</span>

                  <!-- Inline quantity +/- for own items when order is OPEN -->
                  <div
                    v-if="currentOrder?.status === 'OPEN' && item.user === authStore.user?.id"
                    class="flex items-center border border-gray-300 dark:border-gray-600 rounded overflow-hidden"
                  >
                    <button
                      type="button"
                      @click="adjustQuantity(item, -1)"
                      :disabled="updatingItem === item.id"
                      class="px-2 py-1 text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-40 font-bold"
                    >−</button>
                    <span class="px-2 text-sm font-medium dark:text-white min-w-[1.5rem] text-center">{{ item.quantity }}</span>
                    <button
                      type="button"
                      @click="adjustQuantity(item, +1)"
                      :disabled="updatingItem === item.id"
                      class="px-2 py-1 text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-40 font-bold"
                    >+</button>
                  </div>

                  <button
                    v-if="currentOrder?.status === 'OPEN' && (item.user === authStore.user?.id || currentOrder.collector === authStore.user?.id)"
                    @click="removeItem(item.id)"
                    class="bg-red-600 dark:bg-red-500 text-white px-3 py-1 rounded text-sm hover:bg-red-700 dark:hover:bg-red-600"
                    :title="item.user === authStore.user?.id ? 'Remove your item' : 'Remove item (collector)'"
                  >
                    ✕
                  </button>
                  <span v-if="currentOrder?.status !== 'OPEN'" class="text-xs text-gray-400 dark:text-gray-500">Locked</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Sidebar -->
        <div class="space-y-6">
          <!-- Order Summary -->
          <div class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200 dark:ring-gray-700 p-6">
            <h2 class="text-xl font-semibold mb-4 dark:text-white">Summary</h2>
            <div class="space-y-2 text-sm">
              <div class="flex justify-between dark:text-gray-300">
                <span>Items Total:</span>
                <span>{{ formatPrice(currentOrder?.total_items_cost) }} EGP</span>
              </div>
              <div class="flex justify-between dark:text-gray-300">
                <span>Delivery:</span>
                <span>{{ formatPrice(currentOrder?.delivery_fee) }} EGP</span>
              </div>
              <div class="flex justify-between dark:text-gray-300">
                <span>Tip:</span>
                <span>{{ formatPrice(currentOrder?.tip) }} EGP</span>
              </div>
              <div class="flex justify-between dark:text-gray-300">
                <span>Service:</span>
                <span>{{ formatPrice(currentOrder?.service_fee) }} EGP</span>
              </div>
              <div class="border-t dark:border-gray-700 pt-2 flex justify-between font-semibold dark:text-white">
                <span>Total:</span>
                <span>{{ formatPrice(currentOrder?.total_cost) }} EGP</span>
              </div>
            </div>
          </div>

          <!-- Role-aware actions (collector / manager) — one action area, no duplicates -->
          <OrderActionBar
            :order="currentOrder"
            :can-manage="canManage"
            :is-collector="isCollector"
            :can-delete="canDelete"
            :busy="loading"
            @lock="handleLockRequest"
            @unlock="unlockOrder"
            @mark-ordered="markOrdered"
            @close="closeOrder"
            @delete="deleteOrder"
            @transfer="handleTransferRequest"
          />

          <!-- Who's in -->
          <OrderRoster :order="currentOrder" />

          <!-- Fees & settings (collector only, while OPEN) -->
          <div v-if="currentOrder?.status === 'OPEN' && isCollector" class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200 dark:ring-gray-700 p-6">
            <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Fees & Settings</h2>
            <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
              <strong>How it works:</strong> You (the collector) pay the restaurant for everyone's items plus fees.
              Then each person pays you back their share. Use the fee split rules below to calculate how much each person owes.
            </p>
            <div class="space-y-2">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Fees</label>
                <input
                  v-model.number="fees.delivery_fee"
                  type="number"
                  step="0.01"
                  placeholder="Delivery Fee"
                  class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                />
                <input
                  v-model.number="fees.tip"
                  type="number"
                  step="0.01"
                  placeholder="Tip"
                  class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                />
                <input
                  v-model.number="fees.service_fee"
                  type="number"
                  step="0.01"
                  placeholder="Service Fee"
                  class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                />
                <select
                  v-model="fees.fee_split_rule"
                  class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 dark:bg-gray-700 dark:text-white"
                >
                  <option value="equal">Equal Split - Fees divided equally</option>
                  <option value="proportional">Proportional - Based on item cost</option>
                  <option value="collector_pays">Collector Pays - You pay all fees</option>
                  <option value="custom">Custom - Set exact amounts when locking</option>
                </select>
                <p class="text-xs text-gray-500 dark:text-gray-400 mt-1 mb-2">
                  <strong>Fee Split Rules:</strong><br>
                  • <strong>Equal:</strong> Fees split equally among everyone<br>
                  • <strong>Proportional:</strong> Fees split based on each person's item cost<br>
                  • <strong>Collector Pays:</strong> You pay all fees, others only pay for their items<br>
                  • <strong>Custom:</strong> You set each person's exact amount when locking
                </p>
                <input
                  v-model="fees.instapay_link"
                  type="url"
                  placeholder="Instapay Link"
                  class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                />
                <BaseButton block variant="secondary" @click="updateFees">
                  Update Fees
                </BaseButton>
              <!-- Assign Users Section (Compact) -->
              <div class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                <button
                  @click="toggleAssignUsers"
                  class="w-full flex items-center justify-between text-sm text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white py-2"
                >
                  <span class="flex items-center">
                    <span class="mr-2">👥</span>
                    <span>Assign to Specific Users</span>
                    <span v-if="currentOrder?.assigned_users_details?.length > 0" class="ml-2 text-xs bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300 px-2 py-0.5 rounded-full">
                      {{ currentOrder.assigned_users_details.length }}
                    </span>
                  </span>
                  <span class="text-gray-400 dark:text-gray-500">{{ showAssignUsers ? '▼' : '▶' }}</span>
                </button>
                <div v-if="showAssignUsers" class="mt-3 space-y-2 bg-gray-50 dark:bg-gray-700/50 p-3 rounded-md">
                  <p class="text-xs text-gray-600 dark:text-gray-400 mb-2">Select users for special orders (e.g., birthday cake). Order will be private.</p>
                  <div class="flex space-x-1 mb-2">
                    <button
                      type="button"
                      @click="selectAllUsers"
                      class="text-xs bg-white dark:bg-gray-600 hover:bg-gray-100 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-300 px-2 py-1 rounded border border-gray-300 dark:border-gray-500"
                    >
                      All
                    </button>
                    <button
                      type="button"
                      @click="deselectAllUsers"
                      class="text-xs bg-white dark:bg-gray-600 hover:bg-gray-100 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-300 px-2 py-1 rounded border border-gray-300 dark:border-gray-500"
                    >
                      None
                    </button>
                  </div>
                  <select
                    v-model="selectedUsers"
                    multiple
                    class="w-full text-sm px-2 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
                    size="4"
                  >
                    <option v-for="user in allUsers" :key="user.id" :value="user.id">
                      {{ user.username }}
                    </option>
                  </select>
                  <p v-if="selectedUsers.length > 0" class="text-xs text-blue-600 dark:text-blue-400 mt-1">
                    {{ selectedUsers.length }} selected
                  </p>
                  
                  <!-- Even Split Option -->
                  <div class="mt-3 pt-3 border-t border-gray-300 dark:border-gray-600">
                    <p class="text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">Optional: Split evenly among assigned users</p>
                    <div class="space-y-2">
                      <div>
                        <label class="block text-xs text-gray-600 dark:text-gray-400 mb-1">Number of items per user</label>
                        <input
                          v-model.number="assignmentItems"
                          type="number"
                          min="1"
                          placeholder="e.g., 2"
                          class="w-full text-sm px-2 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                        />
                      </div>
                      <div>
                        <label class="block text-xs text-gray-600 dark:text-gray-400 mb-1">Total cost (including delivery/fees)</label>
                        <input
                          v-model.number="assignmentTotalCost"
                          type="number"
                          step="0.01"
                          min="0"
                          placeholder="e.g., 500"
                          class="w-full text-sm px-2 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                        />
                      </div>
                      <p v-if="assignmentItems && assignmentTotalCost && selectedUsers.length > 0" class="text-xs text-green-600 dark:text-green-400 mt-1">
                        Each user will get {{ assignmentItems }} item(s) × {{ formatPrice(assignmentTotalCost / selectedUsers.length / assignmentItems) }} EGP = {{ formatPrice(assignmentTotalCost / selectedUsers.length) }} EGP per user
                      </p>
                    </div>
                  </div>
                  
                  <button
                    @click="updateAssignedUsers"
                    :disabled="loading || (assignmentItems && !assignmentTotalCost) || (assignmentTotalCost && !assignmentItems)"
                    class="w-full text-xs bg-blue-600 dark:bg-blue-500 text-white px-3 py-1.5 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 disabled:opacity-50 mt-3"
                  >
                    {{ loading ? 'Saving...' : 'Save Assignment' }}
                  </button>
                </div>
              </div>
              </div>
            </div>
          </div>

          <!-- Share Message -->
          <div class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200 dark:ring-gray-700 p-6">
            <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Share Message</h2>
            <textarea
              :value="currentOrder?.share_message || ''"
              readonly
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm dark:bg-gray-700 dark:text-white"
              rows="4"
            ></textarea>
            <div class="mt-2 flex gap-2">
              <button
                @click="copyShareMessage"
                class="flex-1 bg-green-600 dark:bg-green-500 text-white px-4 py-2 rounded-md hover:bg-green-700 dark:hover:bg-green-600"
              >
                Copy Message
              </button>
              <a
                v-if="currentOrder?.share_message"
                :href="`https://wa.me/?text=${encodeURIComponent(currentOrder.share_message)}`"
                target="_blank"
                rel="noopener noreferrer"
                class="flex items-center gap-1 bg-[#25D366] text-white px-4 py-2 rounded-md hover:bg-[#1da851] font-medium text-sm"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z"/>
                  <path d="M12 0C5.373 0 0 5.373 0 12c0 2.126.555 4.122 1.527 5.855L0 24l6.335-1.502A11.945 11.945 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22c-1.907 0-3.686-.497-5.234-1.37l-.377-.222-3.76.892.953-3.648-.246-.386A9.952 9.952 0 012 12c0-5.514 4.486-10 10-10s10 4.486 10 10-4.486 10-10 10z"/>
                </svg>
                WhatsApp
              </a>
            </div>
            <!-- Join QR code -->
            <div v-if="currentOrder?.join_url" class="mt-4 flex flex-col items-center gap-2">
              <p class="text-xs text-gray-500 dark:text-gray-400 font-medium">Scan to join</p>
              <canvas ref="joinQrCanvas" class="rounded border border-gray-200 dark:border-gray-600"></canvas>
            </div>
          </div>

          <!-- Payment Breakdown (if locked) -->
          <div v-if="currentOrder?.status !== 'OPEN' && currentOrder?.payments && currentOrder.payments.length > 0" class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200 dark:ring-gray-700 p-6">
            <h2 class="text-xl font-semibold mb-4 dark:text-white">Payment Breakdown</h2>
            <!-- Show message if only collector's payment exists and it's paid -->
            <div v-if="currentOrder.payments.length === 1 && currentOrder.payments[0].user === currentOrder?.collector && currentOrder.payments[0].is_paid" class="p-4 bg-green-50 dark:bg-green-900/30 border border-green-200 dark:border-green-700 rounded">
              <p class="text-sm text-gray-700 dark:text-gray-300">
                ✅ Your payment ({{ formatPrice(currentOrder.payments[0].amount) }} EGP) has been automatically marked as paid since you are the collector.
              </p>
            </div>
            <div v-else class="space-y-3">
              <!-- Shared hidden input for payment proof uploads -->
              <input
                ref="proofFileInput"
                type="file"
                accept="image/*"
                class="hidden"
                @change="onProofFileSelected"
              />
              <div
                v-for="payment in currentOrder.payments.filter(p => {
                  // Show all payments, but hide collector's payment only if it's paid and there are other payments
                  // If collector is ordering only for themselves, show their payment
                  if (p.user === currentOrder?.collector && p.is_paid && currentOrder.payments.length > 1) {
                    return false
                  }
                  return true
                })"
                :key="payment.id"
                :class="[
                  'p-3 border rounded',
                  payment.is_paid ? 'bg-green-50 dark:bg-green-900/30 border-green-200 dark:border-green-700' : 'bg-yellow-50 dark:bg-yellow-900/30 border-yellow-200 dark:border-yellow-700'
                ]"
              >
                <div class="flex items-center">
                  <div class="flex-1 min-w-0">
                    <p class="font-medium dark:text-white">{{ payment.user_name }}</p>
                    <p class="text-sm text-gray-600 dark:text-gray-400">
                      {{ payment.is_paid ? '✅ Paid' : '⏳ Pending' }}
                      <span v-if="payment.paid_at" class="ml-2 text-xs">
                        ({{ new Date(payment.paid_at).toLocaleString() }})
                      </span>
                    </p>
                  </div>
                  <div class="text-right mx-4 flex-shrink-0">
                    <p class="font-semibold text-lg dark:text-white whitespace-nowrap">{{ formatPrice(payment.amount) }} EGP</p>
                    <button
                      v-if="!payment.is_paid && currentOrder?.instapay_link && payment.user === authStore.user?.id"
                      @click="openInstapay"
                      class="mt-1 text-xs text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 underline"
                    >
                      Pay via Instapay
                    </button>
                  </div>
                  <BaseButton
                    v-if="!payment.is_paid && payment.user !== currentOrder?.collector && (currentOrder?.collector === authStore.user?.id || payment.user === authStore.user?.id)"
                    size="sm"
                    variant="success"
                    class="flex-shrink-0"
                    @click="markPaymentPaid(payment.id)"
                  >
                    {{ payment.user === authStore.user?.id ? 'Mark as Paid' : 'Mark Paid' }}
                  </BaseButton>
                </div>

                <!-- Proof status chip -->
                <div v-if="payment.proof_status === 'claimed' || payment.proof_status === 'rejected'" class="mt-2">
                  <BaseBadge :color="payment.proof_status === 'claimed' ? 'yellow' : 'red'">
                    {{ payment.proof_status === 'claimed' ? 'Proof uploaded — awaiting confirmation' : 'Proof rejected — re-upload' }}
                  </BaseBadge>
                </div>

                <!-- My payment: upload proof -->
                <div
                  v-if="payment.user === authStore.user?.id && !payment.is_paid && payment.proof_status !== 'claimed'"
                  class="mt-2"
                >
                  <BaseButton
                    size="sm"
                    variant="secondary"
                    :loading="uploadingProofFor === payment.id"
                    @click="triggerProofUpload(payment.id)"
                  >
                    📎 {{ payment.proof_status === 'rejected' ? 'Re-upload payment proof' : 'Upload payment proof' }}
                  </BaseButton>
                </div>

                <!-- Collector / manager: review claimed proof -->
                <div
                  v-if="canManage && payment.proof_status === 'claimed'"
                  class="mt-2 flex items-center gap-2"
                >
                  <a
                    v-if="payment.proof_image_url"
                    :href="payment.proof_image_url"
                    target="_blank"
                    rel="noopener noreferrer"
                    title="Open payment proof in a new tab"
                    class="shrink-0"
                  >
                    <img
                      :src="payment.proof_image_url"
                      alt="Payment proof"
                      class="w-10 h-10 rounded object-cover border border-gray-300 dark:border-gray-600"
                      @error="$event.target.style.display='none'"
                    />
                  </a>
                  <BaseButton
                    size="sm"
                    variant="success"
                    :loading="reviewingProofFor === payment.id"
                    @click="confirmProof(payment.id)"
                  >
                    Confirm
                  </BaseButton>
                  <BaseButton
                    size="sm"
                    variant="danger"
                    :disabled="reviewingProofFor === payment.id"
                    @click="rejectProof(payment.id)"
                  >
                    Reject
                  </BaseButton>
                </div>
              </div>
            </div>
            <div v-if="currentOrder?.instapay_link && currentOrder.collector === authStore.user?.id" class="mt-4 p-3 bg-blue-50 dark:bg-blue-900/30 rounded">
              <p class="text-sm font-medium mb-2 dark:text-white">Instapay Link:</p>
              <div class="flex items-center space-x-2">
                <input
                  :value="currentOrder.instapay_link"
                  readonly
                  class="flex-1 px-2 py-1 border border-gray-300 dark:border-gray-600 rounded text-sm dark:bg-gray-700 dark:text-white"
                />
                <button
                  @click="copyInstapayLink"
                  class="bg-blue-600 dark:bg-blue-500 text-white px-3 py-1 rounded text-sm hover:bg-blue-700 dark:hover:bg-blue-600"
                >
                  Copy
                </button>
              </div>
            </div>
          </div>

          <!-- Instapay QR Code (if locked/ordered/closed and collector has Instapay link or QR code) -->
          <div v-if="currentOrder?.status !== 'OPEN' && (currentOrder?.collector_instapay_link || currentOrder?.collector_instapay_qr_code_url)" class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200 dark:ring-gray-700 p-6">
            <h2 class="text-xl font-semibold mb-4 dark:text-white">Pay via Instapay</h2>
            <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">Scan the QR code below to pay {{ currentOrder?.collector_name }} via Instapay</p>
            <div class="flex flex-col items-center">
              <!-- Show uploaded QR code image if available, otherwise generate from link -->
              <img
                v-if="currentOrder?.collector_instapay_qr_code_url"
                :src="currentOrder.collector_instapay_qr_code_url"
                alt="Instapay QR Code"
                class="border border-gray-300 dark:border-gray-600 rounded mb-4 max-w-xs"
              />
              <canvas
                v-else-if="currentOrder?.collector_instapay_link"
                ref="instapayQrCanvas"
                class="border border-gray-300 dark:border-gray-600 rounded mb-4"
              ></canvas>
              <a
                v-if="currentOrder?.collector_instapay_link"
                :href="currentOrder.collector_instapay_link"
                target="_blank"
                class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 underline text-sm"
              >
                {{ currentOrder.collector_instapay_link }}
              </a>
              <button
                v-if="currentOrder?.collector_instapay_link"
                @click="copyCollectorInstapayLink"
                class="mt-2 px-4 py-2 bg-blue-600 dark:bg-blue-500 text-white rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 text-sm"
              >
                Copy Link
              </button>
            </div>
          </div>
          
          <!-- Receipt View (if ordered) -->
          <div v-if="currentOrder?.status === 'ORDERED' || currentOrder?.status === 'CLOSED'" class="bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200 dark:ring-gray-700 p-6">
            <h2 class="text-xl font-semibold mb-4 dark:text-white">Order Receipt</h2>
            <div class="space-y-2 text-sm">
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Restaurant:</span>
                <span>{{ currentOrder?.restaurant_name }}</span>
              </div>
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Order Code:</span>
                <span class="font-mono">{{ currentOrder?.code }}</span>
              </div>
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Items Total:</span>
                <span>{{ formatPrice(currentOrder?.total_items_cost) }} EGP</span>
              </div>
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Delivery:</span>
                <span>{{ formatPrice(currentOrder?.delivery_fee) }} EGP</span>
              </div>
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Tip:</span>
                <span>{{ formatPrice(currentOrder?.tip) }} EGP</span>
              </div>
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Service Fee:</span>
                <span>{{ formatPrice(currentOrder?.service_fee) }} EGP</span>
              </div>
              <div class="flex justify-between pt-2 font-bold text-lg dark:text-white">
                <span>Total:</span>
                <span>{{ formatPrice(currentOrder?.total_cost) }} EGP</span>
              </div>
            </div>
            <div class="mt-4 flex gap-2">
              <button
                @click="copyReceipt"
                class="flex-1 bg-gray-600 dark:bg-gray-500 text-white px-4 py-2 rounded-md hover:bg-gray-700 dark:hover:bg-gray-600"
              >
                Copy Receipt to Share
              </button>
              <button
                v-if="currentOrder?.collector === authStore.user?.id || authStore.isManager"
                @click="exportCSV"
                class="flex items-center gap-1 bg-emerald-600 dark:bg-emerald-500 text-white px-4 py-2 rounded-md hover:bg-emerald-700 dark:hover:bg-emerald-600 text-sm font-medium"
                title="Download order summary as CSV"
              >
                ⬇ CSV
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Add to Menu Prompt Modal -->
    <div
      v-if="showAddToMenuPrompt"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click="dismissAddToMenuPrompt"
    >
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4" @click.stop>
        <h2 class="text-xl font-semibold mb-4 dark:text-white">Add Item to Menu?</h2>
        <p class="text-gray-600 dark:text-gray-400 mb-4">
          Would you like to add "<strong class="dark:text-white">{{ promptItemName }}</strong>" to the menu permanently?
        </p>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Select Menu</label>
          <select
            v-model="selectedMenuForPrompt"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
          >
            <option v-for="menu in availableMenus" :key="menu.id" :value="menu.id">
              {{ menu.name }}
            </option>
          </select>
        </div>
        <div class="flex space-x-2">
          <button
            @click="handleAddToMenu"
            class="flex-1 bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600"
          >
            Yes, Add to Menu
          </button>
          <button
            @click="dismissAddToMenuPrompt"
            class="flex-1 bg-gray-300 dark:bg-gray-600 text-gray-800 dark:text-white px-4 py-2 rounded-md hover:bg-gray-400 dark:hover:bg-gray-500"
          >
            No, Keep as Custom
          </button>
        </div>
      </div>
    </div>

    <!-- Update Price Prompt Modal -->
    <div
      v-if="showUpdatePricePrompt"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click="dismissUpdatePricePrompt"
    >
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4" @click.stop>
        <h2 class="text-xl font-semibold mb-4 dark:text-white">Update Menu Item Price?</h2>
        <p class="text-gray-600 dark:text-gray-400 mb-4">
          The price for "<strong class="dark:text-white">{{ promptItemName }}</strong>" is different from the menu price.
          Would you like to update the menu item price to <strong class="dark:text-white">{{ formatPrice(promptItemPrice) }} EGP</strong>?
        </p>
        <div class="flex space-x-2">
          <button
            @click="handleUpdatePrice"
            class="flex-1 bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600"
          >
            Yes, Update Price
          </button>
          <button
            @click="dismissUpdatePricePrompt"
            class="flex-1 bg-gray-300 dark:bg-gray-600 text-gray-800 dark:text-white px-4 py-2 rounded-md hover:bg-gray-400 dark:hover:bg-gray-500"
          >
            No, Keep Current Price
          </button>
        </div>
      </div>
    </div>

    <!-- Custom fee split: collect per-participant amounts before locking -->
    <CustomSplitModal
      :open="showCustomSplitModal"
      :order="currentOrder"
      @close="showCustomSplitModal = false"
      @locked="onCustomSplitLocked"
    />
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed, watch, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useOrdersStore } from '../stores/orders'
import { useAuthStore } from '../stores/auth'
import { useWebSocketStore } from '../stores/websocket'
import { useToast } from '../composables/useToast'
import { useConfirm } from '../composables/useConfirm'
import api from '../api'
import QRCode from 'qrcode'
import BaseButton from '../components/ui/BaseButton.vue'
import BaseBadge from '../components/ui/BaseBadge.vue'
import OrderStepper from '../components/order/OrderStepper.vue'
import OrderActionBar from '../components/order/OrderActionBar.vue'
import OrderRoster from '../components/order/OrderRoster.vue'
import CustomSplitModal from '../components/order/CustomSplitModal.vue'

const toast = useToast()
const { confirm: $confirm } = useConfirm()

const route = useRoute()
const router = useRouter()
const ordersStore = useOrdersStore()
const authStore = useAuthStore()
const wsStore = useWebSocketStore()

const loading = ref(true)
const error = ref(null)
const selectedMenuItem = ref('')
const itemQuantity = ref(1)
const itemNote = ref('')
const customItemName = ref('')
const customItemPrice = ref(0)
const customItemNote = ref('')
const selectedItemUser = ref(null) // User to assign the item to (null = current user)
const instapayQrCanvas = ref(null)
const joinQrCanvas = ref(null)
const transferCollectorId = ref('')
const showAssignUsers = ref(false)
const selectedUsers = ref([])
const allUsers = ref([])
const loadingUsers = ref(false)
const assignmentItems = ref(null)
const assignmentTotalCost = ref(null)
const fees = ref({
  delivery_fee: 0,
  tip: 0,
  service_fee: 0,
  fee_split_rule: 'equal',
  instapay_link: '',
})
// Prompt states
const showAddToMenuPrompt = ref(false)
const showUpdatePricePrompt = ref(false)
const promptItemId = ref(null)
const promptItemName = ref('')
const promptItemPrice = ref(0)
const promptExistingMenuItemId = ref(null)
const availableMenus = ref([])
const selectedMenuForPrompt = ref(null)

// Helper to get order from either computed or store directly
const order = computed(() => ordersStore.currentOrder)

// Always use this to get the order - it falls back to store if computed is null
const currentOrder = computed(() => {
  return order.value || ordersStore.currentOrder
})

// Role helpers for the single action area
const isCollector = computed(() => currentOrder.value?.collector === authStore.user?.id)
const canManage = computed(() => isCollector.value || authStore.isManager)
// Collectors can delete only OPEN orders; managers can delete any order
const canDelete = computed(() => authStore.isManager || (isCollector.value && currentOrder.value?.status === 'OPEN'))

// Custom fee split (lock interception)
const showCustomSplitModal = ref(false)

// Payment proof upload / review state
const proofFileInput = ref(null)
const proofUploadPaymentId = ref(null)
const uploadingProofFor = ref(null)
const reviewingProofFor = ref(null)

// "Add my usual" state
const addingUsual = ref(false)

const availableMenuItems = computed(() => {
  return ordersStore.menuItems.filter(item => item.is_available)
})

// Searchable section-grouped menu picker state
const menuItemSearch = ref('')
const menuPickerOpen = ref(false)
const menuPickerRef = ref(null)

const selectedMenuItemObj = computed(() =>
  selectedMenuItem.value ? availableMenuItems.value.find(i => i.id === selectedMenuItem.value) ?? null : null
)

const selectedMenuItemLabel = computed(() => {
  const item = selectedMenuItemObj.value
  return item ? `${item.name} — ${item.price} EGP` : ''
})

const filteredMenuSections = computed(() => {
  const q = menuItemSearch.value.toLowerCase()
  const items = availableMenuItems.value.filter(item =>
    !q || item.name.toLowerCase().includes(q) || (item.section_name || '').toLowerCase().includes(q)
  )
  const sectionMap = {}
  for (const item of items) {
    const sec = item.section_name || 'Other'
    if (!sectionMap[sec]) sectionMap[sec] = []
    sectionMap[sec].push(item)
  }
  return Object.entries(sectionMap).map(([name, items]) => ({ name, items }))
})

function selectMenuPickerItem(item) {
  selectedMenuItem.value = item.id
  menuItemSearch.value = ''
  menuPickerOpen.value = false
}

function clearMenuPicker() {
  selectedMenuItem.value = ''
  menuItemSearch.value = ''
  menuPickerOpen.value = false
}

function handleMenuPickerOutsideClick(e) {
  if (menuPickerRef.value && !menuPickerRef.value.contains(e.target)) {
    menuPickerOpen.value = false
  }
}

// Copy order code chip
const codeCopied = ref(false)
function copyCode() {
  const code = currentOrder.value?.code
  if (!code) return
  navigator.clipboard.writeText(code).then(() => {
    codeCopied.value = true
    setTimeout(() => { codeCopied.value = false }, 2000)
  })
}

// Who hasn't ordered yet — shown to the collector on LOCKED/ORDERED orders
const usersWithoutItems = computed(() => {
  const order = currentOrder.value
  if (!order || !['LOCKED', 'ORDERED'].includes(order.status)) return []
  if (order.collector !== authStore.user?.id) return []
  const usersWithItems = new Set((order.items || []).map(i => i.user))
  return (order.participants || []).filter(p => !usersWithItems.has(p.id))
})

// Helper function to format prices safely
function formatPrice(value) {
  if (value === null || value === undefined) return '0.00'
  const num = typeof value === 'string' ? parseFloat(value) : value
  return isNaN(num) ? '0.00' : num.toFixed(2)
}

// Helper function to format cutoff time in GMT+2
function formatCutoffTime(dateString) {
  if (!dateString) return 'N/A'
  const date = new Date(dateString)
  // Convert UTC to GMT+2 (Egypt timezone)
  const gmt2Date = new Date(date.getTime() + (2 * 60 * 60 * 1000))
  return gmt2Date.toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
    timeZone: 'Africa/Cairo'
  })
}

async function loadOrder() {
  loading.value = true
  error.value = null
  const code = route.params.code.toUpperCase()
  
  try {
    const result = await ordersStore.fetchOrderByCode(code)
    
    if (!result.success) {
      error.value = result.error?.detail || result.error?.error || 'Order not found'
      console.error('Failed to fetch order:', result.error)
      loading.value = false
      return
    }
    
    if (!ordersStore.currentOrder) {
      error.value = 'Order not found'
      loading.value = false
      return
    }
    
    
    // Verify order is set
    if (!ordersStore.currentOrder) {
      console.error('Order data not set in store after successful fetch')
      error.value = 'Order data not set in store'
      loading.value = false
      return
    }
    
    // Force reactivity update
    await new Promise(resolve => setTimeout(resolve, 0))
    
    // Fetch menu items for the order's menu
    try {
      // If order has a menu assigned, fetch items from that menu
      if (ordersStore.currentOrder.menu) {
        await ordersStore.fetchMenuItems(ordersStore.currentOrder.menu)
      } else {
        // Fallback: fetch menus for the restaurant and use the first one
        await ordersStore.fetchMenus(ordersStore.currentOrder.restaurant)
        
        if (ordersStore.menus.length > 0) {
          await ordersStore.fetchMenuItems(ordersStore.menus[0].id)
        } else {
          console.warn('No menus found for restaurant')
          ordersStore.menuItems = []
        }
      }
    } catch (menuError) {
      console.warn('Failed to load menus:', menuError)
      // Don't fail the whole page if menus fail to load
      ordersStore.menuItems = []
    }
    
    // Payments are already included in order.payments from the API
    
    // Set fees - ensure they're numbers
    if (ordersStore.currentOrder) {
      fees.value = {
        delivery_fee: parseFloat(ordersStore.currentOrder.delivery_fee) || 0,
        tip: parseFloat(ordersStore.currentOrder.tip) || 0,
        service_fee: parseFloat(ordersStore.currentOrder.service_fee) || 0,
        fee_split_rule: ordersStore.currentOrder.fee_split_rule || 'equal',
        instapay_link: ordersStore.currentOrder.instapay_link || '',
      }
      // Auto-fill preset when collector opens an order with all-zero fees
      if (ordersStore.currentOrder.status === 'OPEN' &&
          ordersStore.currentOrder.collector === authStore.user?.id) {
        const preset = loadFeePreset(ordersStore.currentOrder.restaurant)
        if (preset && fees.value.delivery_fee === 0 && fees.value.tip === 0 && fees.value.service_fee === 0) {
          fees.value = { ...fees.value, ...preset }
        }
      }
    }
    
    // Generate QR codes
    await nextTick()
    generateInstapayQR()
    generateJoinQR()
    
    // Load users for assignment (any user can assign) and for item assignment
    if (ordersStore.currentOrder) {
      await loadUsers()
      // Set current assigned users
      if (ordersStore.currentOrder.assigned_users_details) {
        selectedUsers.value = ordersStore.currentOrder.assigned_users_details.map(u => u.id)
      }
      
      // Connect to WebSocket for real-time updates
      wsStore.connect(ordersStore.currentOrder.id, (updatedOrder) => {
        
        // Update the order in the store - replace entire object to trigger reactivity
        ordersStore.currentOrder = updatedOrder
        
        // Update currentOrder ref - replace to trigger Vue reactivity
        currentOrder.value = updatedOrder
        
        // Update fees if they changed
        if (updatedOrder.delivery_fee !== undefined) {
          fees.value = {
            delivery_fee: parseFloat(updatedOrder.delivery_fee) || 0,
            tip: parseFloat(updatedOrder.tip) || 0,
            service_fee: parseFloat(updatedOrder.service_fee) || 0,
            fee_split_rule: updatedOrder.fee_split_rule || 'equal',
            instapay_link: updatedOrder.instapay_link || '',
          }
        }
        
        // Regenerate QR code if instapay link changed
        if (updatedOrder.collector_instapay_link) {
          nextTick(() => {
            generateInstapayQR()
          })
        }
      })
    }
  } catch (err) {
    console.error('Failed to load order:', err)
    error.value = 'Failed to load order: ' + (err.message || 'Unknown error')
  } finally {
    loading.value = false
  }
}

// --- Fee presets (localStorage, keyed by restaurant ID) ---
function loadFeePreset(restaurantId) {
  const raw = localStorage.getItem(`fee_preset_${restaurantId}`)
  return raw ? JSON.parse(raw) : null
}
function saveFeePreset(restaurantId, f) {
  localStorage.setItem(`fee_preset_${restaurantId}`, JSON.stringify({
    delivery_fee: f.delivery_fee,
    tip: f.tip,
    service_fee: f.service_fee,
    fee_split_rule: f.fee_split_rule,
  }))
}

// --- Simple canvas confetti ---
function launchConfetti() {
  const canvas = document.createElement('canvas')
  canvas.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:9999'
  document.body.appendChild(canvas)
  canvas.width = window.innerWidth
  canvas.height = window.innerHeight
  const ctx = canvas.getContext('2d')
  const colors = ['#6366F1','#10B981','#F59E0B','#EF4444','#8B5CF6','#EC4899','#14B8A6','#F97316']
  const pieces = Array.from({ length: 100 }, () => ({
    x: Math.random() * canvas.width, y: Math.random() * canvas.height - canvas.height,
    r: Math.random() * 6 + 4, d: Math.random() * 80,
    color: colors[Math.floor(Math.random() * colors.length)],
    tiltAngle: 0, tiltInc: Math.random() * 0.07 + 0.05,
  }))
  let angle = 0
  const start = Date.now()
  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    angle += 0.01
    pieces.forEach(p => {
      p.tiltAngle += p.tiltInc
      p.y += (Math.cos(angle + p.d) + 3 + p.r / 2) * 0.9
      p.x += Math.sin(angle) * 0.9
      ctx.beginPath()
      ctx.lineWidth = p.r / 2
      ctx.strokeStyle = p.color
      ctx.moveTo(p.x + Math.sin(p.tiltAngle) * 15 + p.r / 4, p.y)
      ctx.lineTo(p.x + Math.sin(p.tiltAngle) * 15, p.y + Math.sin(p.tiltAngle) * 15 + p.r / 4)
      ctx.stroke()
    })
    if (Date.now() - start < 2800) requestAnimationFrame(draw)
    else document.body.removeChild(canvas)
  }
  draw()
}

async function generateJoinQR() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (order?.join_url && joinQrCanvas.value) {
    try {
      await QRCode.toCanvas(joinQrCanvas.value, order.join_url, { width: 160, margin: 1 })
    } catch (e) { console.error('Join QR failed', e) }
  }
}

async function generateInstapayQR() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (order?.collector_instapay_link && instapayQrCanvas.value) {
    try {
      await QRCode.toCanvas(instapayQrCanvas.value, order.collector_instapay_link, {
        width: 250,
        margin: 2,
      })
    } catch (error) {
      console.error('Failed to generate QR code:', error)
    }
  }
}

function copyCollectorInstapayLink() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (order?.collector_instapay_link) {
    navigator.clipboard.writeText(order.collector_instapay_link)
    toast.success('Instapay link copied to clipboard!')
  }
}

let isLoading = false

onMounted(() => {
  if (!isLoading) {
    isLoading = true
    loadOrder().finally(() => {
      isLoading = false
    })
  }
  document.addEventListener('mousedown', handleMenuPickerOutsideClick)
})

// Watch for route changes (e.g., when code changes) - but only if not already loading
watch(() => route.params.code, (newCode, oldCode) => {
  if (newCode !== oldCode && !isLoading) {
    isLoading = true
    loadOrder().finally(() => {
      isLoading = false
    })
  }
})

// Watch for collector_instapay_link changes to regenerate QR code
watch(() => currentOrder.value?.collector_instapay_link, () => {
  nextTick(() => {
    generateInstapayQR()
  })
})

// Watch for join_url to regenerate join QR code whenever order updates
watch(() => currentOrder.value?.join_url, (newUrl) => {
  if (newUrl) {
    nextTick(() => {
      generateJoinQR()
    })
  }
})

// Disconnect WebSocket when component unmounts
onUnmounted(() => {
  wsStore.disconnect()
  document.removeEventListener('mousedown', handleMenuPickerOutsideClick)
})

async function addMenuItem() {
  if (!selectedMenuItem.value || !itemQuantity.value) {
    toast.warning('Please select an item and quantity')
    return
  }

  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (order.status !== 'OPEN') {
    toast.warning('This order is locked and cannot be modified')
    return
  }

  // Check if user is trying to assign to someone else but doesn't have permission
  if (selectedItemUser.value && order.collector !== authStore.user?.id && !authStore.isManager) {
    toast.warning('Only collectors and managers can assign items to other users')
    return
  }

  const wasLoading = loading.value
  loading.value = true
  try {
    const itemData = {
      order: order.id,
      menu_item: selectedMenuItem.value,
      quantity: itemQuantity.value,
    }

    // Add note if provided
    if (itemNote.value && itemNote.value.trim()) {
      itemData.note = itemNote.value.trim()
    }

    // Add user if specified and user has permission
    if (selectedItemUser.value && (order.collector === authStore.user?.id || authStore.isManager)) {
      itemData.user = selectedItemUser.value
    }

    const result = await ordersStore.addOrderItem(itemData)
    
    if (result.success) {
      selectedMenuItem.value = ''
      menuItemSearch.value = ''
      itemQuantity.value = 1
      itemNote.value = ''
      selectedItemUser.value = null
      // Don't manually refetch - WebSocket will broadcast the update automatically
      // await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
      // Regenerate QR code if needed
      await nextTick()
      generateInstapayQR()
    } else {
      const errorMsg = result.error?.detail || result.error?.error || JSON.stringify(result.error)
      toast.error('Failed to add item: ' + errorMsg)
    }
  } finally {
    loading.value = wasLoading
  }
}

// One-tap re-add of the user's items from their last order at this restaurant
async function addMyUsual() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }
  if (order.status !== 'OPEN') {
    toast.warning('This order is locked and cannot be modified')
    return
  }

  addingUsual.value = true
  try {
    const result = await ordersStore.fetchMyUsual(order.restaurant)
    if (!result.success) {
      const errorMsg = result.error?.detail || result.error?.error || 'Unknown error'
      toast.error('Failed to fetch your usual: ' + errorMsg)
      return
    }

    const usualItems = result.data?.items || []
    if (!usualItems.length) {
      toast.info('No previous order here yet')
      return
    }

    let added = 0
    for (const usual of usualItems) {
      const itemData = {
        order: order.id,
        menu_item: usual.menu_item,
        quantity: usual.quantity,
        unit_price: usual.unit_price,
      }
      if (usual.note) itemData.note = usual.note
      const res = await ordersStore.addOrderItem(itemData)
      if (res.success) added++
    }

    if (added > 0) {
      toast.success(`Added ${added} item${added === 1 ? '' : 's'} from your last order`)
    } else {
      toast.error('Could not add items from your last order')
    }
  } finally {
    addingUsual.value = false
  }
}

async function addCustomItem() {
  if (!customItemName.value || !customItemPrice.value) {
    toast.warning('Please enter item name and price')
    return
  }

  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (order.status !== 'OPEN') {
    toast.warning('This order is locked and cannot be modified')
    return
  }

  // Check if user is trying to assign to someone else but doesn't have permission
  if (selectedItemUser.value && order.collector !== authStore.user?.id && !authStore.isManager) {
    toast.warning('Only collectors and managers can assign items to other users')
    return
  }

  const wasLoading = loading.value
  loading.value = true
  try {
    const itemData = {
      order: order.id,
      custom_name: customItemName.value,
      custom_price: customItemPrice.value,
      quantity: 1,
    }

    // Add note if provided
    if (customItemNote.value && customItemNote.value.trim()) {
      itemData.note = customItemNote.value.trim()
    }

    // Add user if specified and user has permission
    if (selectedItemUser.value && (order.collector === authStore.user?.id || authStore.isManager)) {
      itemData.user = selectedItemUser.value
    }

    const result = await ordersStore.addOrderItem(itemData)
    
    if (result.success) {
      const itemData = result.data
      
      // Check for prompts
      if (itemData.suggest_add_to_menu) {
        // Load menus for the restaurant
        await loadMenusForRestaurant(order.restaurant)
        promptItemId.value = itemData.id
        promptItemName.value = itemData.custom_name || itemData.item_name
        promptItemPrice.value = itemData.custom_price || itemData.unit_price
        showAddToMenuPrompt.value = true
      } else if (itemData.suggest_update_price) {
        promptItemId.value = itemData.id
        promptItemName.value = itemData.item_name
        promptItemPrice.value = itemData.custom_price || itemData.unit_price
        promptExistingMenuItemId.value = itemData.existing_menu_item_id
        showUpdatePricePrompt.value = true
      } else {
        // No prompts, just reset
        customItemName.value = ''
        customItemPrice.value = 0
        customItemNote.value = ''
        selectedItemUser.value = null
        // Don't manually refetch - WebSocket will broadcast the update automatically
        // await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
        await nextTick()
        generateInstapayQR()
      }
    } else {
      const errorMsg = result.error?.detail || result.error?.error || JSON.stringify(result.error)
      toast.error('Failed to add custom item: ' + errorMsg)
    }
  } finally {
    loading.value = wasLoading
  }
}

async function loadMenusForRestaurant(restaurantId) {
  try {
    const result = await ordersStore.fetchMenus(restaurantId)
    if (result.success) {
      availableMenus.value = result.data || []
      // Pre-select order's menu if available
      const order = currentOrder.value || ordersStore.currentOrder
      if (order?.menu) {
        selectedMenuForPrompt.value = order.menu
      } else if (availableMenus.value.length > 0) {
        selectedMenuForPrompt.value = availableMenus.value[0].id
      }
    }
  } catch (error) {
    console.error('Failed to load menus:', error)
  }
}

async function handleAddToMenu() {
  if (!promptItemId.value) return
  
  const wasLoading = loading.value
  loading.value = true
  try {
    const result = await ordersStore.addItemToMenu(promptItemId.value, selectedMenuForPrompt.value)
    
    if (result.success) {
      showAddToMenuPrompt.value = false
      customItemName.value = ''
      customItemPrice.value = 0
      selectedItemUser.value = null
      await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
      await nextTick()
      generateInstapayQR()
      toast.success('Item added to menu successfully!')
    } else {
      const errorMsg = result.error?.detail || result.error?.error || JSON.stringify(result.error)
      toast.error('Failed to add item to menu: ' + errorMsg)
    }
  } finally {
    loading.value = wasLoading
  }
}

async function handleUpdatePrice() {
  if (!promptItemId.value || !promptItemPrice.value) return
  
  const wasLoading = loading.value
  loading.value = true
  try {
    const result = await ordersStore.updateMenuItemPrice(promptItemId.value, promptItemPrice.value)
    
    if (result.success) {
      showUpdatePricePrompt.value = false
      await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
      await nextTick()
      generateInstapayQR()
      toast.success('Menu item price updated successfully!')
    } else {
      const errorMsg = result.error?.detail || result.error?.error || JSON.stringify(result.error)
      toast.error('Failed to update price: ' + errorMsg)
    }
  } finally {
    loading.value = wasLoading
  }
}

function dismissAddToMenuPrompt() {
  showAddToMenuPrompt.value = false
  customItemName.value = ''
  customItemPrice.value = 0
  selectedItemUser.value = null
  ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
  nextTick().then(() => generateInstapayQR())
}

function dismissUpdatePricePrompt() {
  showUpdatePricePrompt.value = false
  ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
  nextTick().then(() => generateInstapayQR())
}

const updatingItem = ref(null)

async function adjustQuantity(item, delta) {
  const newQty = item.quantity + delta
  if (newQty < 1) {
    if (!(await $confirm('Remove this item?'))) return
    loading.value = true
    await ordersStore.removeOrderItem(item.id)
    loading.value = false
    return
  }
  updatingItem.value = item.id
  try {
    await api.patch(`/order-items/${item.id}/`, { quantity: newQty })
    // WebSocket will push the update; optimistically update local item
    item.quantity = newQty
    item.total_price = (parseFloat(item.unit_price) * newQty).toFixed(2)
  } catch (error) {
    toast.error('Failed to update quantity: ' + (error.response?.data?.detail || error.message))
  } finally {
    updatingItem.value = null
  }
}

async function removeItem(itemId) {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (order.status !== 'OPEN') {
    toast.warning('This order is locked and cannot be modified')
    return
  }

  if (!(await $confirm('Remove this item?'))) return

  loading.value = true
  const result = await ordersStore.removeOrderItem(itemId)

  if (!result.success) {
    toast.error('Failed to remove item')
  }
  loading.value = false
}

async function updateFees() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (order.status !== 'OPEN') {
    toast.warning('Fees can only be updated when order is open')
    return
  }

  loading.value = true
  try {
    await api.patch(`/orders/${order.id}/`, fees.value)
    saveFeePreset(order.restaurant, fees.value)
    toast.success('Fees updated successfully')
  } catch (error) {
    toast.error('Failed to update fees: ' + (error.response?.data?.detail || error.message))
  }
  loading.value = false
}

// Entry point for the action bar's Lock: intercept custom fee split with a modal
function handleLockRequest() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }
  if (order.fee_split_rule === 'custom') {
    showCustomSplitModal.value = true
    return
  }
  lockOrder()
}

async function onCustomSplitLocked() {
  showCustomSplitModal.value = false
  await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
  toast.success('Order locked successfully')
}

function handleTransferRequest(newCollectorId) {
  transferCollectorId.value = newCollectorId
  transferCollector()
}

async function lockOrder() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (!(await $confirm("Lock this order? Users won't be able to add or remove items.", 'Lock Order'))) return

  loading.value = true
  const result = await ordersStore.lockOrder(order.id)
  if (result.success) {
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    toast.success('Order locked successfully')
  } else {
    toast.error('Failed to lock order: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  loading.value = false
}

async function markOrdered() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (!(await $confirm('Mark this order as ordered with the restaurant?', 'Mark as Ordered'))) return

  loading.value = true
  const result = await ordersStore.markOrdered(order.id)
  if (result.success) {
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    toast.success('Order marked as ordered')
  } else {
    toast.error('Failed to mark as ordered: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  loading.value = false
}

async function closeOrder() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (!(await $confirm('Close this order? This action cannot be undone.', 'Close Order'))) return

  loading.value = true
  const result = await ordersStore.closeOrder(order.id)
  if (result.success) {
    launchConfetti()
    setTimeout(() => router.push('/orders'), 2800)
  } else {
    toast.error('Failed to close order: ' + (result.error?.detail || JSON.stringify(result.error)))
    loading.value = false
  }
}

async function unlockOrder() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (!(await $confirm('Unlock this order? Users will be able to add or remove items again. Payments will be cleared and recalculated on next lock.', 'Unlock Order'))) return

  loading.value = true
  const result = await ordersStore.unlockOrder(order.id)
  if (result.success) {
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    toast.success('Order unlocked successfully')
  } else {
    toast.error('Failed to unlock order: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  loading.value = false
}

async function deleteOrder() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (order.status !== 'OPEN' && !authStore.isManager) {
    toast.warning('Can only delete open orders')
    return
  }

  const statusText = order.status !== 'OPEN' ? ` (Status: ${order.status})` : ''
  if (!(await $confirm(`Are you sure you want to delete this order${statusText}? This action cannot be undone.`, 'Delete Order'))) return

  loading.value = true
  const result = await ordersStore.deleteOrder(order.id)
  if (result.success) {
    toast.success('Order deleted successfully')
    router.replace('/orders')
  } else {
    toast.error('Failed to delete order: ' + (result.error?.error || result.error?.detail || JSON.stringify(result.error)))
    loading.value = false
  }
}

async function copyShareMessage() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order || !order.share_message) {
    toast.warning('Share message not available')
    return
  }
  try {
    await navigator.clipboard.writeText(order.share_message)
    toast.success('Share message copied to clipboard!')
  } catch (error) {
    const textArea = document.createElement('textarea')
    textArea.value = order.share_message
    textArea.style.position = 'fixed'
    textArea.style.opacity = '0'
    document.body.appendChild(textArea)
    textArea.select()
    try {
      document.execCommand('copy')
      toast.success('Share message copied to clipboard!')
    } catch (err) {
      toast.error('Failed to copy message. Please select and copy manually.')
    }
    document.body.removeChild(textArea)
  }
}

async function markPaymentPaid(paymentId) {
  if (!(await $confirm('Mark this payment as paid?', 'Confirm Payment'))) return

  loading.value = true
  try {
    await api.post(`/payments/${paymentId}/mark_paid/`)
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    toast.success('Payment marked as paid!')
  } catch (error) {
    toast.error('Failed to mark payment as paid')
  }
  loading.value = false
}

// --- Payment proof upload (participant) and review (collector/manager) ---
function triggerProofUpload(paymentId) {
  proofUploadPaymentId.value = paymentId
  proofFileInput.value?.click()
}

async function onProofFileSelected(event) {
  const file = event.target.files?.[0]
  event.target.value = '' // allow re-selecting the same file later
  const paymentId = proofUploadPaymentId.value
  proofUploadPaymentId.value = null
  if (!file || !paymentId) return

  uploadingProofFor.value = paymentId
  const result = await ordersStore.uploadPaymentProof(paymentId, file)
  uploadingProofFor.value = null

  if (result.success) {
    // WebSocket broadcast refreshes the order with the new proof_status
    toast.success('Payment proof uploaded — waiting for the collector to confirm')
  } else {
    const errorMsg = result.error?.detail || result.error?.error || 'Unknown error'
    toast.error('Failed to upload proof: ' + errorMsg)
  }
}

async function confirmProof(paymentId) {
  reviewingProofFor.value = paymentId
  const result = await ordersStore.confirmPaymentProof(paymentId)
  reviewingProofFor.value = null

  if (result.success) {
    toast.success('Payment proof confirmed')
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
  } else {
    const errorMsg = result.error?.detail || result.error?.error || 'Unknown error'
    toast.error('Failed to confirm proof: ' + errorMsg)
  }
}

async function rejectProof(paymentId) {
  reviewingProofFor.value = paymentId
  const result = await ordersStore.rejectPaymentProof(paymentId)
  reviewingProofFor.value = null

  if (result.success) {
    toast.info('Payment proof rejected — the participant can re-upload')
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
  } else {
    const errorMsg = result.error?.detail || result.error?.error || 'Unknown error'
    toast.error('Failed to reject proof: ' + errorMsg)
  }
}

async function loadUsers() {
  loadingUsers.value = true
  const usersResult = await ordersStore.fetchUsers()
  if (usersResult.success) {
    allUsers.value = usersResult.data
  }
  loadingUsers.value = false
}

async function ensureUsersLoaded() {
  if (allUsers.value.length === 0) {
    await loadUsers()
  }
}

function toggleAssignUsers() {
  showAssignUsers.value = !showAssignUsers.value
  if (showAssignUsers.value && allUsers.value.length === 0) {
    loadUsers()
  }
  // Set current assigned users when opening
  if (showAssignUsers.value && currentOrder.value?.assigned_users_details) {
    selectedUsers.value = currentOrder.value.assigned_users_details.map(u => u.id)
  }
  // Reset assignment fields
  if (!showAssignUsers.value) {
    assignmentItems.value = null
    assignmentTotalCost.value = null
  }
}

function selectAllUsers() {
  selectedUsers.value = allUsers.value.map(user => user.id)
}

function deselectAllUsers() {
  selectedUsers.value = []
}

async function updateAssignedUsers() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (order.status !== 'OPEN') {
    toast.warning('Can only update assigned users for open orders')
    return
  }

  if (selectedUsers.value.length === 0) {
    toast.warning('Please select at least one user')
    return
  }

  if ((assignmentItems.value && !assignmentTotalCost.value) || (assignmentTotalCost.value && !assignmentItems.value)) {
    toast.warning('Please provide both number of items and total cost, or leave both empty')
    return
  }

  loading.value = true
  try {
    const updateData = { assigned_users: selectedUsers.value }

    if (assignmentItems.value && assignmentTotalCost.value) {
      updateData.assignment_items = assignmentItems.value
      updateData.assignment_total_cost = assignmentTotalCost.value
    }

    await api.patch(`/orders/${order.id}/`, updateData)

    const hadItems = assignmentItems.value && assignmentTotalCost.value
    assignmentItems.value = null
    assignmentTotalCost.value = null

    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())

    toast.success('Assigned users updated successfully' + (hadItems ? '. Items split evenly.' : ''))
    showAssignUsers.value = false
  } catch (error) {
    toast.error('Failed to update assigned users: ' + (error.response?.data?.error || error.response?.data?.detail || error.message))
  }
  loading.value = false
}

async function transferCollector() {
  if (!transferCollectorId.value) {
    toast.warning('Please select a new collector')
    return
  }

  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (!(await $confirm('Transfer collector role to the selected participant?', 'Transfer Collector'))) return

  loading.value = true
  try {
    await api.post(`/orders/${order.id}/transfer_collector/`, {
      new_collector_id: transferCollectorId.value
    })
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    transferCollectorId.value = ''
    toast.success('Collector role transferred successfully')
  } catch (error) {
    toast.error('Failed to transfer collector: ' + (error.response?.data?.error || error.message))
  }
  loading.value = false
}

function openInstapay() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (order.instapay_link) {
    window.open(order.instapay_link, '_blank')
  } else {
    toast.warning('Instapay link not set by collector')
  }
}

function copyInstapayLink() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }

  if (order.instapay_link) {
    navigator.clipboard.writeText(order.instapay_link)
    toast.success('Instapay link copied to clipboard!')
  }
}

async function copyReceipt() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    toast.error('Order not loaded')
    return
  }
  
  const receipt = `📋 Order Receipt - ${order.restaurant_name}
Order Code: ${order.code}
Collector: ${order.collector_name}

Items Total: ${formatPrice(order.total_items_cost)} EGP
Delivery: ${formatPrice(order.delivery_fee)} EGP
Tip: ${formatPrice(order.tip)} EGP
Service Fee: ${formatPrice(order.service_fee)} EGP
━━━━━━━━━━━━━━━━━━━━
Total: ${formatPrice(order.total_cost)} EGP

Payment Breakdown:
${(order.payments || []).map(p => `  ${p.user_name}: ${formatPrice(p.amount)} EGP ${p.is_paid ? '✅' : '⏳'}`).join('\n')}

${order.instapay_link ? `Pay via Instapay: ${order.instapay_link}` : ''}`
  
  try {
    await navigator.clipboard.writeText(receipt)
    toast.success('Receipt copied! Share it in the group.')
  } catch (error) {
    const textArea = document.createElement('textarea')
    textArea.value = receipt
    textArea.style.position = 'fixed'
    textArea.style.opacity = '0'
    document.body.appendChild(textArea)
    textArea.select()
    try {
      document.execCommand('copy')
      toast.success('Receipt copied! Share it in the group.')
    } catch (err) {
      toast.error('Failed to copy receipt. Please select and copy manually.')
    }
    document.body.removeChild(textArea)
  }
}

async function exportCSV() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) return
  try {
    const response = await api.get(`/orders/${order.id}/export_csv/`, { responseType: 'blob' })
    const url = URL.createObjectURL(new Blob([response.data], { type: 'text/csv' }))
    const a = document.createElement('a')
    a.href = url
    a.download = `order-${order.code}.csv`
    a.click()
    URL.revokeObjectURL(url)
  } catch (error) {
    toast.error('Failed to export CSV: ' + (error.response?.data?.error || error.message))
  }
}
</script>

