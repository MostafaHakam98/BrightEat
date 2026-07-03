import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

vi.mock('../../src/api', () => ({
  default: { get: vi.fn(), post: vi.fn(), patch: vi.fn(), delete: vi.fn() },
}))

import api from '../../src/api'
import { useOrdersStore } from '../../src/stores/orders'

describe('orders store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  it('fetchMenus populates the store ref (regression: local shadowing left it empty)', async () => {
    const store = useOrdersStore()
    const menus = [{ id: 1, name: 'Main', is_active: true }]
    api.get.mockResolvedValue({ data: menus })

    const result = await store.fetchMenus(7)

    expect(result.success).toBe(true)
    expect(result.data).toEqual(menus)
    expect(store.menus).toEqual(menus)
    expect(api.get).toHaveBeenCalledWith('/menus/', { params: { restaurant: 7 } })
  })

  it('lockOrder sends custom_amounts only when provided', async () => {
    const store = useOrdersStore()
    api.post.mockResolvedValue({ data: { id: 1, status: 'LOCKED' } })

    await store.lockOrder(1)
    expect(api.post).toHaveBeenCalledWith('/orders/1/lock/', {})

    await store.lockOrder(1, { 5: '80.00' })
    expect(api.post).toHaveBeenCalledWith('/orders/1/lock/', { custom_amounts: { 5: '80.00' } })
  })

  it('lockOrder surfaces backend errors (e.g. invalid custom split)', async () => {
    const store = useOrdersStore()
    api.post.mockRejectedValue({ response: { data: { error: 'Custom split is missing amounts' } } })

    const result = await store.lockOrder(1, {})
    expect(result.success).toBe(false)
    expect(result.error.error).toMatch(/custom split/i)
  })

  it('uploadPaymentProof posts multipart form data', async () => {
    const store = useOrdersStore()
    api.post.mockResolvedValue({ data: { id: 9, proof_status: 'claimed' } })

    const file = new File(['x'], 'proof.png', { type: 'image/png' })
    const result = await store.uploadPaymentProof(9, file)

    expect(result.success).toBe(true)
    const [url, body] = api.post.mock.calls[0]
    expect(url).toBe('/payments/9/upload_proof/')
    expect(body).toBeInstanceOf(FormData)
    expect(body.get('proof')).toBe(file)
  })
})
