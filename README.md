# tojam-2021

A multiplayer table hockey game I made for the 2021 Toronto Game Jam.
See the commit history for the original version completed at the jam.

![Toronto Game Jam MiniCade screenshot](TorontoGameJamMiniCade.png)

## Local development

Both networking services can be started together with Docker Compose.

```sh
cp .env.example .env
make up
```

### Configure game endpoint overrides

The game reads these environment variables at runtime when loading networking:

- `SIGNALING_WS_URL` (default `ws://localhost:5050/rooms/%s`)
- `TURN_SERVER_URLS` (default `turn:127.0.0.1:3478`)
- `TURN_SERVER_USERNAME` (default `tojam-2021`)
- `TURN_SERVER_PASSWORD` (default `tojam-2021`)

Set these in your shell before launching Godot so the game points to the local services:

```sh
export SIGNALING_WS_URL="ws://localhost:5050/rooms/%s"
export TURN_SERVER_URLS="turn:127.0.0.1:3478"
export TURN_SERVER_USERNAME="tojam-2021"
export TURN_SERVER_PASSWORD="tojam-2021"
make godot
```

## Contributing

### Pull request titles and changelog entries

Use pull request titles in the form `<tag>: <title>`, with an optional scope when it adds clarity.

Prefer tags such as `feat`, `fix`, `chore`, `docs`, `ci`, and `refactor`.

Add changelog entries under `## [Unreleased]` in `CHANGELOG.md` using the pull request title followed by `by @contributor in #PR`.

```md
- feat: add support for local multiplayer by @AndreiBetlen in #1
- fix: clean up signaling server startup by @AndreiBetlen in #1
```

### Code style

Keep changes small and scoped to the relevant feature.

Run formatting and checks for Go server changes using:

```sh
cd signalling-server
go test ./...
```
