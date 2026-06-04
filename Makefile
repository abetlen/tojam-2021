DOCKER_COMPOSE ?= docker-compose
PROJECT_PATH ?= TOJAM-2021
GODOT ?= godot
ENV_FILE ?= .env
ENV_FILE_PATH := $(abspath $(ENV_FILE))

.PHONY: up down logs logs-signaling logs-coturn status stop rebuild clean godot

up:
	$(DOCKER_COMPOSE) up -d --build

down:
	$(DOCKER_COMPOSE) down

logs:
	$(DOCKER_COMPOSE) logs -f

logs-signaling:
	$(DOCKER_COMPOSE) logs -f signalling-server

logs-coturn:
	$(DOCKER_COMPOSE) logs -f coturn

status:
	$(DOCKER_COMPOSE) ps

stop:
	$(DOCKER_COMPOSE) stop

rebuild:
	$(DOCKER_COMPOSE) build --no-cache

clean:
	$(DOCKER_COMPOSE) down -v --remove-orphans

godot:
	@if [ -f "$(ENV_FILE_PATH)" ]; then \
		set -a; . "$(ENV_FILE_PATH)"; set +a; \
		$(GODOT) --path $(PROJECT_PATH); \
	else \
		$(GODOT) --path $(PROJECT_PATH); \
	fi
