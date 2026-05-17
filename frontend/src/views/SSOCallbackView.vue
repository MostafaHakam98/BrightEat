<template>
  <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-50 via-indigo-50/30 to-slate-100 dark:from-gray-950 dark:via-indigo-950/20 dark:to-gray-900">
    <div class="text-center">
      <div v-if="error" class="space-y-4">
        <p class="text-red-600 dark:text-red-400 text-lg font-medium">Sign-in failed</p>
        <p class="text-gray-600 dark:text-gray-400 text-sm">{{ errorMessage }}</p>
        <button @click="$router.push('/login')" class="text-indigo-600 dark:text-indigo-400 underline text-sm">
          Back to login
        </button>
      </div>
      <div v-else class="space-y-3">
        <div class="w-8 h-8 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin mx-auto"></div>
        <p class="text-gray-600 dark:text-gray-400">Signing you in…</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const error = ref(false)
const errorMessage = ref('')

const SSO_ERROR_MESSAGES = {
  state_mismatch:  'Security check failed. Please try again.',
  token_error:     'Could not complete sign-in with Microsoft.',
  no_email:        'No email was returned by Microsoft.',
  user_not_found:  'Your Microsoft account is not linked to an OrderQ account. Contact your administrator.',
  user_inactive:   'Your account is inactive. Contact your administrator.',
  not_configured:  'Microsoft sign-in is not configured.',
}

onMounted(async () => {
  const ssoError = route.query.sso_error
  if (ssoError) {
    error.value = true
    errorMessage.value = SSO_ERROR_MESSAGES[ssoError] || `Sign-in error: ${ssoError}`
    return
  }

  const access = route.query.access
  const refresh = route.query.refresh
  if (access && refresh) {
    authStore.setTokens(access, refresh)
    await authStore.fetchUser()
    router.replace('/')
    return
  }

  error.value = true
  errorMessage.value = 'Invalid SSO callback. Please try again.'
})
</script>
