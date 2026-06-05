DOCKER_COMPOSE ?= docker-compose
PROJECT_PATH ?= TOJAM-2021
GODOT ?= godot
ENV_FILE ?= .env
ENV_FILE_PATH := $(abspath $(ENV_FILE))
WEB_EXPORT_PRESET ?= Web
WEB_EXPORT_DIR ?= $(PROJECT_PATH)/Releases
WEB_EXPORT_FILE ?= $(WEB_EXPORT_DIR)/index.html
WEB_HOST ?= 0.0.0.0
WEB_PORT ?= 8000

.PHONY: up down logs logs-signaling logs-coturn status stop rebuild clean godot web export-web

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

export-web:
	mkdir -p $(WEB_EXPORT_DIR)
	$(GODOT) --headless --path $(PROJECT_PATH) --export-release "$(WEB_EXPORT_PRESET)" "$(abspath $(WEB_EXPORT_FILE))"

web: export-web
	cd $(WEB_EXPORT_DIR) && python3 -m http.server $(WEB_PORT) --bind $(WEB_HOST)
