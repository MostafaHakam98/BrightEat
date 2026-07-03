import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

vi.mock('../../src/api', () => ({
  default: { get: vi.fn(), post: vi.fn() },
}))

import { useNotificationsStore } from '../../src/stores/notifications'

class FakeWebSocket {
  static instances = []
  static OPEN = 1
  constructor(url) {
    this.url = url
    this.readyState = FakeWebSocket.OPEN
    this.sent = []
    FakeWebSocket.instances.push(this)
  }
  send(data) { this.sent.push(data) }
  close(code) { this.onclose?.({ code }) }
}

describe('notifications store live socket', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    FakeWebSocket.instances = []
    vi.stubGlobal('WebSocket', FakeWebSocket)
    localStorage.setItem('access_token', 'tok')
  })
  afterEach(() => {
    vi.unstubAllGlobals()
    localStorage.clear()
  })

  it('pushed notifications bump the badge and notify listeners', () => {
    const store = useNotificationsStore()
    const seen = []
    store.onNotification(n => seen.push(n))
    store.connectLive()

    const ws = FakeWebSocket.instances[0]
    expect(ws.url).toContain('/ws/notifications/')

    ws.onmessage({ data: JSON.stringify({ type: 'notification', notification: { id: 1, message: 'You owe 80 EGP', is_read: false } }) })

    expect(store.unreadCount).toBe(1)
    expect(store.notifications[0].message).toBe('You owe 80 EGP')
    expect(seen).toHaveLength(1)
  })

  it('order events reach order listeners and unsubscribe works', () => {
    const store = useNotificationsStore()
    const events = []
    const off = store.onOrderEvent((type, order) => events.push([type, order.id]))
    store.connectLive()

    const ws = FakeWebSocket.instances[0]
    ws.onmessage({ data: JSON.stringify({ type: 'new_order', order: { id: 42 } }) })
    ws.onmessage({ data: JSON.stringify({ type: 'order_update', order: { id: 42 } }) })
    expect(events).toEqual([['new_order', 42], ['order_update', 42]])

    off()
    ws.onmessage({ data: JSON.stringify({ type: 'new_order', order: { id: 43 } }) })
    expect(events).toHaveLength(2)
  })

  it('does not connect without a token', () => {
    localStorage.removeItem('access_token')
    const store = useNotificationsStore()
    store.connectLive()
    expect(FakeWebSocket.instances).toHaveLength(0)
  })

  it('malformed socket messages are ignored', () => {
    const store = useNotificationsStore()
    store.connectLive()
    const ws = FakeWebSocket.instances[0]
    ws.onmessage({ data: 'not-json' })
    expect(store.unreadCount).toBe(0)
  })
})
