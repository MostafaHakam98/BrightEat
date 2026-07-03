import { defineConfig } from '@playwright/test'

/* E2E golden path. The backend must already be running on
 * VITE_PROXY_TARGET (default http://127.0.0.1:8000) with the e2e seed data —
 * use scripts/run-e2e.sh from the repo root, which orchestrates all of it. */
export default defineConfig({
  testDir: 'tests/e2e',
  timeout: 60_000,
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL: 'http://127.0.0.1:4173',
    trace: 'retain-on-failure',
  },
  webServer: {
    // --host 127.0.0.1 matters: on CI runners `localhost` binds IPv6-only,
    // and the url check below probes IPv4, which then never connects.
    command: 'npx vite build && npx vite preview --host 127.0.0.1 --port 4173 --strictPort',
    url: 'http://127.0.0.1:4173',
    reuseExistingServer: !process.env.CI,
    timeout: 180_000,
  },
})
