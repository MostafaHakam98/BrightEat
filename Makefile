.PHONY: help \
        build up down restart logs logs-backend logs-frontend ps clean \
        migrate makemigrations shell superuser test \
        prod-build prod-up prod-down prod-restart \
        prod-logs prod-logs-backend prod-logs-frontend prod-ps \
        prod-migrate prod-shell deploy

COMPOSE      = docker compose
PROD_COMPOSE = docker compose -f docker-compose.prod.yml
BRANCH      ?= devel

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
prod-build: ## Build production Docker images (backend + frontend)
	docker build -t brighteat-backend:latest -f Dockerfile .
	docker build -t brighteat-frontend:latest -f frontend/Dockerfile frontend/

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
deploy: ## Pull latest code, rebuild images, restart backend + frontend (BRANCH=devel)
	git pull origin $(BRANCH)
	$(MAKE) prod-build
	$(PROD_COMPOSE) up -d backend frontend
