# OrderQ Product & Engineering Backlog

Prioritized backlog derived from a full repo audit (backend, Vue frontend, Flutter PWA, infra) on 2026-07-03.
Status legend: `[ ]` open · `[x]` done · `[~]` partially done / in progress.

Tiers are ordered by user impact per unit of effort:

- **Tier 0** — broken or dangerous in production today.
- **Tier 1** — the core product promise: the app should *run* the collection (reminders, cutoffs, live updates), not just record it.
- **Tier 2** — flow ease, reach, and polish.
- **Tier 3** — engineering foundation that protects everything else.
- **Epics** — larger strategic tracks (multi-tenancy, frontend consolidation, i18n).

---

## Tier 0 — Production breakages & critical risks

- [x] **Flutter PWA API URL is hardcoded `http://51.20.151.57:19992/api`** (`mobile/lib/config/app_config.dart`).
  Mobile UAs are routed to the Flutter PWA by `nginx-router.conf`, which is served over HTTPS — plain-HTTP XHR is blocked
  as mixed content, so the deployed mobile app cannot reach the API. Fix: relative `/api` through the nginx proxy
  (same origin), overridable with `--dart-define` for local dev.
- [x] **`custom` fee split silently creates zero payments.** `CollectionOrder.FEE_SPLIT_CHOICES` offers `custom`
  but `_calculate_payments` never handles it: locking such an order produces no `Payment` rows. Fix: support
  per-user amounts supplied at lock time (validated to sum to the order total); reject lock with a clear error
  when amounts are missing or don't add up.
- [x] **`make deploy` never rebuilds/restarts `flutter-pwa`** — mobile ships stale on every deploy. Fix: include it
  in `prod-build` / `deploy` targets.
- [x] **Production `SECRET_KEY` (also the JWT signing key) and DB credentials committed in compose files.**
  Fix: read from `.env` (git-ignored, `.env.example` provided); prod compose fails fast when unset. **Rotate the
  key and DB password on the server when deploying this change** — rotating invalidates existing JWTs (users
  re-login).

## Tier 1 — Close the payment loop (highest user value)

- [x] **Emit the missing notification types** (`order_joined`, `payment_due`, `payment_received`) — they exist in the
  model but nothing creates them:
  - `payment_due` → to each debtor when an order is locked (with their amount).
  - `payment_received` → to the collector when a payment is marked paid.
  - `order_joined` → to the collector when someone joins the order.
- [x] **Explicit join action.** `/join/:code` previously only navigated; users were invisible until they added an item.
  Backend `POST /orders/{id}/join/` registers participation (adds to `assigned_users`), emits `order_joined`,
  broadcasts over WS. Frontend join button calls it.
- [x] **Notify the right people.** `get_participants()` only returned users *with items* — assigned users who hadn't
  ordered yet (exactly who needs the "order locks soon" nudge) got nothing. Notification recipients now include
  `assigned_users` and the collector.
- [x] **Make `cutoff_time` real.** Celery beat job auto-locks OPEN orders past their cutoff and sends a
  "locks in ≤15 min" reminder beforehand; both broadcast over WS.
- [x] **Daily payment reminders.** Celery beat job nags unpaid debtors on LOCKED/ORDERED/CLOSED orders
  (`payment_due` notification, one per unpaid payment per day).
- [x] **Live notifications over WebSocket.** Per-user notification group in the consumer; notifications are pushed
  as they're created instead of relying on the 60 s unread-count poll. Frontend bell updates live.

## Tier 2 — Flow ease & reach

- [x] **Live list pages** — Home/Orders now refresh via the user-level socket (new orders appear without manual refresh).
- [ ] **Web push (PWA push).** The killer notification arrives with the app closed ("order locks in 15 min",
  "you owe 85 EGP"). Requires VAPID keys + `pywebpush` (or FCM) + subscription model + SW push handler in both
  frontends. Depends on Tier 1 plumbing (done).
- [ ] **Declutter `OrderDetailView.vue` (2,000 lines).** A manager-collector sees two Delete buttons and duplicate
  Lock/Close (collector "Actions & Fees" block vs "Manager Actions" block). Unify the action bar; split the view
  into components (items panel, fees panel, payments panel, actions bar).
- [ ] **Dark-mode gaps** — "Assign to User" sub-form in OrderDetail uses light-only classes.
- [x] **`fetchMenus` store bug** — local `const menus` shadowed the Pinia ref, so the store's `menus` state was never
  populated (masked because callers used the return value).
- [x] **Strip production `console.log`s** — the `order` computed in OrderDetail logged on every render.
- [ ] **Offline fallback page** for the Vue PWA; remove the duplicate static `manifest.json`
  (vite-plugin-pwa already emits `manifest.webmanifest`).
- [ ] **Reorder flow race** — menu pre-selection from `/?restaurant=&menu=` depends on `onRestaurantChange()` timing.
- [ ] **A11y pass on custom modals** — Add-to-Menu / Menu-Item / Restaurant / Edit-User modals are plain `<div>`s
  with no `role="dialog"`, `aria-modal`, or focus trap (only `ConfirmDialog` does it right). Icon-only controls
  (copy code, ±, ×) need `aria-label`s.
- [ ] **Flutter parity backlog** — SSO login flow is web-only today; every Tier 1/2 feature above needs a Flutter
  counterpart (see Epic: frontend consolidation).

## Tier 3 — Engineering foundation

- [x] **CI pipeline (GitHub Actions):** backend tests against Postgres + Redis, frontend build, on every push/PR.
- [x] **Tests for the money math** — fee-split calculation (equal / proportional / collector_pays / custom) had zero
  coverage; it's the one place bugs cost users real money. Plus tests for join, notifications, cutoff auto-lock,
  and payment reminders.
- [x] **Automated DB backups** — nightly `pg_dump` script with retention (`scripts/backup_db.sh`) + cron install
  instructions. Offsite copy (S3/rclone) still open:
  - [ ] Offsite/encrypted backup replication + restore drill.
- [x] **Prod compose hardening:** `restart: unless-stopped` on all services, backend healthcheck, removed
  source bind-mounts over images (deploys now run the built artifact), pinned image tags, `depends_on:
  condition: service_healthy` for backend.
- [x] **Stop `makemigrations` + `seed_data` on every boot** — prod entrypoint runs `migrate` only;
  auto-generating migrations at runtime is unsafe and replicas would race.
- [x] **Perf quick wins:**
  - Participants N+1 on the orders list (serializer now reuses prefetched items).
  - DB indexes on hot columns: `Payment(is_paid, user)`, `CollectionOrder(status)`, `Notification(user, is_read)`.
  - Pagination on the notifications endpoint (bell fetches page 1; unbounded growth otherwise).
- [ ] **Money as Decimal end-to-end** — serializers/reports cast to `float` in places; switch API money fields to
  string-decimals and fix clients.
- [ ] **Error tracking + uptime monitoring** — Sentry (backend + frontends) and an uptime check on `/health/`;
  currently the only observability is `docker logs`.
- [ ] **Retention/archival policy for `AuditLog` and `Notification`** — both grow unbounded.
- [ ] **Timezone handling** — `share_message` falls back to manual +2 h because `pytz` isn't installed; use
  `zoneinfo` ("Africa/Cairo") everywhere.
- [ ] **Remove dead code:** `msal` dependency (unused — SSO goes through Hive), `MicrosoftCallbackView` stub,
  `HelloWorld.vue` + Vite starter assets, vestigial `CollectionOrder.instapay_link` (collector's user-level
  link is what's surfaced).

## Epics — strategic tracks

### Epic: Multi-tenancy (ship OrderQ beyond one company)

Today the app assumes a single organization: one user pool, `@brightskiesinc.com` hardcoded in SSO, one Hive
backend, global restaurants/menus. To ship anywhere else:

- [ ] **Tenant model & data isolation.** `Organization` model; scope Users, Restaurants, Menus, Orders, FeePresets,
  Notifications by org FK (shared-schema row-level isolation is the pragmatic start; enforce via a queryset
  mixin/manager so no view can forget the filter). Alternative (`django-tenants` schema-per-tenant) only if
  compliance demands it.
- [ ] **Pluggable auth per tenant.** Local accounts by default; SSO becomes per-tenant configuration
  (issuer, client id, allowed email domains) instead of the Hive-specific flow. Hive/Microsoft becomes one
  provider implementation among several (generic OIDC covers most companies).
  - [x] First step (done): allowed SSO email domain moved from hardcoded string to `HIVE_ALLOWED_EMAIL_DOMAINS`
    env setting.
- [ ] **Tenant onboarding flow** — create org, invite members (email invite links), org-scoped join codes.
- [ ] **Per-tenant branding/config** — name, logo, currency (EGP hardcoded today), timezone, payment rails
  (Instapay is Egypt-specific; make the "payment handle" concept generic: IBAN, PayPal.me, etc.).
- [ ] **Quotas & plans** (only if commercializing): org size limits, billing integration.
- [ ] **Ops**: per-tenant admin, data export/delete per tenant (GDPR-shaped requests).

### Epic: Frontend consolidation (Vue PWA vs Flutter PWA)

Two full frontends are UA-routed alternates of the same product and already drifting (Flutter lacks SSO).
Every feature costs double. Decide:

- **Option A (recommended):** consolidate on the Vue PWA (already installable, responsive, websocket-live);
  keep the Flutter codebase only if/when native Android/iOS builds are actually wanted.
- **Option B:** keep both, but enforce a per-release parity checklist and shared API contract tests.
- [ ] Decision + follow-through.

### Epic: Arabic + RTL i18n

Egyptian audience (EGP, Instapay, Talabat) with an English-only UI.

- [ ] `vue-i18n` scaffold, extract all strings, `dir="rtl"` layout audit, Arabic translations.
- [ ] Locale-aware dates/numbers (`Intl`, `ar-EG`).
- [ ] (If keeping Flutter) mirror with `flutter_localizations`.

### Epic: Payments beyond honor-system

Instapay confirmation is manual/self-reported. Options to explore (Egypt market):

- [ ] Payment-proof upload (screenshot) attached to a `Payment`, collector approves/rejects.
- [ ] InstaPay/IPN or PSP integration if/when a viable API exists; webhook-driven auto-confirmation.
- [ ] Cross-order debt netting ("you owe Ahmed 120 across 3 orders — settle once").

---

## Deferred / nice-to-have

- [ ] Scheduled/recurring orders ("every day at 11:00 open a lunch order from X").
- [ ] Favorites & one-tap reorder of "my usual" per restaurant.
- [ ] Order templates per team.
- [ ] Collector rotation suggestions (fairness stats exist in reports already).
- [ ] Menu item photos in the picker (Talabat `image_url` is already scraped and stored).
- [ ] Slack/Teams webhook integration for order-opened announcements (WhatsApp share text exists).
- [ ] Talabat scraper resilience: alerting on sync failures, snapshot tests against fixture HTML.
