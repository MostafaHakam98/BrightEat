<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900">

    <!-- ── Top bar ──────────────────────────────────────────────── -->
    <nav
      v-if="authStore.isAuthenticated"
      :class="[
        'bg-white/80 dark:bg-gray-900/80 backdrop-blur-md border-b border-gray-200/50 dark:border-gray-700/50 sticky top-0 z-40 transition-shadow duration-200',
        scrolled ? 'shadow-md shadow-black/5 dark:shadow-black/20' : ''
      ]"
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16 items-center">
          <!-- Left: hamburger + logo -->
          <div class="flex items-center gap-3">
            <button
              @click="sidebarOpen = true"
              class="p-2 rounded-md text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              aria-label="Open menu"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
              </svg>
            </button>
            <router-link to="/" class="text-2xl font-extrabold text-indigo-600 dark:text-indigo-400 tracking-tight">
              OrderQ
            </router-link>
          </div>

          <!-- Right: quick links (desktop) + theme + avatar + logout -->
          <div class="flex items-center gap-3">
            <!-- Quick nav (desktop only) -->
            <div class="hidden md:flex items-center gap-1">
              <router-link
                to="/"
                class="px-3 py-1.5 rounded-md text-sm font-medium text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-gray-900 dark:hover:text-white transition-colors"
                active-class="bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400"
                :exact="true"
              >
                Home
              </router-link>
              <router-link
                to="/orders"
                class="px-3 py-1.5 rounded-md text-sm font-medium text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-gray-900 dark:hover:text-white transition-colors"
                active-class="bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400"
              >
                Orders
              </router-link>
              <router-link
                to="/wheel"
                class="px-3 py-1.5 rounded-md text-sm font-medium text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-gray-900 dark:hover:text-white transition-colors"
                active-class="bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400"
              >
                Wheel
              </router-link>
            </div>

            <!-- Theme toggle -->
            <button
              @click="themeStore.toggleTheme()"
              class="p-2 rounded-md text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              :title="themeStore.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
            >
              <svg v-if="themeStore.isDark" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"/>
              </svg>
              <svg v-else class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"/>
              </svg>
            </button>

            <!-- Bell / notifications -->
            <div class="relative" ref="bellRef">
              <button
                @click="toggleBell"
                class="relative p-2 rounded-md text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
                :aria-label="$t('nav.notifications')"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
                </svg>
                <span
                  v-if="notifStore.unreadCount > 0"
                  class="absolute -top-0.5 -right-0.5 flex items-center justify-center min-w-[18px] h-[18px] px-1 rounded-full bg-red-500 text-white text-[10px] font-bold leading-none"
                >{{ notifStore.unreadCount > 99 ? '99+' : notifStore.unreadCount }}</span>
              </button>

              <!-- Dropdown panel -->
              <transition name="bell-drop">
                <div
                  v-if="bellOpen"
                  class="absolute right-0 mt-2 w-80 bg-white dark:bg-gray-800 rounded-xl shadow-xl border border-gray-200 dark:border-gray-700 z-50 overflow-hidden"
                >
                  <div class="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-gray-700">
                    <span class="text-sm font-semibold text-gray-800 dark:text-gray-100">{{ $t('nav.notifications') }}</span>
                    <button
                      v-if="notifStore.unreadCount > 0"
                      @click="notifStore.markAllRead()"
                      class="text-xs text-indigo-600 dark:text-indigo-400 hover:underline"
                    >{{ $t('nav.markAllRead') }}</button>
                  </div>
                  <ul class="max-h-72 overflow-y-auto divide-y divide-gray-100 dark:divide-gray-700">
                    <li v-if="notifStore.notifications.length === 0" class="px-4 py-6 text-center text-sm text-gray-400 dark:text-gray-500">
                      {{ $t('nav.noNotifications') }}
                    </li>
                    <li
                      v-for="n in notifStore.notifications"
                      :key="n.id"
                      @click="handleNotifClick(n)"
                      :class="['px-4 py-3 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors', n.is_read ? '' : 'bg-indigo-50 dark:bg-indigo-900/20']"
                    >
                      <p class="text-sm text-gray-800 dark:text-gray-100 leading-snug">{{ n.message }}</p>
                      <p class="text-xs text-gray-400 dark:text-gray-500 mt-0.5">{{ formatNotifTime(n.created_at) }}</p>
                    </li>
                  </ul>
                </div>
              </transition>
            </div>

            <!-- Avatar -->
            <span
              class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-indigo-600 dark:bg-indigo-500 text-white text-sm font-semibold select-none cursor-default"
              :title="authStore.user?.username"
            >
              {{ authStore.user?.username?.charAt(0)?.toUpperCase() || '?' }}
            </span>
            <span class="text-sm font-medium text-gray-700 dark:text-gray-300 hidden lg:inline">{{ authStore.user?.username }}</span>

            <button
              @click="authStore.logout()"
              class="px-3 py-1.5 rounded-md text-sm font-medium border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:border-red-300 dark:hover:border-red-700 hover:text-red-600 dark:hover:text-red-400 transition-colors"
            >
              {{ $t('nav.logout') }}
            </button>
          </div>
        </div>
      </div>
    </nav>

    <!-- ── Sidebar overlay ──────────────────────────────────────── -->
    <transition name="sidebar-backdrop">
      <div
        v-if="sidebarOpen"
        class="fixed inset-0 z-50 flex"
        @click.self="sidebarOpen = false"
      >
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/40 dark:bg-black/60 backdrop-blur-sm" @click="sidebarOpen = false" />

        <!-- Panel -->
        <transition name="sidebar-panel">
          <aside
            v-if="sidebarOpen"
            class="relative w-72 max-w-[85vw] h-full bg-white dark:bg-gray-900 shadow-2xl flex flex-col overflow-y-auto"
          >
            <!-- Sidebar header -->
            <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800">
              <span class="text-lg font-extrabold text-indigo-600 dark:text-indigo-400 tracking-tight">OrderQ</span>
              <button
                @click="sidebarOpen = false"
                class="p-1.5 rounded-md text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <!-- User chip -->
            <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800">
              <div class="flex items-center gap-3">
                <span class="inline-flex items-center justify-center w-9 h-9 rounded-full bg-indigo-600 dark:bg-indigo-500 text-white text-sm font-semibold">
                  {{ authStore.user?.username?.charAt(0)?.toUpperCase() || '?' }}
                </span>
                <div>
                  <p class="text-sm font-semibold text-gray-900 dark:text-white">{{ authStore.user?.username }}</p>
                  <p class="text-xs text-gray-500 dark:text-gray-400 capitalize">{{ authStore.user?.role || 'user' }}</p>
                </div>
              </div>
            </div>

            <!-- Nav links -->
            <nav class="flex-1 px-3 py-4 space-y-1">
              <p class="px-2 text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-2">Main</p>

              <SidebarLink to="/" :exact="true" icon="home" @click="sidebarOpen = false">{{ $t('nav.home') }}</SidebarLink>
              <SidebarLink to="/orders" icon="orders" @click="sidebarOpen = false">{{ $t('nav.orders') }}</SidebarLink>
              <SidebarLink to="/wheel" icon="wheel" @click="sidebarOpen = false">{{ $t('nav.wheel') }}</SidebarLink>
              <SidebarLink to="/reports" icon="reports" @click="sidebarOpen = false">{{ $t('nav.reports') }}</SidebarLink>
              <SidebarLink to="/pending-payments" icon="payments" @click="sidebarOpen = false">{{ $t('nav.pendingPayments') }}</SidebarLink>
              <SidebarLink to="/recommendations" icon="feedback" @click="sidebarOpen = false">{{ $t('nav.feedback') }}</SidebarLink>
              <SidebarLink to="/restaurants" icon="restaurants" @click="sidebarOpen = false">{{ $t('nav.restaurants') }}</SidebarLink>
              <SidebarLink to="/profile" icon="profile" @click="sidebarOpen = false">{{ $t('nav.profile') }}</SidebarLink>

              <template v-if="authStore.isAdmin">
                <p class="px-2 pt-4 text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-2">Management</p>
                <SidebarLink to="/register" icon="add-user" @click="sidebarOpen = false">{{ $t('nav.register') }}</SidebarLink>
                <SidebarLink to="/users" icon="users" @click="sidebarOpen = false">{{ $t('nav.users') }}</SidebarLink>
              </template>
            </nav>

            <!-- Sidebar footer -->
            <div class="px-5 py-4 border-t border-gray-100 dark:border-gray-800">
              <button
                @click="authStore.logout()"
                class="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/>
                </svg>
                {{ $t('nav.logout') }}
              </button>
            </div>
          </aside>
        </transition>
      </div>
    </transition>

    <!-- ── Page content with route transitions ──────────────────── -->
    <main class="dark:bg-gray-900">
      <router-view v-slot="{ Component, route }">
        <transition name="page" mode="out-in">
          <component :is="Component" :key="route.path" />
        </transition>
      </router-view>
    </main>

    <ToastContainer />
    <ConfirmDialog />
  </div>
</template>

<script setup>
import { ref, watch, onMounted, onUnmounted, defineComponent, h, resolveComponent } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from './stores/auth'
import { useThemeStore } from './stores/theme'
import { useNotificationsStore } from './stores/notifications'
import { RouterLink } from 'vue-router'
import ToastContainer from './components/ToastContainer.vue'
import ConfirmDialog from './components/ConfirmDialog.vue'
import { useToast } from './composables/useToast'
import api from './api'

const authStore = useAuthStore()
const themeStore = useThemeStore()
const notifStore = useNotificationsStore()
const router = useRouter()
const sidebarOpen = ref(false)


// Bell
const bellOpen = ref(false)
const bellRef = ref(null)

function toggleBell() {
  bellOpen.value = !bellOpen.value
  if (bellOpen.value) notifStore.fetchNotifications()
}

function handleNotifClick(n) {
  if (!n.is_read) notifStore.markRead(n.id)
  if (n.order) {
    bellOpen.value = false
    router.push(`/orders/${n.order}`)
  }
}

function formatNotifTime(ts) {
  const d = new Date(ts)
  const diff = (Date.now() - d.getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return d.toLocaleDateString()
}

function handleBellOutsideClick(e) {
  if (bellRef.value && !bellRef.value.contains(e.target)) bellOpen.value = false
}

// Live notifications over WebSocket, with a 60 s unread-count poll as fallback
let notifPollTimer = null
let offNotification = null
const toast = useToast()

function startLiveNotifications() {
  notifStore.connectLive()
  if (!offNotification) {
    offNotification = notifStore.onNotification((n) => {
      toast.info(n.message)
      if (n.notification_type === 'payment_due' || n.notification_type === 'payment_received') {
        refreshTabTitle()
      }
    })
  }
}

function stopLiveNotifications() {
  notifStore.disconnectLive()
  if (offNotification) { offNotification(); offNotification = null }
}

// Close sidebar on Escape
function handleKey(e) {
  if (e.key === 'Escape') { sidebarOpen.value = false; bellOpen.value = false }
}

// Scroll shadow
const scrolled = ref(false)
function handleScroll() { scrolled.value = window.scrollY > 4 }
onMounted(() => {
  window.addEventListener('scroll', handleScroll, { passive: true })
  window.addEventListener('keydown', handleKey)
  document.addEventListener('mousedown', handleBellOutsideClick)
  if (authStore.isAuthenticated) {
    notifStore.fetchUnreadCount()
    notifPollTimer = setInterval(() => notifStore.fetchUnreadCount(), 60_000)
    startLiveNotifications()
  }
})
onUnmounted(() => {
  window.removeEventListener('scroll', handleScroll)
  window.removeEventListener('keydown', handleKey)
  document.removeEventListener('mousedown', handleBellOutsideClick)
  if (notifPollTimer) clearInterval(notifPollTimer)
  stopLiveNotifications()
})

async function refreshTabTitle() {
  if (!authStore.isAuthenticated) { document.title = 'OrderQ'; return }
  try {
    const res = await api.get('/orders/pending_payments/')
    const count = res.data.length
    document.title = count > 0 ? `(${count}) OrderQ` : 'OrderQ'
  } catch {
    document.title = 'OrderQ'
  }
}
onMounted(refreshTabTitle)
watch(() => authStore.isAuthenticated, (auth) => {
  if (auth) {
    refreshTabTitle()
    notifStore.fetchUnreadCount()
    notifPollTimer = setInterval(() => notifStore.fetchUnreadCount(), 60_000)
    startLiveNotifications()
  } else {
    document.title = 'OrderQ'
    if (notifPollTimer) { clearInterval(notifPollTimer); notifPollTimer = null }
    stopLiveNotifications()
  }
})

// ── SidebarLink helper component ───────────────────────────────
const iconPaths = {
  home:        'M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6',
  orders:      'M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01',
  wheel:       'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z',
  reports:     'M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z',
  payments:    'M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z',
  feedback:    'M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z',
  profile:     'M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z',
  restaurants: 'M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4',
  'add-user':  'M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z',
  users:       'M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z',
}

const SidebarLink = defineComponent({
  props: { to: String, icon: String, exact: Boolean },
  emits: ['click'],
  setup(props, { slots, emit }) {
    return () => h(
      RouterLink,
      {
        to: props.to,
        class: 'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-indigo-50 dark:hover:bg-indigo-900/20 hover:text-indigo-700 dark:hover:text-indigo-300 transition-colors group',
        activeClass: 'bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300',
        exactActiveClass: props.exact ? 'bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300' : undefined,
        onClick: () => emit('click'),
      },
      () => [
        h('svg', { class: 'w-5 h-5 shrink-0 opacity-70 group-hover:opacity-100', fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24' }, [
          h('path', { 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: iconPaths[props.icon] || '' })
        ]),
        h('span', {}, slots.default?.()),
      ]
    )
  }
})
</script>

<style>
/* ── Page transitions ──────────────────────────────────────── */
.page-enter-active,
.page-leave-active {
  transition: opacity 0.18s ease, transform 0.18s ease;
}
.page-enter-from {
  opacity: 0;
  transform: translateY(6px);
}
.page-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}

/* ── Sidebar transitions ──────────────────────────────────── */
.sidebar-backdrop-enter-active,
.sidebar-backdrop-leave-active {
  transition: opacity 0.2s ease;
}
.sidebar-backdrop-enter-from,
.sidebar-backdrop-leave-to {
  opacity: 0;
}

.sidebar-panel-enter-active,
.sidebar-panel-leave-active {
  transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1);
}
.sidebar-panel-enter-from,
.sidebar-panel-leave-to {
  transform: translateX(-100%);
}

/* ── Bell dropdown ───────────────────────────────────────── */
.bell-drop-enter-active,
.bell-drop-leave-active {
  transition: opacity 0.15s ease, transform 0.15s ease;
}
.bell-drop-enter-from,
.bell-drop-leave-to {
  opacity: 0;
  transform: translateY(-6px) scale(0.97);
}
</style>
