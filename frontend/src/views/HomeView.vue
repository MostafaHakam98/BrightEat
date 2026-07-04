<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
    <!-- ═══════════════ HERO ═══════════════ -->
    <section
      class="home-rise relative overflow-hidden rounded-3xl bg-gradient-to-br from-indigo-600 via-indigo-600 to-violet-600 dark:from-indigo-950 dark:via-indigo-900 dark:to-violet-900 shadow-lg shadow-indigo-600/20 dark:shadow-black/40"
    >
      <!-- decorative layers -->
      <div class="pointer-events-none absolute inset-0" aria-hidden="true">
        <div class="hero-dots absolute inset-0 opacity-60" />
        <div class="absolute -top-24 -right-16 h-72 w-72 rounded-full bg-violet-400/30 dark:bg-violet-500/20 blur-3xl" />
        <div class="absolute -bottom-28 -left-10 h-72 w-72 rounded-full bg-indigo-300/25 dark:bg-indigo-400/10 blur-3xl" />
      </div>

      <div class="relative px-5 py-6 sm:px-8 sm:py-8">
        <div class="flex flex-col lg:flex-row lg:items-start gap-6">
          <!-- Greeting + boarding -->
          <div class="flex-1 min-w-0">
            <h1 class="text-2xl sm:text-3xl font-extrabold tracking-tight text-white">
              {{ greeting }} 👋
            </h1>
            <p class="mt-1.5 text-sm sm:text-base text-indigo-100/90">{{ subline }}</p>

            <!-- 🚂 Boarding now -->
            <div
              v-if="boardingOrder"
              class="mt-5 rounded-2xl bg-white/10 ring-1 ring-white/20 backdrop-blur-sm p-4 sm:p-5"
            >
              <div class="flex flex-col sm:flex-row sm:items-center gap-3 sm:gap-4">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <span class="relative flex h-2.5 w-2.5 shrink-0" aria-hidden="true">
                      <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-300 opacity-70" />
                      <span class="relative inline-flex h-2.5 w-2.5 rounded-full bg-emerald-300" />
                    </span>
                    <p class="text-[11px] font-bold uppercase tracking-widest text-emerald-200">Boarding now</p>
                  </div>
                  <p class="mt-1.5 text-white font-semibold truncate">
                    🚂 {{ boardingOrder.restaurant_name }} is boarding —
                    code <span class="font-mono tracking-wider">{{ boardingOrder.code }}</span>
                  </p>
                  <p v-if="countdown(boardingOrder.cutoff_time)" class="mt-2">
                    <span
                      class="inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-semibold ring-1"
                      :class="{
                        'bg-white/15 text-white ring-white/20': countdown(boardingOrder.cutoff_time).urgency === 'normal',
                        'bg-amber-300/20 text-amber-100 ring-amber-200/30': countdown(boardingOrder.cutoff_time).urgency === 'warning',
                        'bg-red-400/25 text-red-100 ring-red-300/30 animate-pulse': countdown(boardingOrder.cutoff_time).urgency === 'urgent',
                        'bg-white/10 text-indigo-100 ring-white/15': countdown(boardingOrder.cutoff_time).urgency === 'passed',
                      }"
                    >
                      ⏱ {{ countdown(boardingOrder.cutoff_time).text }}
                    </span>
                  </p>
                </div>
                <BaseButton
                  class="!bg-white !text-indigo-700 hover:!bg-indigo-50 shrink-0 shadow-sm"
                  @click="router.push(`/orders/${boardingOrder.code}`)"
                >
                  Hop on →
                </BaseButton>
              </div>
            </div>
          </div>

          <!-- Inline join-by-code -->
          <div class="w-full lg:w-80 shrink-0 lg:pt-1">
            <form @submit.prevent="joinOrder" class="rounded-2xl bg-white/10 ring-1 ring-white/20 backdrop-blur-sm p-4">
              <label for="hero-join-code" class="block text-[11px] font-bold uppercase tracking-widest text-indigo-100/90">
                Join an order
              </label>
              <div class="mt-2 flex gap-2">
                <input
                  id="hero-join-code"
                  v-model="joinCode"
                  type="text"
                  required
                  autocomplete="off"
                  placeholder="Got a code?"
                  class="min-w-0 flex-1 rounded-xl bg-white/15 border border-white/25 px-3 py-2 text-sm font-mono uppercase tracking-widest text-white placeholder:normal-case placeholder:tracking-normal placeholder:font-sans placeholder-indigo-200/80 focus:outline-none focus:ring-2 focus:ring-white/60 focus:border-transparent"
                />
                <BaseButton
                  type="submit"
                  :loading="joining"
                  class="!bg-white !text-indigo-700 hover:!bg-indigo-50 shrink-0 shadow-sm"
                >
                  Join
                </BaseButton>
              </div>
              <p class="mt-2 text-xs text-indigo-100/70">Paste the code from your group chat.</p>
            </form>
          </div>
        </div>

        <!-- Stat chips -->
        <div class="mt-6">
          <div v-if="loadingOrders" class="flex flex-col sm:flex-row gap-2 sm:gap-3">
            <div
              v-for="i in 3"
              :key="i"
              class="h-10 w-full sm:w-44 rounded-xl bg-white/10 ring-1 ring-white/10 animate-pulse"
              aria-hidden="true"
            />
          </div>
          <div v-else class="flex flex-col sm:flex-row gap-2 sm:gap-3">
            <div class="flex items-center justify-between sm:justify-start gap-2.5 rounded-xl bg-white/10 ring-1 ring-white/20 backdrop-blur-sm px-3.5 py-2">
              <span class="text-xs font-medium text-indigo-100/80">🍽 Active orders</span>
              <span class="text-sm font-bold text-white tabular-nums">{{ activeOrders.length }}</span>
            </div>
            <div class="flex items-center justify-between sm:justify-start gap-2.5 rounded-xl bg-white/10 ring-1 ring-white/20 backdrop-blur-sm px-3.5 py-2">
              <span class="text-xs font-medium text-indigo-100/80">💸 You owe</span>
              <span class="text-sm font-bold tabular-nums" :class="youOweTotal > 0 ? 'text-amber-200' : 'text-white'">
                {{ formatPrice(youOweTotal) }} EGP
              </span>
            </div>
            <div class="flex items-center justify-between sm:justify-start gap-2.5 rounded-xl bg-white/10 ring-1 ring-white/20 backdrop-blur-sm px-3.5 py-2">
              <span class="text-xs font-medium text-indigo-100/80">🪙 Owed to you</span>
              <span class="text-sm font-bold tabular-nums" :class="owedToMeTotal > 0 ? 'text-emerald-200' : 'text-white'">
                {{ formatPrice(owedToMeTotal) }} EGP
              </span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══════════════ TABS ═══════════════ -->
    <div class="home-rise home-rise-1 mt-6 sm:mt-8">
      <div class="inline-flex w-full sm:w-auto items-stretch gap-1 rounded-2xl bg-white dark:bg-gray-800 p-1 ring-1 ring-gray-200/80 dark:ring-gray-700/60 shadow-sm">
        <button
          type="button"
          aria-label="Active orders"
          :aria-pressed="activeTab === 'active'"
          @click="switchTab('active')"
          :class="tabClass('active')"
        >
          <span aria-hidden="true">🍽</span>
          <span class="hidden sm:inline">Active orders</span><span class="sm:hidden">Active</span>
          <span
            class="ml-0.5 rounded-full px-1.5 py-px text-[11px] font-bold tabular-nums"
            :class="activeTab === 'active' ? 'bg-white/20 text-white' : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300'"
          >{{ activeOrders.length }}</span>
        </button>
        <button
          type="button"
          aria-label="New order"
          :aria-pressed="activeTab === 'new'"
          @click="switchTab('new')"
          :class="tabClass('new')"
        >
          <span aria-hidden="true">➕</span>
          <span class="hidden sm:inline">New order</span><span class="sm:hidden">New</span>
        </button>
        <button
          type="button"
          aria-label="Scheduled"
          :aria-pressed="activeTab === 'scheduled'"
          @click="switchTab('scheduled')"
          :class="tabClass('scheduled')"
        >
          <span aria-hidden="true">⏰</span>
          <span class="hidden sm:inline">Scheduled</span><span class="sm:hidden">Auto</span>
          <span
            v-if="schedules.length"
            class="ml-0.5 rounded-full px-1.5 py-px text-[11px] font-bold tabular-nums"
            :class="activeTab === 'scheduled' ? 'bg-white/20 text-white' : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300'"
          >{{ schedules.length }}</span>
        </button>
      </div>
    </div>

    <!-- ─────────── Panel: Active orders ─────────── -->
    <section v-if="activeTab === 'active'" class="home-rise home-rise-2 mt-5">
      <div v-if="loadingOrders" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5">
        <SkeletonOrderCard v-for="i in 3" :key="i" />
      </div>

      <div v-else-if="activeOrders.length === 0" class="rounded-3xl bg-white dark:bg-gray-800 ring-1 ring-gray-200/80 dark:ring-gray-700/50 shadow-sm px-6 py-16 text-center">
        <div class="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-indigo-50 dark:bg-indigo-900/30 text-4xl" aria-hidden="true">🍽</div>
        <h3 class="mt-4 text-lg font-semibold text-gray-900 dark:text-white">No active orders right now</h3>
        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Start one and share the code in the group</p>
        <BaseButton class="mt-5" @click="switchTab('new')">Start an order</BaseButton>
      </div>

      <div v-else class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5">
        <article
          v-for="order in activeOrders"
          :key="order.id"
          class="relative overflow-hidden bg-white dark:bg-gray-800 rounded-2xl ring-1 ring-gray-200/80 dark:ring-gray-700/60 shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 p-5"
        >
          <span
            class="absolute inset-x-0 top-0 h-1"
            :class="{
              'bg-green-500': order.status === 'OPEN',
              'bg-amber-500': order.status === 'LOCKED',
              'bg-blue-500': order.status === 'ORDERED',
              'bg-gray-400': order.status === 'CLOSED',
            }"
            aria-hidden="true"
          />

          <div class="flex items-start justify-between gap-3">
            <h3 class="text-base font-semibold text-gray-900 dark:text-white truncate">{{ order.restaurant_name }}</h3>
            <BaseBadge :color="order.status">{{ order.status }}</BaseBadge>
          </div>

          <dl class="mt-2.5 grid grid-cols-[auto_minmax(0,1fr)] items-center gap-x-2 gap-y-1 text-sm text-gray-600 dark:text-gray-400">
            <dt class="text-gray-400 dark:text-gray-500">Code</dt>
            <dd class="justify-self-start font-mono text-xs font-semibold tracking-wider text-gray-700 dark:text-gray-300 bg-gray-100 dark:bg-gray-700/70 rounded px-1.5 py-0.5">{{ order.code }}</dd>
            <dt class="text-gray-400 dark:text-gray-500">Collector</dt>
            <dd class="truncate">{{ order.collector_name }}</dd>
          </dl>

          <div class="mt-2.5 flex flex-wrap items-center gap-2">
            <span
              v-if="countdown(order.cutoff_time)"
              class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium"
              :class="{
                'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400': countdown(order.cutoff_time).urgency === 'normal',
                'bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300': countdown(order.cutoff_time).urgency === 'warning',
                'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-300 animate-pulse': countdown(order.cutoff_time).urgency === 'urgent',
                'bg-gray-100 dark:bg-gray-700 text-gray-400 dark:text-gray-500': countdown(order.cutoff_time).urgency === 'passed',
              }"
            >
              ⏱ {{ countdown(order.cutoff_time).text }}
            </span>
            <span
              v-if="getPendingPayment(order.id)"
              class="inline-flex items-center rounded-full bg-yellow-100 dark:bg-yellow-900/40 px-2 py-0.5 text-xs font-semibold text-yellow-700 dark:text-yellow-300"
            >
              Pending {{ formatPrice(getPendingPayment(order.id).amount) }} EGP
            </span>
          </div>

          <div class="mt-4 flex gap-2">
            <router-link
              :to="`/orders/${order.code}`"
              class="flex-1 inline-flex items-center justify-center rounded-xl bg-indigo-600 dark:bg-indigo-500 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700 dark:hover:bg-indigo-600 transition-colors focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-1 dark:focus:ring-offset-gray-900"
            >
              View details
            </router-link>
            <BaseButton
              v-if="getPendingPayment(order.id)"
              variant="success"
              :loading="markingPaid === getPendingPayment(order.id).payment_id"
              @click="markAsPaid(getPendingPayment(order.id).payment_id, order.id)"
            >
              Pay
            </BaseButton>
          </div>
        </article>
      </div>
    </section>

    <!-- ─────────── Panel: New order ─────────── -->
    <section v-if="activeTab === 'new'" class="home-rise home-rise-2 mt-5">
      <div
        id="create-order-form"
        class="max-w-2xl bg-white dark:bg-gray-800 rounded-3xl ring-1 ring-gray-200/80 dark:ring-gray-700/50 shadow-sm p-6 sm:p-8"
      >
        <div class="flex items-center gap-2 flex-wrap">
          <h2 class="text-xl font-bold text-gray-900 dark:text-white">Create New Order</h2>
          <span
            v-if="reorderBanner"
            class="text-xs bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 px-2 py-0.5 rounded-full font-medium"
          >
            ↺ {{ reorderBanner }}
          </span>
        </div>
        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Open the train — everyone hops on with the code.</p>

        <form @submit.prevent="createOrder" class="mt-6 space-y-4">
          <div class="relative" ref="restaurantDropdownRef">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Restaurant</label>
            <input
              v-model="restaurantSearch"
              @focus="restaurantOpen = true"
              @input="restaurantOpen = true"
              type="text"
              autocomplete="off"
              placeholder="Search restaurant…"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-xl shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 dark:text-white"
            />
            <ul
              v-if="restaurantOpen && filteredRestaurants.length"
              class="absolute z-20 mt-1 w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl shadow-lg max-h-48 overflow-y-auto"
            >
              <li
                v-for="r in filteredRestaurants"
                :key="r.id"
                @mousedown.prevent="selectRestaurant(r)"
                class="px-3 py-2 cursor-pointer text-sm text-gray-800 dark:text-gray-100 hover:bg-indigo-50 dark:hover:bg-gray-600"
              >{{ r.name }}</li>
            </ul>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Menu
              <span v-if="availableMenus.length > 0" class="text-red-500 dark:text-red-400">*</span>
            </label>
            <div v-if="loadingMenus" class="mt-1 text-sm text-gray-500 dark:text-gray-400">Loading menus...</div>
            <select
              v-else
              v-model="newOrder.menu"
              :required="availableMenus.length > 0"
              :disabled="!newOrder.restaurant || availableMenus.length === 0"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-xl shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 disabled:bg-gray-100 dark:disabled:bg-gray-600 disabled:cursor-not-allowed dark:bg-gray-700 dark:text-white"
            >
              <option :value="null">
                {{ availableMenus.length === 0 ? 'No menus available for this restaurant' : 'Select a menu' }}
              </option>
              <option v-for="menu in availableMenus" :key="menu.id" :value="menu.id">
                {{ menu.name }}
              </option>
            </select>
            <p v-if="availableMenus.length > 0" class="mt-1 text-xs text-gray-500 dark:text-gray-400">Select a menu for this order</p>
            <p v-else-if="newOrder.restaurant" class="mt-1 text-xs text-gray-500 dark:text-gray-400">No menus available. You can still create the order and add items manually.</p>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Cutoff Time</label>
            <input
              v-model="newOrder.cutoff_time"
              type="datetime-local"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-xl shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 dark:text-white"
            />
          </div>

          <!-- Fee Preset -->
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Fee Preset</label>
            <select
              v-model="selectedPresetId"
              @change="applyPreset"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-xl shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 dark:text-white"
            >
              <option :value="null">— Custom / No Preset —</option>
              <option v-for="p in ordersStore.feePresets" :key="p.id" :value="p.id">
                {{ p.name }} (delivery {{ p.delivery_fee }}, tip {{ p.tip }})
              </option>
            </select>
          </div>

          <!-- Fee fields (collapsed by default, expanded when preset applied or toggled) -->
          <div class="rounded-xl border border-dashed border-gray-200 dark:border-gray-700 px-3 py-2.5">
            <button
              type="button"
              @click="showFeeFields = !showFeeFields"
              class="text-xs font-semibold text-indigo-600 dark:text-indigo-400 hover:underline"
            >
              {{ showFeeFields ? 'Hide fee details ▲' : 'Edit fee details ▼' }}
            </button>
            <div v-if="showFeeFields" class="mt-2 grid grid-cols-3 gap-2">
              <div>
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Delivery</label>
                <input v-model.number="newOrder.delivery_fee" type="number" min="0" step="0.01"
                  class="mt-1 block w-full px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Tip</label>
                <input v-model.number="newOrder.tip" type="number" min="0" step="0.01"
                  class="mt-1 block w-full px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Service</label>
                <input v-model.number="newOrder.service_fee" type="number" min="0" step="0.01"
                  class="mt-1 block w-full px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
              </div>
              <div class="col-span-3">
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Fee Split</label>
                <select v-model="newOrder.fee_split_rule"
                  class="mt-1 block w-full px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white">
                  <option value="equal">Equal</option>
                  <option value="proportional">Proportional</option>
                  <option value="collector_pays">Collector Pays</option>
                </select>
              </div>
            </div>
          </div>

          <div class="flex items-center">
            <input
              v-model="newOrder.is_private"
              type="checkbox"
              id="is_private"
              class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
            />
            <label for="is_private" class="ml-2 block text-sm text-gray-700 dark:text-gray-300">
              Make this order private (only participants can see it)
            </label>
          </div>

          <BaseButton type="submit" block :loading="loading">
            Create Order
          </BaseButton>
        </form>
      </div>
    </section>

    <!-- ─────────── Panel: Scheduled ─────────── -->
    <section v-if="activeTab === 'scheduled'" class="home-rise home-rise-2 mt-5">
      <div class="max-w-2xl bg-white dark:bg-gray-800 rounded-3xl ring-1 ring-gray-200/80 dark:ring-gray-700/50 shadow-sm p-6 sm:p-8">
        <div class="flex items-center justify-between gap-3 flex-wrap">
          <div>
            <h2 class="text-xl font-bold text-gray-900 dark:text-white">Scheduled orders</h2>
            <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Recurring orders that open themselves.</p>
          </div>
          <BaseButton
            v-if="schedules.length > 0 || showScheduleForm"
            variant="secondary"
            size="sm"
            @click="showScheduleForm = !showScheduleForm"
          >
            {{ showScheduleForm ? 'Close form' : '➕ New schedule' }}
          </BaseButton>
        </div>

        <!-- Loading -->
        <div v-if="loadingSchedules" class="mt-5 space-y-3" aria-hidden="true">
          <div v-for="i in 2" :key="i" class="flex items-center justify-between gap-3 rounded-2xl border border-gray-200 dark:border-gray-700 p-4">
            <div class="flex-1 space-y-2">
              <BaseSkeleton width="45%" height="1rem" />
              <BaseSkeleton width="60%" height="0.75rem" />
            </div>
            <BaseSkeleton width="2.25rem" height="1.25rem" rounded="full" />
          </div>
        </div>

        <!-- Empty state -->
        <div v-else-if="schedules.length === 0 && !showScheduleForm" class="mt-5 rounded-2xl border border-dashed border-gray-300 dark:border-gray-600 px-6 py-12 text-center">
          <div class="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-indigo-50 dark:bg-indigo-900/30 text-3xl" aria-hidden="true">⏰</div>
          <h3 class="mt-3 text-base font-semibold text-gray-900 dark:text-white">No schedules yet — lunch that starts itself</h3>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Pick a restaurant, a time, and the days. The order opens automatically.</p>
          <BaseButton class="mt-5" @click="showScheduleForm = true">➕ New schedule</BaseButton>
        </div>

        <!-- Schedule rows -->
        <ul v-if="!loadingSchedules && schedules.length > 0" class="mt-5 space-y-3">
          <li
            v-for="schedule in schedules"
            :key="schedule.id"
            class="flex items-center justify-between gap-3 rounded-2xl border border-gray-200 dark:border-gray-700 p-4 transition-opacity"
            :class="schedule.is_active ? '' : 'opacity-60'"
          >
            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-2 flex-wrap">
                <p class="text-sm font-semibold text-gray-900 dark:text-white truncate">
                  {{ schedule.restaurant_name }}
                </p>
                <span class="inline-flex items-center rounded-md bg-indigo-50 dark:bg-indigo-900/40 px-1.5 py-0.5 font-mono text-xs font-semibold text-indigo-700 dark:text-indigo-300">
                  {{ formatScheduleTime(schedule.open_at) }}
                </span>
              </div>
              <div class="mt-1.5 flex flex-wrap gap-1">
                <span
                  v-for="day in scheduleWeekdays(schedule.weekdays)"
                  :key="day.value"
                  class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-300"
                >{{ day.label }}</span>
              </div>
            </div>
            <div class="flex items-center gap-2 shrink-0">
              <button
                type="button"
                role="switch"
                :aria-checked="schedule.is_active"
                :disabled="togglingSchedule === schedule.id"
                @click="toggleSchedule(schedule)"
                class="relative inline-flex h-5 w-9 items-center rounded-full transition-colors disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-1 dark:focus:ring-offset-gray-800"
                :class="schedule.is_active ? 'bg-indigo-600' : 'bg-gray-300 dark:bg-gray-600'"
                :title="schedule.is_active ? 'Active — click to pause' : 'Paused — click to activate'"
              >
                <span
                  class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform"
                  :class="schedule.is_active ? 'translate-x-4' : 'translate-x-1'"
                />
              </button>
              <button
                type="button"
                @click="deleteSchedule(schedule)"
                class="rounded-lg p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 dark:hover:text-red-400 dark:hover:bg-red-900/20 transition-colors"
                title="Delete schedule"
                aria-label="Delete schedule"
              >✕</button>
            </div>
          </li>
        </ul>

        <!-- New schedule form -->
        <form
          v-if="showScheduleForm"
          @submit.prevent="createSchedule"
          class="mt-5 space-y-4 rounded-2xl bg-gray-50 dark:bg-gray-900/40 ring-1 ring-gray-200 dark:ring-gray-700 p-4 sm:p-5"
        >
          <h3 class="text-sm font-bold uppercase tracking-wide text-gray-500 dark:text-gray-400">New schedule</h3>
          <div>
            <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Restaurant</label>
            <select
              v-model="newSchedule.restaurant"
              @change="onScheduleRestaurantChange"
              required
              class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
            >
              <option value="" disabled>Select a restaurant</option>
              <option v-for="r in ordersStore.restaurants" :key="r.id" :value="r.id">{{ r.name }}</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Menu (optional)</label>
            <select
              v-model="newSchedule.menu"
              :disabled="!newSchedule.restaurant || scheduleMenus.length === 0"
              class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white disabled:bg-gray-100 dark:disabled:bg-gray-600 disabled:cursor-not-allowed"
            >
              <option :value="null">{{ scheduleMenus.length === 0 ? 'No menus available' : 'No specific menu' }}</option>
              <option v-for="menu in scheduleMenus" :key="menu.id" :value="menu.id">{{ menu.name }}</option>
            </select>
          </div>
          <div class="grid grid-cols-2 gap-2">
            <div>
              <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Opens at</label>
              <input
                v-model="newSchedule.open_at"
                type="time"
                required
                class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
              />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Cutoff after (min)</label>
              <input
                v-model.number="newSchedule.cutoff_after_minutes"
                type="number"
                min="0"
                class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
              />
            </div>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Days</label>
            <div class="mt-1 flex flex-wrap gap-1.5">
              <button
                v-for="day in weekdayOptions"
                :key="day.value"
                type="button"
                @click="toggleWeekday(day.value)"
                class="text-xs font-medium px-2 py-1 rounded-full border transition-colors"
                :class="newSchedule.weekdays.includes(day.value)
                  ? 'bg-indigo-600 border-indigo-600 text-white'
                  : 'bg-white dark:bg-gray-700 border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:border-indigo-400'"
              >
                {{ day.label }}
              </button>
            </div>
          </div>
          <div class="grid grid-cols-3 gap-2">
            <div>
              <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Delivery</label>
              <input v-model.number="newSchedule.delivery_fee" type="number" min="0" step="0.01"
                class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Tip</label>
              <input v-model.number="newSchedule.tip" type="number" min="0" step="0.01"
                class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Service</label>
              <input v-model.number="newSchedule.service_fee" type="number" min="0" step="0.01"
                class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white" />
            </div>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">Fee Split</label>
            <select
              v-model="newSchedule.fee_split_rule"
              class="mt-1 block w-full px-2 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
            >
              <option value="equal">Equal</option>
              <option value="proportional">Proportional</option>
              <option value="collector_pays">Collector Pays</option>
            </select>
          </div>
          <BaseButton type="submit" block :loading="creatingSchedule">
            Schedule it
          </BaseButton>
        </form>
      </div>
    </section>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, onBeforeUnmount } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useOrdersStore } from '../stores/orders'
import { useAuthStore } from '../stores/auth'
import { useNotificationsStore } from '../stores/notifications'
import { formatCountdown, useTick } from '../composables/useCountdown'
import { useToast } from '../composables/useToast'
import { useConfirm } from '../composables/useConfirm'
import api from '../api'
import BaseButton from '../components/ui/BaseButton.vue'
import BaseBadge from '../components/ui/BaseBadge.vue'
import BaseSkeleton from '../components/ui/BaseSkeleton.vue'
import SkeletonOrderCard from '../components/ui/SkeletonOrderCard.vue'

const toast = useToast()
const { confirm: $confirm } = useConfirm()

const router = useRouter()
const route = useRoute()
const ordersStore = useOrdersStore()
const authStore = useAuthStore()

const tick = useTick()
function countdown(cutoffTime) {
  void tick.value
  return formatCountdown(cutoffTime)
}

// --- Hero: greeting + subline ---
const greeting = computed(() => {
  const hour = new Date().getHours()
  const part = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening'
  const name = authStore.user?.first_name || authStore.user?.username || 'there'
  return `${part}, ${name}`
})

const subline = computed(() => {
  const hour = new Date().getHours()
  if (hour < 12) return 'Coffee first — then rally the lunch train.'
  if (hour < 18) return 'Prime boarding hours. Don’t miss the train.'
  return 'Late cravings? Someone is probably ordering.'
})

// --- Hero: boarding order (nearest-cutoff OPEN order) ---
const boardingOrder = computed(() => {
  const open = ordersStore.orders.filter(o => o.status === 'OPEN')
  if (open.length === 0) return null
  const now = Date.now()
  const withFutureCutoff = open.filter(o => o.cutoff_time && new Date(o.cutoff_time).getTime() > now)
  if (withFutureCutoff.length > 0) {
    return [...withFutureCutoff].sort(
      (a, b) => new Date(a.cutoff_time) - new Date(b.cutoff_time)
    )[0]
  }
  return [...open].sort((a, b) => (b.id ?? 0) - (a.id ?? 0))[0]
})

// --- Tabs ---
const HOME_TAB_KEY = 'orderq:home-tab'
const VALID_TABS = ['active', 'new', 'scheduled']
const activeTab = ref('active')
try {
  const saved = localStorage.getItem(HOME_TAB_KEY)
  if (VALID_TABS.includes(saved)) activeTab.value = saved
} catch { /* localStorage unavailable — keep default */ }

function switchTab(tab) {
  activeTab.value = tab
  try { localStorage.setItem(HOME_TAB_KEY, tab) } catch { /* noop */ }
}

function tabClass(tab) {
  return [
    'flex-1 sm:flex-none inline-flex items-center justify-center gap-1.5 rounded-xl px-3 sm:px-4 py-2 text-sm font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-indigo-500',
    activeTab.value === tab
      ? 'bg-indigo-600 text-white shadow-sm'
      : 'text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700/70',
  ]
}

const newOrder = ref({
  restaurant: '',
  menu: null,
  cutoff_time: '',
  is_private: false,
  delivery_fee: 30,
  tip: 30,
  service_fee: 0,
  fee_split_rule: 'equal',
})
const joinCode = ref('')
const loading = ref(false)
const joining = ref(false)
const loadingOrders = ref(false)
const availableMenus = ref([])
const loadingMenus = ref(false)
const pendingPayments = ref([])
const owedToMePayments = ref([])
const markingPaid = ref(null)
const selectedPresetId = ref(null)
const showFeeFields = ref(false)

function applyPreset() {
  const preset = ordersStore.feePresets.find(p => p.id === selectedPresetId.value)
  if (preset) {
    newOrder.value.delivery_fee = parseFloat(preset.delivery_fee)
    newOrder.value.tip = parseFloat(preset.tip)
    newOrder.value.service_fee = parseFloat(preset.service_fee)
    newOrder.value.fee_split_rule = preset.fee_split_rule || 'equal'
    showFeeFields.value = true
  }
}

const activeOrders = computed(() => {
  return ordersStore.orders.filter(o => o.status !== 'CLOSED')
})

// --- Hero stats ---
const youOweTotal = computed(() =>
  pendingPayments.value.reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0)
)
const owedToMeTotal = computed(() =>
  owedToMePayments.value.reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0)
)

function formatPrice(value) {
  if (value === null || value === undefined) return '0.00'
  const num = typeof value === 'string' ? parseFloat(value) : value
  return isNaN(num) ? '0.00' : num.toFixed(2)
}

function getPendingPayment(orderId) {
  return pendingPayments.value.find(p => p.order_id === orderId)
}

async function fetchPendingPayments() {
  try {
    const response = await api.get('/orders/pending_payments/')
    pendingPayments.value = response.data
  } catch (error) {
    console.error('Failed to fetch pending payments:', error)
  }
}

async function fetchOwedToMe() {
  try {
    const response = await api.get('/orders/pending_payments_to_me/')
    owedToMePayments.value = response.data
  } catch (error) {
    console.error('Failed to fetch payments owed to me:', error)
  }
}

async function markAsPaid(paymentId, orderId) {
  if (!(await $confirm('Mark this payment as paid?', 'Confirm Payment'))) return

  markingPaid.value = paymentId
  try {
    await api.post(`/payments/${paymentId}/mark_paid/`)
    pendingPayments.value = pendingPayments.value.filter(p => p.payment_id !== paymentId)
    toast.success('Payment marked as paid!')
  } catch (error) {
    toast.error('Failed to mark payment as paid: ' + (error.response?.data?.error || error.message))
  } finally {
    markingPaid.value = null
  }
}

async function onRestaurantChange() {
  if (!newOrder.value.restaurant) {
    availableMenus.value = []
    newOrder.value.menu = null
    return
  }

  loadingMenus.value = true
  try {
    const result = await ordersStore.fetchMenus(parseInt(newOrder.value.restaurant))
    if (result.success) {
      availableMenus.value = result.data.filter(menu => menu.is_active)
    } else {
      availableMenus.value = []
    }
    newOrder.value.menu = null
  } catch (error) {
    console.error('Error fetching menus:', error)
    availableMenus.value = []
  } finally {
    loadingMenus.value = false
  }
}

const reorderBanner = ref('')

// --- Scheduled (recurring) orders ---
// Weekday values follow the backend csv convention: 0=Mon … 6=Sun
const weekdayOptions = [
  { value: 0, label: 'Mon' },
  { value: 1, label: 'Tue' },
  { value: 2, label: 'Wed' },
  { value: 3, label: 'Thu' },
  { value: 4, label: 'Fri' },
  { value: 5, label: 'Sat' },
  { value: 6, label: 'Sun' },
]

// Default: Sun–Thu (the local work week), opening at 11:00 with a 45-min cutoff
const defaultSchedule = () => ({
  restaurant: '',
  menu: null,
  open_at: '11:00',
  weekdays: [6, 0, 1, 2, 3],
  cutoff_after_minutes: 45,
  delivery_fee: 30,
  tip: 30,
  service_fee: 0,
  fee_split_rule: 'equal',
})

const schedules = computed(() => ordersStore.recurringOrders)
const loadingSchedules = ref(false)
const showScheduleForm = ref(false)
const creatingSchedule = ref(false)
const togglingSchedule = ref(null)
const scheduleMenus = ref([])
const newSchedule = ref(defaultSchedule())

function formatScheduleTime(openAt) {
  return String(openAt || '').slice(0, 5) // "11:00:00" → "11:00"
}

function scheduleWeekdays(csv) {
  const selected = new Set(String(csv ?? '').split(',').filter(v => v !== '').map(Number))
  return weekdayOptions.filter(day => selected.has(day.value))
}

function toggleWeekday(value) {
  const index = newSchedule.value.weekdays.indexOf(value)
  if (index === -1) newSchedule.value.weekdays.push(value)
  else newSchedule.value.weekdays.splice(index, 1)
}

async function fetchSchedules() {
  loadingSchedules.value = true
  await ordersStore.fetchRecurringOrders()
  loadingSchedules.value = false
}

async function onScheduleRestaurantChange() {
  newSchedule.value.menu = null
  scheduleMenus.value = []
  if (!newSchedule.value.restaurant) return
  const result = await ordersStore.fetchMenus(parseInt(newSchedule.value.restaurant))
  if (result.success) {
    scheduleMenus.value = result.data.filter(menu => menu.is_active)
  }
}

async function createSchedule() {
  if (!newSchedule.value.restaurant) {
    toast.warning('Please select a restaurant')
    return
  }
  if (newSchedule.value.weekdays.length === 0) {
    toast.warning('Pick at least one day')
    return
  }

  creatingSchedule.value = true
  const openAt = newSchedule.value.open_at
  const result = await ordersStore.createRecurringOrder({
    restaurant: parseInt(newSchedule.value.restaurant),
    menu: newSchedule.value.menu ? parseInt(newSchedule.value.menu) : null,
    open_at: openAt.length === 5 ? `${openAt}:00` : openAt,
    weekdays: newSchedule.value.weekdays.join(','),
    cutoff_after_minutes: newSchedule.value.cutoff_after_minutes || null,
    delivery_fee: newSchedule.value.delivery_fee,
    tip: newSchedule.value.tip,
    service_fee: newSchedule.value.service_fee,
    fee_split_rule: newSchedule.value.fee_split_rule,
  })

  if (result.success) {
    toast.success('Scheduled — it will open automatically')
    newSchedule.value = defaultSchedule()
    scheduleMenus.value = []
    showScheduleForm.value = false
    await fetchSchedules()
  } else {
    toast.error('Failed to create schedule: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  creatingSchedule.value = false
}

async function toggleSchedule(schedule) {
  togglingSchedule.value = schedule.id
  const result = await ordersStore.updateRecurringOrder(schedule.id, { is_active: !schedule.is_active })
  if (!result.success) {
    toast.error('Failed to update schedule: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  togglingSchedule.value = null
}

async function deleteSchedule(schedule) {
  if (!(await $confirm(`Delete the ${schedule.restaurant_name} schedule?`, 'Delete Schedule'))) return
  const result = await ordersStore.deleteRecurringOrder(schedule.id)
  if (result.success) {
    toast.success('Schedule deleted')
  } else {
    toast.error('Failed to delete schedule: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
}

// Restaurant type-ahead search
const restaurantSearch = ref('')
const restaurantOpen = ref(false)
const restaurantDropdownRef = ref(null)

const filteredRestaurants = computed(() => {
  const q = restaurantSearch.value.toLowerCase()
  return ordersStore.restaurants.filter(r => r.name.toLowerCase().includes(q))
})

function selectRestaurant(r) {
  newOrder.value.restaurant = String(r.id)
  restaurantSearch.value = r.name
  restaurantOpen.value = false
  onRestaurantChange()
}

function handleOutsideClick(e) {
  if (restaurantDropdownRef.value && !restaurantDropdownRef.value.contains(e.target)) {
    restaurantOpen.value = false
  }
}
onMounted(() => document.addEventListener('mousedown', handleOutsideClick))
onBeforeUnmount(() => document.removeEventListener('mousedown', handleOutsideClick))

// Keep "Active orders" live: refetch when any order is created/updated elsewhere
const notifStore = useNotificationsStore()
let offOrderEvents = null
onMounted(() => {
  offOrderEvents = notifStore.onOrderEvent(() => ordersStore.fetchOrders())
})
onBeforeUnmount(() => { if (offOrderEvents) offOrderEvents() })

onMounted(async () => {
  // Reorder deep-link opens the New order tab immediately (don't persist —
  // it's a navigation intent, not a user preference)
  if (route.query.restaurant) {
    activeTab.value = 'new'
  }

  loadingOrders.value = true
  await Promise.all([
    ordersStore.fetchRestaurants(),
    ordersStore.fetchOrders(),
    ordersStore.fetchFeePresets(),
    fetchPendingPayments(),
    fetchOwedToMe(),
    fetchSchedules(),
  ])
  loadingOrders.value = false

  // Pre-fill form when navigated here via ↺ Reorder
  if (route.query.restaurant) {
    newOrder.value.restaurant = String(route.query.restaurant)
    await onRestaurantChange()
    if (route.query.menu) {
      newOrder.value.menu = parseInt(route.query.menu)
    }
    const restaurant = ordersStore.restaurants.find(r => r.id === parseInt(route.query.restaurant))
    if (restaurant) restaurantSearch.value = restaurant.name
    reorderBanner.value = restaurant ? `Re-ordering from ${restaurant.name}` : 'Re-ordering'
    document.getElementById('create-order-form')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
})

async function createOrder() {
  if (!newOrder.value.restaurant) {
    toast.warning('Please select a restaurant')
    return
  }

  if (availableMenus.value.length > 0 && !newOrder.value.menu) {
    toast.warning('Please select a menu for this restaurant')
    return
  }

  loading.value = true
  const orderData = {
    restaurant: parseInt(newOrder.value.restaurant),
    is_private: newOrder.value.is_private,
    delivery_fee: newOrder.value.delivery_fee,
    tip: newOrder.value.tip,
    service_fee: newOrder.value.service_fee,
    fee_split_rule: newOrder.value.fee_split_rule,
  }

  if (newOrder.value.menu) {
    orderData.menu = parseInt(newOrder.value.menu)
  }

  if (newOrder.value.cutoff_time) {
    orderData.cutoff_time = newOrder.value.cutoff_time
  }

  const result = await ordersStore.createOrder(orderData)

  if (result.success) {
    router.push(`/orders/${result.data.code}`)
    newOrder.value = { restaurant: '', menu: null, cutoff_time: '', is_private: false, delivery_fee: 30, tip: 30, service_fee: 0, fee_split_rule: 'equal' }
    selectedPresetId.value = null
    showFeeFields.value = false
    availableMenus.value = []
  } else {
    toast.error('Failed to create order: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  loading.value = false
}

async function joinOrder() {
  joining.value = true
  const result = await ordersStore.fetchOrderByCode(joinCode.value.toUpperCase())

  if (result.success) {
    router.push(`/orders/${joinCode.value.toUpperCase()}`)
  } else {
    toast.error('Order not found')
  }
  joining.value = false
}
</script>

<style scoped>
/* Subtle dot-grid texture over the hero gradient */
.hero-dots {
  background-image: radial-gradient(rgba(255, 255, 255, 0.16) 1px, transparent 1px);
  background-size: 22px 22px;
  mask-image: linear-gradient(to bottom, rgba(0, 0, 0, 0.9), transparent 75%);
  -webkit-mask-image: linear-gradient(to bottom, rgba(0, 0, 0, 0.9), transparent 75%);
}

/* Staggered entrance */
@keyframes home-rise {
  from { opacity: 0; transform: translateY(10px); }
  to   { opacity: 1; transform: none; }
}
.home-rise   { animation: home-rise 0.5s cubic-bezier(0.22, 1, 0.36, 1) both; }
.home-rise-1 { animation-delay: 0.07s; }
.home-rise-2 { animation-delay: 0.14s; }

@media (prefers-reduced-motion: reduce) {
  .home-rise, .home-rise-1, .home-rise-2 { animation: none; }
}
</style>
