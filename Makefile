.PHONY: help \
        build up down restart logs logs-backend logs-frontend ps clean \
        migrate makemigrations shell superuser test \
        prod-build prod-up prod-down prod-restart \
        prod-logs prod-logs-backend prod-logs-frontend prod-ps \
        prod-migrate prod-shell deploy

COMPOSE         = docker compose
PROD_COMPOSE    = docker compose -f docker-compose.prod.yml
STAGING_COMPOSE = docker compose --env-file .env.staging -f docker-compose.prod.yml -f docker-compose.staging.yml
BRANCH         ?= devel

# ── Help ─────────────────────────────────────────────────────────────────────
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Local dev targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-25s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ── Local dev ─────────────────────────────────────────────────────────────────
build: ## Build all local Docker images
	$(COMPOSE) build

up: ## Start all local services (detached)
	$(COMPOSE) up -d

down: ## Stop all local services
	$(COMPOSE) down

restart: ## Restart all local services
	$(COMPOSE) restart

logs: ## Tail logs from all local services
	$(COMPOSE) logs -f

logs-backend: ## Tail local backend logs
	$(COMPOSE) logs -f backend

logs-frontend: ## Tail local frontend logs
	$(COMPOSE) logs -f frontend

ps: ## Show local running containers
	$(COMPOSE) ps

clean: ## Stop local services and remove volumes (destructive)
	$(COMPOSE) down -v
	docker system prune -f

migrate: ## Run Django migrations (local)
	$(COMPOSE) exec backend python manage.py migrate

makemigrations: ## Create Django migration files (local)
	$(COMPOSE) exec backend python manage.py makemigrations

shell: ## Open Django shell (local)
	$(COMPOSE) exec backend python manage.py shell

superuser: ## Create Django superuser (local)
	$(COMPOSE) exec backend python manage.py createsuperuser

test: ## Run Django tests (local)
	$(COMPOSE) exec backend python manage.py test

# ── Production ────────────────────────────────────────────────────────────────
prod-build: ## Build production Docker images (backend + frontend + flutter-pwa)
	docker build -t orderq-backend:latest -f Dockerfile .
	docker build -t orderq-frontend:latest --build-arg VITE_SENTRY_DSN=$(VITE_SENTRY_DSN) -f frontend/Dockerfile frontend/
	docker build -t orderq-flutter-pwa:latest -f mobile/Dockerfile.pwa mobile/

prod-up: ## Start all production services (detached)
	$(PROD_COMPOSE) up -d

prod-down: ## Stop all production services
	$(PROD_COMPOSE) down

prod-restart: ## Restart all production services
	$(PROD_COMPOSE) restart

prod-logs: ## Tail logs from all production services
	$(PROD_COMPOSE) logs -f

prod-logs-backend: ## Tail production backend logs
	$(PROD_COMPOSE) logs -f backend

prod-logs-frontend: ## Tail production frontend logs
	$(PROD_COMPOSE) logs -f frontend

prod-ps: ## Show production running containers
	$(PROD_COMPOSE) ps

prod-migrate: ## Run Django migrations (production)
	$(PROD_COMPOSE) exec backend python manage.py migrate

prod-shell: ## Open Django shell (production)
	$(PROD_COMPOSE) exec backend python manage.py shell

# ── Deploy ────────────────────────────────────────────────────────────────────
deploy: ## Pull latest code, rebuild images, restart app services (BRANCH=devel)
	git pull origin $(BRANCH)
	$(MAKE) prod-build
	$(PROD_COMPOSE) up -d backend celery-worker celery-beat frontend flutter-pwa
	# nginx resolves container IPs at startup — recreated services get new
	# IPs, so the router must restart or /api starts returning 502s
	$(PROD_COMPOSE) restart nginx-router

backup: ## Dump the production database to backups/ (with retention)
	./scripts/backup_db.sh

release: ## Build + tag versioned images and a git tag: make release TAG=v1.2.0
	@test -n "$(TAG)" || (echo "Usage: make release TAG=v1.2.0" && exit 1)
	docker build -t orderq-backend:$(TAG) -f Dockerfile .
	docker build -t orderq-frontend:$(TAG) -f frontend/Dockerfile frontend/
	docker build -t orderq-flutter-pwa:$(TAG) -f mobile/Dockerfile.pwa mobile/
	git tag -a $(TAG) -m "Release $(TAG)"
	@echo "Tagged $(TAG). Deploy it with: IMAGE_TAG=$(TAG) in .env, then make prod-up"
	@echo "Roll back by pointing IMAGE_TAG at the previous tag and re-running make prod-up."

# ── Staging ───────────────────────────────────────────────────────────────────
staging-up: ## Start the staging stack (ports 29991/29992, own volumes)
	$(STAGING_COMPOSE) up -d

staging-down: ## Stop the staging stack
	$(STAGING_COMPOSE) down

staging-logs: ## Tail staging logs
	$(STAGING_COMPOSE) logs -f
