<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900">
    <nav
      v-if="authStore.isAuthenticated"
      :class="[
        'bg-white/80 dark:bg-gray-900/80 backdrop-blur-md border-b border-gray-200/50 dark:border-gray-700/50 sticky top-0 z-40 transition-shadow duration-200',
        scrolled ? 'shadow-md shadow-black/5 dark:shadow-black/20' : ''
      ]"
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex">
            <router-link to="/" class="flex items-center px-2 py-2 text-2xl font-extrabold text-indigo-600 dark:text-indigo-400 tracking-tight">
              OrderQ
            </router-link>
            <div class="hidden sm:ml-6 sm:flex sm:space-x-1">
              <router-link
                to="/"
                class="inline-flex items-center px-3 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-indigo-300 dark:hover:border-indigo-600 transition-colors"
                active-class="border-indigo-500 dark:border-indigo-400 text-gray-900 dark:text-white"
              >
                Home
              </router-link>
              <router-link
                to="/orders"
                class="inline-flex items-center px-3 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-indigo-300 dark:hover:border-indigo-600 transition-colors"
                active-class="border-indigo-500 dark:border-indigo-400 text-gray-900 dark:text-white"
              >
                Orders
              </router-link>
              <router-link
                to="/reports"
                class="inline-flex items-center px-3 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-indigo-300 dark:hover:border-indigo-600 transition-colors"
                active-class="border-indigo-500 dark:border-indigo-400 text-gray-900 dark:text-white"
              >
                Reports
              </router-link>
              <router-link
                to="/pending-payments"
                class="inline-flex items-center px-3 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-indigo-300 dark:hover:border-indigo-600 transition-colors"
                active-class="border-indigo-500 dark:border-indigo-400 text-gray-900 dark:text-white"
              >
                Payments
              </router-link>
              <router-link
                to="/recommendations"
                class="inline-flex items-center px-3 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-indigo-300 dark:hover:border-indigo-600 transition-colors"
                active-class="border-indigo-500 dark:border-indigo-400 text-gray-900 dark:text-white"
              >
                Feedback
              </router-link>
              <router-link
                to="/wheel"
                class="inline-flex items-center px-3 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-indigo-300 dark:hover:border-indigo-600 transition-colors"
                active-class="border-indigo-500 dark:border-indigo-400 text-gray-900 dark:text-white"
              >
                🎡 Wheel
              </router-link>
              <router-link
                v-if="authStore.isManager || authStore.isAdmin"
                to="/restaurants"
                class="inline-flex items-center px-3 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-indigo-300 dark:hover:border-indigo-600 transition-colors"
                active-class="border-indigo-500 dark:border-indigo-400 text-gray-900 dark:text-white"
              >
                Restaurants
              </router-link>
              <router-link
                v-if="authStore.isAdmin"
                to="/register"
                class="inline-flex items-center px-3 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-indigo-300 dark:hover:border-indigo-600 transition-colors"
                active-class="border-indigo-500 dark:border-indigo-400 text-gray-900 dark:text-white"
              >
                Create User
              </router-link>
              <router-link
                v-if="authStore.isAdmin"
                to="/users"
                class="inline-flex items-center px-3 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-indigo-300 dark:hover:border-indigo-600 transition-colors"
                active-class="border-indigo-500 dark:border-indigo-400 text-gray-900 dark:text-white"
              >
                User Management
              </router-link>
              <router-link
                to="/profile"
                class="inline-flex items-center px-3 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-indigo-300 dark:hover:border-indigo-600 transition-colors"
                active-class="border-indigo-500 dark:border-indigo-400 text-gray-900 dark:text-white"
              >
                Profile
              </router-link>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <button
              @click="themeStore.toggleTheme()"
              class="p-2 rounded-md text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition-colors"
              :title="themeStore.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
            >
              <svg v-if="themeStore.isDark" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
              <svg v-else class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
              </svg>
            </button>
            <!-- Avatar with initials -->
            <div class="flex items-center gap-2">
              <span
                class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-indigo-600 dark:bg-indigo-500 text-white text-sm font-semibold select-none"
                :title="authStore.user?.username"
              >
                {{ authStore.user?.username?.charAt(0)?.toUpperCase() || '?' }}
              </span>
              <span class="text-sm font-medium text-gray-700 dark:text-gray-300 hidden md:inline">{{ authStore.user?.username }}</span>
            </div>
            <button
              @click="authStore.logout()"
              class="px-3 py-1.5 rounded-md text-sm font-medium border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:border-red-300 dark:hover:border-red-700 hover:text-red-600 dark:hover:text-red-400 transition-colors"
            >
              Logout
            </button>
          </div>
        </div>
      </div>
    </nav>
    <main class="dark:bg-gray-900">
      <router-view />
    </main>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, onUnmounted } from 'vue'
import { useAuthStore } from './stores/auth'
import { useThemeStore } from './stores/theme'
import api from './api'

const authStore = useAuthStore()
const themeStore = useThemeStore()

// Scroll shadow
const scrolled = ref(false)
function handleScroll() {
  scrolled.value = window.scrollY > 4
}
onMounted(() => window.addEventListener('scroll', handleScroll, { passive: true }))
onUnmounted(() => window.removeEventListener('scroll', handleScroll))

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
  if (auth) refreshTabTitle()
  else document.title = 'OrderQ'
})
</script>
