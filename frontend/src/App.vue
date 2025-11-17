<template>
  <div class="min-h-screen bg-gray-50">
    <nav v-if="authStore.isAuthenticated" class="bg-white shadow-sm">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex">
            <router-link to="/" class="flex items-center px-2 py-2 text-xl font-bold text-blue-600">
              BrightEat
            </router-link>
            <div class="hidden sm:ml-6 sm:flex sm:space-x-8">
              <router-link
                to="/"
                class="inline-flex items-center px-1 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300"
                active-class="border-blue-500 text-gray-900"
              >
                Home
              </router-link>
              <router-link
                to="/orders"
                class="inline-flex items-center px-1 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300"
                active-class="border-blue-500 text-gray-900"
              >
                Orders
              </router-link>
              <router-link
                v-if="authStore.isManager"
                to="/restaurants"
                class="inline-flex items-center px-1 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300"
                active-class="border-blue-500 text-gray-900"
              >
                Restaurants
              </router-link>
              <router-link
                v-if="authStore.isManager"
                to="/register"
                class="inline-flex items-center px-1 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300"
                active-class="border-blue-500 text-gray-900"
              >
                Create User
              </router-link>
              <router-link
                to="/reports"
                class="inline-flex items-center px-1 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300"
                active-class="border-blue-500 text-gray-900"
              >
                Reports
              </router-link>
              <router-link
                to="/pending-payments"
                class="inline-flex items-center px-1 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300"
                active-class="border-blue-500 text-gray-900"
              >
                Pending Payments
              </router-link>
              <router-link
                to="/recommendations"
                class="inline-flex items-center px-1 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300"
                active-class="border-blue-500 text-gray-900"
              >
                Recommendations
              </router-link>
              <router-link
                to="/profile"
                class="inline-flex items-center px-1 pt-1 border-b-2 border-transparent text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300"
                active-class="border-blue-500 text-gray-900"
              >
                Profile
              </router-link>
            </div>
          </div>
          <div class="flex items-center">
            <span class="text-sm text-gray-700 mr-4">{{ authStore.user?.username }}</span>
            <button
              @click="authStore.logout()"
              class="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-md text-sm font-medium"
            >
              Logout
            </button>
          </div>
        </div>
      </div>
    </nav>
    <main>
      <router-view />
    </main>
  </div>
</template>

<script setup>
import { useAuthStore } from './stores/auth'

const authStore = useAuthStore()
</script>
