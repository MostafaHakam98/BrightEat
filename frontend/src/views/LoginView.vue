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
          <p v-if="hiveMode" class="mt-2 text-sm text-center text-indigo-600 dark:text-indigo-400 font-medium">
            Enter your BSACAIPortal (Hive) username and password below
          </p>
        </div>

        <!-- Card -->
        <div class="shadow-xl shadow-indigo-500/5 border border-gray-100 dark:border-gray-800 backdrop-blur-sm bg-white/90 dark:bg-gray-900/90 rounded-2xl p-8">
          <form class="space-y-6" @submit.prevent="handleLogin">
            <div
              class="space-y-3 transition-all"
              :class="hiveMode ? 'ring-2 ring-indigo-500 ring-offset-2 dark:ring-offset-gray-900 rounded-xl p-1' : ''"
            >
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
                :class="[
                  'group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 transition-colors',
                  hiveMode
                    ? 'bg-indigo-600 hover:bg-indigo-700 dark:bg-indigo-500 dark:hover:bg-indigo-600 focus:ring-indigo-500'
                    : 'bg-indigo-600 hover:bg-indigo-700 dark:bg-indigo-500 dark:hover:bg-indigo-600 focus:ring-indigo-500',
                ]"
              >
                {{ loading ? 'Signing in…' : hiveMode ? 'Sign in with Hive' : 'Sign in' }}
              </button>
            </div>

            <!-- Divider -->
            <div class="relative">
              <div class="absolute inset-0 flex items-center">
                <div class="w-full border-t border-gray-300 dark:border-gray-600"></div>
              </div>
              <div class="relative flex justify-center text-sm">
                <span class="px-2 bg-white/90 dark:bg-gray-900/90 text-gray-500 dark:text-gray-400">or</span>
              </div>
            </div>

            <!-- Hive SSO button -->
            <div>
              <button
                type="button"
                @click="toggleHiveMode"
                :class="[
                  'w-full flex items-center justify-center gap-2 py-2 px-4 border text-sm font-medium rounded-lg focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors',
                  hiveMode
                    ? 'border-indigo-500 bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300'
                    : 'border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700',
                ]"
              >
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
                </svg>
                {{ hiveMode ? 'Using Hive credentials ✓' : 'Continue with Hive (BSACAIPortal)' }}
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
import { ref, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const username = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const hiveMode = ref(false)

function toggleHiveMode() {
  hiveMode.value = !hiveMode.value
  if (hiveMode.value) {
    nextTick(() => document.getElementById('username')?.focus())
  }
}

async function handleLogin() {
  loading.value = true
  error.value = ''

  const result = await authStore.login(username.value, password.value)

  if (result.success) {
    router.push('/')
  } else {
    error.value = result.error
  }

  loading.value = false
}
</script>
