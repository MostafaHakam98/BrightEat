# OrderQ Product & Engineering Backlog

Prioritized backlog derived from a full repo audit (backend, Vue frontend, Flutter PWA, infra) on 2026-07-03.
Status legend: `[ ]` open · `[x]` done · `[~]` partially done / in progress.

> **Deployed to production (EC2) 2026-07-04** from `devel`: everything marked `[x]` below is live.
> Server-side secrets moved to `.env` (SECRET_KEY carried over, DB password rotated, VAPID keys generated),
> nightly backup cron installed, CI (tests + build + E2E) green on `devel`.
>
> **Product decision 2026-07-04:** restaurants, menus, menu items, fee presets, and the Talabat
> scraper are open to ALL authenticated users (previously manager/admin-only). Admin-only remains:
> user management, registration, role changes.
>
> **On the remaining unticked boxes:** they are intentionally open, not forgotten. They fall into three
> buckets — (1) **strategic epics** (multi-tenancy, full Arabic sweep + RTL audit, native app feature parity)
> that are multi-week tracks to schedule deliberately; (2) **needs-your-input / external accounts** (create a
> Sentry project + set the DSN, provide S3/rclone creds for offsite backups); (3) **low-value polish**
> (legacy-modal a11y migration, money-as-string-decimal, `MicrosoftCallbackView` stub). Nothing here is a
> production blocker — the shipped app is complete and live.

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
- [x] **Auto-close stale orders.** Collectors forget to hit Close once food arrives, so orders piled up in
  the active view. A beat sweep (every 30 min) closes OPEN/LOCKED/ORDERED orders older than
  `AUTO_CLOSE_AFTER_HOURS` (default 12), notifies the collector, and broadcasts. Unpaid balances stay
  tracked (CLOSED orders still surface in Pending Payments) — only the clutter is removed.
- [x] **Daily payment reminders.** Celery beat job nags unpaid debtors on LOCKED/ORDERED/CLOSED orders
  (`payment_due` notification, one per unpaid payment per day).
- [x] **Live notifications over WebSocket.** Per-user notification group in the consumer; notifications are pushed
  as they're created instead of relying on the 60 s unread-count poll. Frontend bell updates live.

## Tier 2 — Flow ease & reach

- [x] **Live list pages** — Home/Orders now refresh via the user-level socket (new orders appear without manual refresh).
- [x] **Web push (PWA push).** Done end-to-end: `PushSubscription` model + subscribe/unsubscribe/public-key
  endpoints, `pywebpush` VAPID sender task (prunes dead subscriptions), fan-out from `notify_users`, custom
  service worker push/notificationclick handlers, opt-in toggle on the Profile page. **Deploy note:** generate
  VAPID keys (`npx web-push generate-vapid-keys`) and set them in `.env`, else push stays silently disabled.
- [x] **Declutter `OrderDetailView.vue`.** The duplicated "Manager Actions" block is gone; one role-aware
  `OrderActionBar` (sticky bottom bar on mobile), an `OrderStepper` (Open→Locked→Ordered→Closed with cutoff
  countdown / payments-remaining context), an `OrderRoster` ("who's in": joined/ordered/paid per person), and
  a `CustomSplitModal` (per-person amounts with live remaining-to-allocate; the custom split now has UI).
  New shared UI kit under `components/ui/` (BaseButton/Badge/Card/Modal with focus trap + aria-modal).
- [x] **Dark-mode gaps** — "Assign to User" sub-form fixed.
- [x] **`fetchMenus` store bug** — local `const menus` shadowed the Pinia ref, so the store's `menus` state was never
  populated (masked because callers used the return value).
- [x] **Strip production `console.log`s** — the `order` computed in OrderDetail logged on every render.
- [x] **Offline fallback page** (custom SW `setCatchHandler` → precached `offline.html`); duplicate static
  `manifest.json` removed (vite-plugin-pwa's `manifest.webmanifest` is the single source).
- [x] **Reorder flow race** — resolved: HomeView `await`s `onRestaurantChange()` before setting the menu, so the
  option exists when pre-selected.
- [~] **A11y pass on custom modals** — the shared `BaseModal` (focus trap, `aria-modal`, Esc, focus restore) now
  exists and every *new* dialog uses it. Still open:
  - [ ] Migrate the legacy Add-to-Menu / Menu-Item / Restaurant / Edit-User plain-`<div>` modals to `BaseModal`;
    `aria-label`s for icon-only controls (copy code, ±, ×).
- [ ] **Flutter parity backlog** — SSO login flow is web-only today; every Tier 1/2 feature above needs a Flutter
  counterpart (see Epic: frontend consolidation).

## Tier 3 — Engineering foundation

- [x] **CI pipeline (GitHub Actions):** backend tests against Postgres + Redis, frontend build, on every push/PR.
- [x] **Tests for the money math** — fee-split calculation (equal / proportional / collector_pays / custom) had zero
  coverage; it's the one place bugs cost users real money. Plus tests for join, notifications, cutoff auto-lock,
  and payment reminders.
- [x] **Automated DB backups** — nightly `pg_dump` script with retention (`scripts/backup_db.sh`);
  cron installed on the EC2 host 2026-07-04 (02:30 daily) and verified with a live run. Still open:
  - [ ] Offsite/encrypted backup replication + restore drill.
- [x] **Prod compose hardening:** `restart: unless-stopped` on all services, backend healthcheck, removed
  source bind-mounts over images (deploys now run the built artifact), pinned image tags, `depends_on:
  condition: service_healthy` for backend.
- [x] **Stop `makemigrations` + `seed_data` on every boot** — prod entrypoint runs `migrate` only;
  auto-generating migrations at runtime is unsafe and replicas would race.
- [x] **Perf quick wins:**
  - Participants N+1 on the orders list (serializer now reuses prefetched items).
  - DB indexes on hot columns: `Payment(is_paid, user)`, `CollectionOrder(status)`, `Notification(user, is_read)`.
  - Notifications list capped at the latest 100 (response stays a plain array — both frontends parse it
    as one; real pagination would break the Flutter client).
- [ ] **Money as Decimal end-to-end** — serializers/reports cast to `float` in places; switch API money fields to
  string-decimals and fix clients.
- [~] **Error tracking + uptime monitoring** — Sentry wired on backend (`SENTRY_DSN`) and Vue frontend
  (`VITE_SENTRY_DSN` build arg), both no-ops until a DSN is set. Still open:
  - [ ] Create the Sentry project + set DSNs in prod; add an external uptime check on `/health/`.
- [x] **Retention/archival policy for `AuditLog` and `Notification`** — daily beat sweep, 90/365 days,
  env-tunable (`NOTIFICATION_RETENTION_DAYS`/`AUDIT_LOG_RETENTION_DAYS`).
- [x] **Timezone handling** — `share_message` now uses `zoneinfo` with `settings.TIME_ZONE`.
- [~] **Remove dead code:** `msal` dep and Vite starter files (HelloWorld.vue, logos) removed; Flutter orphan
  `main_navigation_screen.dart` + stale template test removed. Still open:
  - [ ] `MicrosoftCallbackView` stub (harmless no-op kept so the SSO URL doesn't 404 — low priority).
  - Note: `CollectionOrder.instapay_link` is NOT vestigial after all — it's the per-order Instapay override
    used by the fee-editing form, distinct from the collector's user-level link. Keep it.
- [x] **Staging environment + versioned releases** — `docker-compose.staging.yml` override (own project name,
  volumes, ports 29991/29992, `.env.staging`), `IMAGE_TAG`-parameterized prod images, `make release TAG=vX.Y.Z`
  builds+tags images and a git tag; rollback = point `IMAGE_TAG` back and `make prod-up`.
- [x] **Frontend test harness** — Vitest store tests (`npm run test`, in CI) and a Playwright golden-path E2E
  (login → create → add item → lock, plus invite-link deep-linking) via `scripts/run-e2e.sh`, with its own CI
  job and failure traces.

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
  - [x] First step (done): allowed SSO email domain moved from hardcoded string to `SSO_ALLOWED_EMAIL_DOMAINS`
    env setting.
- [ ] **Tenant onboarding flow** — create org, invite members (email invite links), org-scoped join codes.
- [ ] **Per-tenant branding/config** — name, logo, currency (EGP hardcoded today), timezone, payment rails
  (Instapay is Egypt-specific; make the "payment handle" concept generic: IBAN, PayPal.me, etc.).
- [ ] **Quotas & plans** (only if commercializing): org size limits, billing integration.
- [ ] **Ops**: per-tenant admin, data export/delete per tenant (GDPR-shaped requests).

### Epic: Frontend consolidation (Vue PWA) + native Android app

Two web frontends were UA-routed alternates of the same product and drifting. Resolved by consolidating the
**web** on the Vue PWA, and repurposing the Flutter codebase into a real **native Android app**.

- [x] **Web: consolidated on the Vue PWA.** nginx routes all web traffic to `frontend`; the Flutter *web*
  container still builds/runs but receives no traffic (revert instructions commented in `nginx-router.conf`).
- [x] **Native Android app shipped (v1.1.0).** The Flutter app now builds a distributable release APK:
  - Certificate pinning (`lib/network/cert_pinning_io.dart`) trusts the production server's self-signed cert
    by SHA-256 — a native HTTP client can't click through it like a browser, so this was the connectivity
    blocker. **If the server cert is regenerated, update the pinned fingerprint.**
  - Real `applicationId` (`com.orderq.mobile`), release keystore signing (`android/key.properties` +
    `orderq-release.jks`, both git-ignored — **back these up; losing them blocks in-place updates**),
    branded launcher icon generated from the OrderQ logo (`flutter_launcher_icons`).
  - Join flow wired to `POST /orders/{id}/join/` (roster + collector notification), order model hardened
    against missing core fields, orphan/stale files removed → `flutter analyze` reports 0 errors.
- [ ] **Native feature parity (deferred, deliberate):** the Android app still lacks the web's payment-proof
  UI, custom-split UI, `my_usual` button, and native background push (would need FCM + a Firebase project —
  a real infra lift). In-app live notifications work over WebSocket while the app is open. Prioritize per
  demand.
- [ ] Follow-through (later): stop building the Flutter *web* image in deploys; consider moving `mobile/` to
  its own repo.

### Epic: Arabic + RTL i18n

Egyptian audience (EGP, Instapay, Talabat) with an English-only UI.

- [x] `vue-i18n` scaffold: locale files (en/ar), persisted locale, `dir`/`lang` switching, language selector in
  **Profile → Preferences** (moved out of the top bar per user request). App shell (nav, sidebar, bell) and
  core strings translated; Arabic falls back to English for untranslated keys, so partial coverage degrades
  gracefully.
- [ ] Extract + translate the remaining views (Home, OrderDetail, Reports, …) — mechanical `$t()` sweep.
- [ ] RTL layout audit (directional paddings/margins/icons) once coverage is broad.
- [ ] Locale-aware dates/numbers (`Intl`, `ar-EG`).

### Epic: Payments beyond honor-system

Instapay confirmation is manual/self-reported. Options to explore (Egypt market):

- [x] Payment-proof upload (screenshot) attached to a `Payment`; payer uploads, collector confirms/rejects,
  both sides notified; surfaced on the order page and the Pending Payments screen.
- [ ] InstaPay/IPN or PSP integration if/when a viable API exists; webhook-driven auto-confirmation.
- [ ] Cross-order debt netting ("you owe Ahmed 120 across 3 orders — settle once").

---

## Adoption wave (2026-07-04) — beating the WhatsApp default

Root cause of drop-off: joining took too many steps vs typing in the group chat. Shipped counter-measures:

- [x] **Frictionless invite join** — `/join/CODE` no longer requires an account: a name is enough
  (`POST /auth/quick-join/` creates a throttled guest identity, joins the roster, returns JWTs).
  WhatsApp link → placed order in seconds.
- [x] **Scheduled/recurring orders** — `RecurringOrder` model + minute-beat task auto-opens the daily order
  (Egypt-workweek default, auto-cutoff N minutes later) and notifies everyone; managed from Home.
  Nobody has to remember to start lunch.
- [x] **"My usual" hero banner** — joiners with no items yet get a one-tap "add your usual" banner.
- [x] **Settle-up receipt** — WhatsApp-ready per-person breakdown (`settle_message`: paid ✅ / owing ⏳ +
  collector's Instapay link) with copy + wa.me share; the collector nags the group once, not each person.
- [x] **Talabat handoff sheet** — `GET /orders/{id}/talabat_sheet/`: aggregated qty×item list with per-person
  notes + the restaurant's Talabat link, copy-ready for placing the real order. (True auto-placement on
  Talabat would require automating logged-in accounts with payment access — ToS-hostile; not pursued.)

## Talabat scraping (2026-07-04) — fixed and hardened

Diagnosis: Cloudflare hard-blocks the EC2 datacenter IP (plain 403 even with a perfect Chrome TLS
fingerprint); the old FlareSolverr v3.3.21 (Chrome 120) could no longer solve the interactive challenge.

- [x] FlareSolverr pinned to **v3.5.0** (Chrome 148) — solves the challenge again (~12 s).
- [x] **Session mint-and-reuse pipeline** in the scraper: solve once via FlareSolverr, then plain
  sub-second fetches with the minted cookies + UA (cached per worker process); the solved hydrated page
  lacking `__NEXT_DATA__` is handled by re-fetching raw HTML with the session.
- [x] Sync-failure UX points users at manual item entry (menus are user-editable by everyone now).
- [ ] Scraper resilience extras: alerting on repeated sync failures, snapshot tests against fixture HTML.

## Deferred / nice-to-have

- [x] Favorites & one-tap reorder — "Add my usual" replays your last order at that restaurant
  (`GET /restaurants/{id}/my_usual/`).
- [ ] Order templates per team.
- [ ] Collector rotation suggestions (fairness stats exist in reports already).
- [x] Menu item photos in the picker (Talabat `image_url` was already scraped and stored — now rendered).
- [ ] Slack/Teams webhook integration for order-opened announcements (WhatsApp share text exists).
- [ ] Guest-account hygiene: periodic cleanup/merge of inactive `quick-join` guests.
