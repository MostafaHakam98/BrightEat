import axios from 'axios'
import { progressStart, progressStop } from './composables/useGlobalProgress'

// Always relative: nginx proxies /api in production, the Vite dev/preview
// server proxies it locally (see vite.config.js server.proxy).
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api'

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Add token to requests + drive the global top progress bar
api.interceptors.request.use(
  (config) => {
    // Never send a (possibly stale) Bearer token to credential endpoints —
    // JWT auth runs before the view, so an expired stored token 401s the
    // login itself ("Given token not valid for any token type").
    const isAuthEndpoint = ['/auth/login/', '/auth/refresh/', '/auth/quick-join/']
      .some((p) => config.url?.includes(p))
    const token = localStorage.getItem('access_token')
    if (token && !isAuthEndpoint) {
      config.headers.Authorization = `Bearer ${token}`
    }
    progressStart()
    return config
  },
  (error) => {
    progressStop()
    return Promise.reject(error)
  }
)

// Handle token refresh on 401
api.interceptors.response.use(
  (response) => {
    progressStop()
    return response
  },
  async (error) => {
    progressStop()
    const originalRequest = error.config
    
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true
      
      try {
        const refreshToken = localStorage.getItem('refresh_token')
        const response = await axios.post(`${API_BASE_URL}/auth/refresh/`, {
          refresh: refreshToken,
        })
        
        const { access } = response.data
        localStorage.setItem('access_token', access)
        
        originalRequest.headers.Authorization = `Bearer ${access}`
        return api(originalRequest)
      } catch (refreshError) {
        localStorage.removeItem('access_token')
        localStorage.removeItem('refresh_token')
        window.location.href = '/login'
        return Promise.reject(refreshError)
      }
    }
    
    return Promise.reject(error)
  }
)

export default api

