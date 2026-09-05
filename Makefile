# Thin wrappers around the same compose file selection as bash/docker.sh.
# Requires a configured .env (same keys as magic.sh).

COMPOSE_FILE := -f docker-compose.yml
ifeq ($(shell grep -E '^ENABLE_CRON=true' .env 2>/dev/null),ENABLE_CRON=true)
COMPOSE_FILE += -f docker-compose.cron.yml
endif
ifeq ($(shell grep -E '^ENABLE_JOB=true' .env 2>/dev/null),ENABLE_JOB=true)
COMPOSE_FILE += -f docker-compose.job.yml
endif

COMPOSE ?= $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; \
	elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"; \
	else echo "docker compose"; fi)

.PHONY: up down rebuild ps build

up:
	$(COMPOSE) $(COMPOSE_FILE) build
	$(COMPOSE) $(COMPOSE_FILE) up -d --remove-orphans

rebuild:
	$(COMPOSE) $(COMPOSE_FILE) build --no-cache
	$(COMPOSE) $(COMPOSE_FILE) up -d --remove-orphans --force-recreate

down:
	$(COMPOSE) $(COMPOSE_FILE) down --remove-orphans

ps:
	docker ps

build:
	$(COMPOSE) $(COMPOSE_FILE) build
