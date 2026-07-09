import { test, expect } from '@playwright/test'

/* The golden path: login → create order → add item → lock.
 * Seed data comes from scripts/run-e2e.sh (user e2e_collector, restaurant
 * "E2E Diner" with item "E2E Burger"). */

test('golden path: login, create order, add item, lock', async ({ page }) => {
  // ── Login ──
  await page.goto('/login')
  await page.getByPlaceholder('Username or Email').fill('e2e_collector')
  await page.getByPlaceholder('Password').fill('testpass123')
  await page.getByRole('button', { name: /sign in/i }).click()
  // Home is tabbed now — the create form lives behind the "New order" tab
  const newOrderTab = page.getByRole('button', { name: /new order/i }).first()
  await expect(newOrderTab).toBeVisible({ timeout: 15_000 })
  await newOrderTab.click()
  await expect(page.getByRole('heading', { name: /create new order/i })).toBeVisible()

  // ── Create order ──
  await page.getByPlaceholder('Search restaurant…').fill('E2E Diner')
  await page.locator('li', { hasText: 'E2E Diner' }).first().click()
  // Menu is required; its options load after the restaurant is picked
  const menuSelect = page.getByRole('combobox').first()
  await expect(menuSelect.locator('option', { hasText: 'E2E Menu' })).toHaveCount(1, { timeout: 15_000 })
  await menuSelect.selectOption({ label: 'E2E Menu' })
  await page.getByRole('button', { name: /create order/i }).click()

  // Lands on the order page, order is OPEN
  await expect(page).toHaveURL(/\/orders\/[A-Z0-9]{6}/, { timeout: 15_000 })
  await expect(page.getByText(/open/i).first()).toBeVisible()

  // ── Add an item ──
  // The picker input only carries this placeholder once menu items have loaded
  const search = page.getByPlaceholder('Search menu items…')
  await expect(search).toBeVisible({ timeout: 15_000 })
  await search.fill('E2E Burger')
  // Dropdown options select on mousedown (the input's blur closes the list)
  await page.getByRole('button', { name: /E2E Burger/ }).first().dispatchEvent('mousedown')
  const addButton = page.getByRole('button', { name: /^add$/i }).first()
  await expect(addButton).toBeEnabled()
  await addButton.click()
  await expect(page.getByText(/e2e burger/i).first()).toBeVisible({ timeout: 15_000 })

  // ── Lock ──
  await page.getByRole('button', { name: /lock order/i }).first().click()
  // Confirm dialog (if the action asks for confirmation)
  const confirm = page.getByRole('button', { name: /^confirm$/i })
  if (await confirm.isVisible({ timeout: 2_000 }).catch(() => false)) {
    await confirm.click()
  }
  await expect(page.getByText(/locked/i).first()).toBeVisible({ timeout: 15_000 })
})

test('protected routes deep-link through login via ?next', async ({ page }) => {
  await page.goto('/pending-payments')
  await expect(page).toHaveURL(/\/login\?next=(%2F|\/)pending-payments/)
  await page.getByPlaceholder('Username or Email').fill('e2e_collector')
  await page.getByPlaceholder('Password').fill('testpass123')
  await page.getByRole('button', { name: /sign in/i }).click()
  await expect(page).toHaveURL(/\/pending-payments/, { timeout: 15_000 })
})

test('guest quick-join: invite link → name → placed in the order', async ({ page }) => {
  // Arrange an OPEN order via the API (collector creates it)
  const login = await page.request.post('/api/auth/login/', {
    data: { username: 'e2e_collector', password: 'testpass123' },
  })
  const { access } = await login.json()
  const auth = { Authorization: `Bearer ${access}` }
  const restaurants = await (await page.request.get('/api/restaurants/', { headers: auth })).json()
  const list = restaurants.results || restaurants
  const diner = list.find(r => r.name === 'E2E Diner')
  const order = await (await page.request.post('/api/orders/', {
    headers: auth, data: { restaurant: diner.id },
  })).json()

  // Act: an anonymous visitor opens the invite link — sign-in is the default,
  // guest join is behind an explicit opt-in
  await page.goto(`/join/${order.code}`)
  await expect(page.getByRole('button', { name: /sign in to join/i })).toBeVisible()
  await page.getByRole('button', { name: /continue as guest/i }).click()
  await page.getByPlaceholder('e.g. Sara').fill('Guest Omar')
  await page.getByRole('button', { name: /join as guest/i }).click()

  // Assert: lands authenticated on the order page
  await expect(page).toHaveURL(new RegExp(`/orders/${order.code}`), { timeout: 15_000 })
  await expect(page.getByText(/e2e diner/i).first()).toBeVisible()
})
