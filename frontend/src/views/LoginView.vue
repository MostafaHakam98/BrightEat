<template>
  <div class="relative min-h-screen flex flex-col bg-gradient-to-br from-slate-50 via-indigo-50/30 to-slate-100 dark:from-gray-950 dark:via-indigo-950/20 dark:to-gray-900">
    <!-- Thin indigo accent line at the very top -->
    <div class="absolute top-0 left-0 right-0 h-1 bg-indigo-500 z-10"></div>

    <div class="flex-1 flex items-center justify-center py-16 px-4 sm:px-6 lg:px-8">
      <div class="max-w-md w-full space-y-8">
        <div class="flex flex-col items-center">
          <img src="/favicon.svg" alt="OrderQ Logo" class="h-24 w-24 mb-4" />
          <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900 dark:text-white">
            Sign in to OrderQ
          </h2>
        </div>

        <!-- Card -->
        <div class="shadow-xl shadow-indigo-500/5 border border-gray-100 dark:border-gray-800 backdrop-blur-sm bg-white/90 dark:bg-gray-900/90 rounded-2xl p-8">
          <form class="space-y-6" @submit.prevent="handleLogin">
            <div class="space-y-3">
              <div>
                <label for="username" class="sr-only">Username or Email</label>
                <input
                  id="username"
                  v-model="username"
                  name="username"
                  type="text"
                  required
                  class="appearance-none rounded-lg relative block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 placeholder-gray-500 dark:placeholder-gray-400 text-gray-900 dark:text-white dark:bg-gray-800 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                  placeholder="Username or Email"
                />
              </div>
              <div>
                <label for="password" class="sr-only">Password</label>
                <input
                  id="password"
                  v-model="password"
                  name="password"
                  type="password"
                  required
                  class="appearance-none rounded-lg relative block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 placeholder-gray-500 dark:placeholder-gray-400 text-gray-900 dark:text-white dark:bg-gray-800 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                  placeholder="Password"
                />
              </div>
            </div>

            <div v-if="error" class="text-red-600 dark:text-red-400 text-sm text-center">{{ error }}</div>

            <div>
              <button
                type="submit"
                :disabled="loading"
                class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-lg text-white bg-indigo-600 hover:bg-indigo-700 dark:bg-indigo-500 dark:hover:bg-indigo-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 transition-colors"
              >
                {{ loading ? 'Signing in…' : 'Sign in' }}
              </button>
            </div>

            <div v-if="ssoEnabled" class="relative">
              <div class="absolute inset-0 flex items-center"><div class="w-full border-t border-gray-200 dark:border-gray-700"></div></div>
              <div class="relative flex justify-center text-xs uppercase">
                <span class="bg-white dark:bg-gray-900 px-2 text-gray-400">or</span>
              </div>
            </div>

            <div v-if="ssoEnabled">
              <button
                type="button"
                :disabled="ssoLoading"
                @click="loginWithHive"
                class="w-full flex items-center justify-center gap-2 py-2 px-4 border border-gray-300 dark:border-gray-600 text-sm font-medium rounded-lg text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 transition-colors"
              >
                <svg class="w-4 h-4" viewBox="0 0 21 21" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <rect x="1" y="1" width="9" height="9" fill="#F25022"/>
                  <rect x="11" y="1" width="9" height="9" fill="#7FBA00"/>
                  <rect x="1" y="11" width="9" height="9" fill="#00A4EF"/>
                  <rect x="11" y="11" width="9" height="9" fill="#FFB900"/>
                </svg>
                {{ ssoLoading ? 'Redirecting…' : 'Login with Hive (Microsoft)' }}
              </button>
            </div>

            <div class="text-center">
              <p class="text-sm text-gray-600 dark:text-gray-400">
                Contact your manager to create an account
              </p>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import api from '../api'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

const username = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const ssoEnabled = ref(false)
const ssoLoginUrl = ref('')
const ssoLoading = ref(false)

const SSO_ERROR_MESSAGES = {
  state_mismatch:  'Security check failed. Please try again.',
  token_error:     'Could not complete sign-in with Microsoft.',
  no_email:        'No email was returned by Microsoft.',
  user_not_found:  'Your Microsoft account is not registered in OrderQ. Contact your administrator.',
  user_inactive:   'Your account is inactive.',
  not_configured:  'Microsoft sign-in is not configured on this server.',
}

onMounted(async () => {
  const ssoError = route.query.sso_error
  if (ssoError) {
    error.value = SSO_ERROR_MESSAGES[ssoError] || `Sign-in error: ${ssoError}`
  }
  try {
    const res = await api.get('/auth/microsoft/status/')
    ssoEnabled.value = res.data.enabled
    ssoLoginUrl.value = res.data.login_url || ''
  } catch {
    ssoEnabled.value = false
  }
})

async function handleLogin() {
  loading.value = true
  error.value = ''

  const result = await authStore.login(username.value, password.value)

  if (result.success) {
    // Honor ?next= so invite links land the user on the order they were sent
    const next = typeof route.query.next === 'string' && route.query.next.startsWith('/')
      ? route.query.next : '/'
    router.push(next)
  } else {
    error.value = result.error
  }

  loading.value = false
}

function loginWithHive() {
  if (!ssoLoginUrl.value) return
  ssoLoading.value = true
  // Navigate directly to the external Hive URL — cross-origin navigations
  // bypass the service worker, avoiding the SW/redirect conflict.
  window.location.href = ssoLoginUrl.value
}
</script>
