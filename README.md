# tojam-2021

A multiplayer table hockey game I made for the 2021 Toronto Game Jam.
See the commit history for the original version completed at the jam.

![Toronto Game Jam MiniCade screenshot](TorontoGameJamMiniCade.png)

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
