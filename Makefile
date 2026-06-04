DOCKER_COMPOSE ?= docker-compose

.PHONY: up down logs logs-signaling logs-coturn status stop rebuild clean

up:
\t$(DOCKER_COMPOSE) up -d --build

down:
\t$(DOCKER_COMPOSE) down

logs:
\t$(DOCKER_COMPOSE) logs -f

logs-signaling:
\t$(DOCKER_COMPOSE) logs -f signalling-server

logs-coturn:
\t$(DOCKER_COMPOSE) logs -f coturn

status:
\t$(DOCKER_COMPOSE) ps

stop:
\t$(DOCKER_COMPOSE) stop

rebuild:
\t$(DOCKER_COMPOSE) build --no-cache

clean:
\t$(DOCKER_COMPOSE) down -v --remove-orphans
