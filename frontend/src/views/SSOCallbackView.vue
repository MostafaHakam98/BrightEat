<template>
  <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-50 via-indigo-50/30 to-slate-100 dark:from-gray-950 dark:via-indigo-950/20 dark:to-gray-900">
    <div class="text-center">
      <div v-if="error" class="space-y-4">
        <p class="text-red-600 dark:text-red-400 text-lg font-medium">Sign-in failed</p>
        <p class="text-gray-600 dark:text-gray-400 text-sm max-w-sm mx-auto">{{ errorMessage }}</p>
        <button @click="$router.push('/login')" class="text-indigo-600 dark:text-indigo-400 underline text-sm">
          Back to login
        </button>
      </div>
      <div v-else class="space-y-3">
        <div class="w-8 h-8 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin mx-auto"></div>
        <p class="text-gray-600 dark:text-gray-400">{{ statusMessage }}</p>
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

const error = ref(false)
const errorMessage = ref('')
const statusMessage = ref('Verifying with Hive…')

const HIVE_URL = 'https://acai.brightskiesinc.com'

const SSO_ERROR_MESSAGES = {
  state_mismatch:   'Security check failed. Please try again.',
  token_error:      'Could not complete sign-in with Microsoft.',
  no_email:         'No email was returned by Microsoft.',
  user_not_found:   'Your account is not registered in OrderQ. Contact your administrator.',
  user_inactive:    'Your account is inactive.',
  not_configured:   'SSO is not configured on this server.',
}

onMounted(async () => {
  // Handle ?sso_error from backend redirects
  const ssoError = route.query.sso_error
  if (ssoError) {
    error.value = true
    errorMessage.value = SSO_ERROR_MESSAGES[ssoError] || `Sign-in error: ${ssoError}`
    return
  }

  // The normal path: browser was redirected here from Hive after Microsoft auth.
  // Ask Hive's check endpoint who is logged in (credentialed CORS request).
  if (route.query.sso === 'success' || !route.query.sso_error) {
    try {
      statusMessage.value = 'Verifying with Hive…'
      const hiveResp = await fetch(`${HIVE_URL}/api/users/auth/check/`, {
        credentials: 'include',
      })

      if (!hiveResp.ok) {
        throw new Error(`Hive check returned ${hiveResp.status}`)
      }

      const hiveData = await hiveResp.json()

      if (!hiveData.authenticated || !hiveData.user?.email) {
        error.value = true
        errorMessage.value = 'Hive session not found. Please try signing in again.'
        return
      }

      statusMessage.value = 'Signing you in to OrderQ…'
      const orderqResp = await api.post('/auth/hive-sso/', { email: hiveData.user.email })
      const { access, refresh } = orderqResp.data

      authStore.setTokens(access, refresh)
      await authStore.fetchUser()
      router.replace('/')
    } catch (err) {
      error.value = true
      const detail = err.response?.data?.error || err.message || 'Unknown error'
      errorMessage.value = detail
    }
  }
})
</script>
