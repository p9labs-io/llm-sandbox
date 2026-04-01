# llm-sandbox

Run [Claude Code](https://claude.ai/code) and [Gemini CLI](https://github.com/google-gemini/gemini-cli) in isolated Docker containers — no runtimes installed on your machinehine, no access to your home directory, SSH keys, or anything outside the project you point them at.

## How it works

Each tool runs inside a container. When you launch it, only the folder you're currently in gets mounted — everything else on your machine is invisible to the AI. When the session ends, the container is deleted automatically.

```
your machine
└── ~/projects/my-app     ← only this is visible inside the container
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

## Quick start — Claude

Claude supports two authentication methods. OAuth is recommended if you have a Pro plan — no extra cost, no separate billing.

### Option A: claude.ai Pro (OAuth) — recommended

Authenticates inside the container on first run. Credentials are saved to `~/.claude/.credentials.json` on your machine and reused on every subsequent run — read-only, so the container can never modify or rotate them.

**Step 1** — Authenticate (once):
```bash
make setup-claude-oauth
```

This launches a container, opens a browser for you to log in with your claude.ai account, then saves the credentials to your machine. No native Claude Code install needed.

**Step 2** — Go to your project and run:
```bash
cd ~/projects/my-app
make claude
```

### Option B: Anthropic API key

If you don't have a Pro plan, you can use a pay-per-token API key from [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys). Note this is billed separately from claude.ai Pro.

```bash
make setup-claude-key
```

### How `make claude` picks auth

It checks in this order and uses whichever is available first:

1. `~/.claude/.credentials.json` (OAuth) — prints `Auth: OAuth (Pro plan)`
2. `ANTHROPIC_API_KEY` in `~/.env.ai-cli` — prints `Auth: API key`
3. Neither found → error with setup instructions

---

## Quick start — Gemini

```bash
make setup-gemini   # save your Google API key (once)
cd ~/projects/my-app
make gemini
```

---

## Running without Make

If you prefer plain Docker:

**Claude with OAuth:**
```bash
docker run -it --rm \
  -v "$(pwd)":/workspace \
  -v "$HOME/.claude/.credentials.json":/root/.claude/.credentials.json:ro \
  ghcr.io/p9labs-io/claude-cli:latest
```

**Claude with API key:**
```bash
docker run -it --rm \
  -v "$(pwd)":/workspace \
  -e ANTHROPIC_API_KEY="your-key-here" \
  ghcr.io/p9labs-io/claude-cli:latest
```

**Gemini:**
```bash
docker run -it --rm \
  -v "$(pwd)":/workspace \
  -e GOOGLE_API_KEY="your-key-here" \
  ghcr.io/p9labs-io/gemini-cli:latest
```

### What each flag does

| Flag | Meaning |
|---|---|
| `-it` | Interactive mode — keeps the terminal session open |
| `--rm` | Deletes the container automatically when you exit |
| `-v "$(pwd)":/workspace` | Mounts your current folder into the container |
| `:ro` | Read-only — container can read but not modify the file |
| `-e KEY="..."` | Passes a value as an environment variable |

---

## What the AI can and cannot access

| Resource | Accessible |
|---|---|
| Your current project folder | ✅ Yes |
| Any other folder on your machine | ❌ No |
| `~/.ssh` | ❌ No |
| `~/Documents`, `~/Downloads` | ❌ No |
| Your environment variables | ❌ No (only what you pass explicitly) |
| Your claude.ai credentials (OAuth) | ✅ Read-only, auth only |

---

## Images

| Image | Base | Notes |
|---|---|---|
| `ghcr.io/p9labs-io/claude-cli` | `debian:bookworm-slim` | Native binary, no Node.js required |
| `ghcr.io/p9labs-io/gemini-cli` | `node:20-slim` | Requires Node.js — Google hasn't released a native binary yet |

Images are published to [GitHub Container Registry](https://github.com/orgs/p9labs-io/packages) and rebuilt automatically only when their Dockerfile changes.

---

## Troubleshooting

**`make setup-claude-oauth` says login may not have completed**
Make sure you completed the browser login before typing `/exit` in the container. Run `make setup-claude-oauth` again.

**`make claude` says "No Claude credentials found"**
Run either `make setup-claude-oauth` (Pro) or `make setup-claude-key` (API key).

**`make gemini` says "No GOOGLE_API_KEY found"**
Run `make setup-gemini` to save your key.

**Docker says "image not found"**
Make sure Docker Desktop is running, then pull manually:
```bash
docker pull ghcr.io/p9labs-io/claude-cli:latest
docker pull ghcr.io/p9labs-io/gemini-cli:latest
```

**I want to use a specific subfolder, not my whole project**
`cd` into that subfolder before running `make claude` or `make gemini`. Only that directory will be mounted.