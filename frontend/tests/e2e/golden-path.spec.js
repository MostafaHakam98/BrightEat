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
  await expect(page.getByRole('heading', { name: /create new order/i })).toBeVisible({ timeout: 15_000 })

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

test('invite link deep-links through login', async ({ page }) => {
  await page.goto('/join/ZZZZ99')
  // Unauthenticated: lands on login with ?next preserved
  await expect(page).toHaveURL(/\/login\?next=(%2F|\/)join(%2F|\/)ZZZZ99/)
  await page.getByPlaceholder('Username or Email').fill('e2e_collector')
  await page.getByPlaceholder('Password').fill('testpass123')
  await page.getByRole('button', { name: /sign in/i }).click()
  // Lands back on the join page (order doesn't exist → not-found state, which is fine)
  await expect(page).toHaveURL(/\/join\/ZZZZ99/, { timeout: 15_000 })
})
