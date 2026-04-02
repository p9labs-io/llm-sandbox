# llm-sandbox

Run [Claude Code](https://claude.ai/code) and [Gemini CLI](https://github.com/google-gemini/gemini-cli) in isolated Docker containers — no runtimes installed on your machine, no access to your home directory, SSH keys, or anything outside the project you point them at.

## How it works

When you launch a tool, only the project folder you specify gets mounted into the container. Everything else on your Mac is invisible to the AI. When the session ends the container is deleted automatically.

```
your Mac
└── projects/my-app     ← only this is visible inside the container
    ├── src/
    ├── package.json
    └── ...
```

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- For Claude: a **claude.ai Pro** account — or an **Anthropic API key** from [console.anthropic.com](https://console.anthropic.com)
- For Gemini: a **Google API key** from [aistudio.google.com/apikey](https://aistudio.google.com/apikey)

---

## Setup

Clone the repo. All `make` commands must be run from the repo root.

```bash
git clone https://github.com/p9labs-io/llm-sandbox.git
cd llm-sandbox
```

### Claude — Option A: claude.ai Pro (OAuth) — recommended

Runs once. Pulls the image, then Claude prints a login URL in the terminal — copy it and open it in your browser. After logging in, type `/exit` to close the session. Your credentials are saved to `~/.claude/.credentials.json` and reused on every subsequent run, read-only.

```bash
make setup-claude-oauth
```

### Claude — Option B: Anthropic API key

If you don't have a Pro plan, use a pay-per-token API key from [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys). Billed separately from claude.ai.

```bash
make setup-claude-key
```

Saves your key and pulls the image automatically.

### Gemini

```bash
make setup-gemini
```

Saves your Google API key from [aistudio.google.com/apikey](https://aistudio.google.com/apikey) and pulls the image automatically.

---

## Running

All commands are run from the **repo root**. Point them at your project using `PROJECT=`. Relative paths, absolute paths, and `~` are all supported.

```bash
# relative path — resolved automatically
make claude PROJECT=projects/my-app
make gemini PROJECT=projects/my-app

# absolute path
make claude PROJECT=/Users/you/work/client-api
make gemini PROJECT=/Users/you/work/client-api

# home directory shorthand
make claude PROJECT=~/work/client-api

# defaults to current directory if PROJECT is omitted
make claude
make gemini
```

If the image isn't available locally, it will be pulled automatically before starting.

### How `make claude` picks auth

It checks in this order and uses whichever is found first:

1. `~/.claude/.credentials.json` exists → OAuth (Pro plan)
2. `ANTHROPIC_API_KEY` in `~/.env.ai-cli` → API key
3. Neither found → error with setup instructions

### Updating images

When new versions are released, pull the latest:

```bash
make pull          # both images
make pull-claude   # Claude only
make pull-gemini   # Gemini only
```

---

## Running without Make

If you prefer plain Docker, use absolute paths for volume mounts:

**Claude with OAuth:**
```bash
docker run -it --rm \
  -v /absolute/path/to/my-app:/workspace \
  -v "$HOME/.claude/.credentials.json":/home/claude/.claude/.credentials.json:ro \
  ghcr.io/p9labs-io/claude-cli:latest
```

**Claude with API key:**
```bash
docker run -it --rm \
  -v /absolute/path/to/my-app:/workspace \
  -e ANTHROPIC_API_KEY="your-key-here" \
  ghcr.io/p9labs-io/claude-cli:latest
```

**Gemini:**
```bash
docker run -it --rm \
  -v /absolute/path/to/my-app:/workspace \
  -e GOOGLE_API_KEY="your-key-here" \
  ghcr.io/p9labs-io/gemini-cli:latest
```

### What each flag does

| Flag | Meaning |
|---|---|
| `-it` | Interactive — keeps the terminal session open |
| `--rm` | Deletes the container automatically on exit |
| `-v /absolute/path:/workspace` | Mounts your project folder into the container |
| `:ro` | Read-only — container can read but not modify the file |
| `-e KEY="..."` | Passes a value as an environment variable |

---

## What the AI can and cannot access

| Resource | Accessible |
|---|---|
| The project folder you specify | ✅ Yes |
| Any other folder on your Mac | ❌ No |
| `~/.ssh` | ❌ No |
| `~/Documents`, `~/Downloads` | ❌ No |
| Your environment variables | ❌ No (only what you pass explicitly) |
| Your claude.ai credentials (OAuth) | ✅ Read-only, auth only |

---

## Images

| Image | Base | Platforms | Runs as |
|---|---|---|---|
| `ghcr.io/p9labs-io/claude-cli` | `debian:bookworm-slim` | `linux/amd64`, `linux/arm64` | `claude` (non-root) |
| `ghcr.io/p9labs-io/gemini-cli` | `node:20-slim` | `linux/amd64`, `linux/arm64` | `node` (non-root) |

Both containers run as non-root users. Images are published to [GitHub Container Registry](https://github.com/orgs/p9labs-io/packages) and rebuilt automatically only when their Dockerfile changes.

---

## Troubleshooting

**`make` says "No such file or directory"**
You are not in the repo root. `cd` into the `llm-sandbox` folder first.

**`make setup-claude-oauth` says login may not have completed**
Make sure you finished the browser login before typing `/exit`. Run `make setup-claude-oauth` again.

**`make claude` says "No Claude credentials found"**
Run either `make setup-claude-oauth` (Pro) or `make setup-claude-key` (API key).

**`make gemini` says "No GOOGLE_API_KEY found"**
Run `make setup-gemini` to save your key.

**The container starts but asks me to log in again**
`make claude` automatically detects an expired OAuth token and re-authenticates before launching. If you see a 401 error mid-session, exit the container and run `make claude` again — it will handle re-auth automatically.

**I want to use the latest image version**
Run `make pull` to pull the latest images from the registry.