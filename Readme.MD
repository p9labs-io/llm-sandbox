# llm-sandbox

Run [Claude Code](https://claude.ai/code) and [Gemini CLI](https://github.com/google-gemini/gemini-cli) in isolated Docker containers — no runtimes installed on your machinehine, no access to your home directory, SSH keys, or anything outside the project you point them at.

## How it works

When you launch a tool, only the project folder you specify gets mounted into the container. Everything else on your machine is invisible to the AI. When the session ends the container is deleted automatically.

```
your machine
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

Clone the repo and run Make from its root directory. All `make` commands must be run from the repo root.

```bash
git clone https://github.com/p9labs-io/llm-sandbox.git
cd llm-sandbox
```

### Claude — Option A: claude.ai Pro (OAuth) — recommended

Authenticates inside the container on first run. Credentials are saved to `~/.claude/.credentials.json` on your machine and reused on every subsequent run — read-only, so the container can never modify or rotate them.

```bash
make setup-claude-oauth
```

This launches a container, opens a browser for you to log in with your claude.ai account, then saves the session to your machine. No native Claude Code install needed. Run this once, then you're done.

### Claude — Option B: Anthropic API key

If you don't have a Pro plan, use a pay-per-token API key from [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys). Billed separately from claude.ai Pro.

```bash
make setup-claude-key
```

### Gemini

```bash
make setup-gemini
```

Prompts for your Google API key from [aistudio.google.com/apikey](https://aistudio.google.com/apikey) and saves it to `~/.env.ai-cli`.

---

## Running

All commands are run from the **repo root**. Point them at your project using `PROJECT=`.

```bash
# use the projects/ folder inside this repo
make claude PROJECT=projects/my-app
make gemini PROJECT=projects/my-app

# or point at any folder on your machine
make claude PROJECT=~/work/client-api
make gemini PROJECT=~/work/client-api

# defaults to current directory if PROJECT is omitted
make claude
make gemini
```

### How `make claude` picks auth

It checks in this order and uses whichever is found first:

1. `~/.claude/.credentials.json` exists → OAuth (Pro plan)
2. `ANTHROPIC_API_KEY` in `~/.env.ai-cli` → API key
3. Neither → error with setup instructions

---

## Running without Make

If you prefer plain Docker, the equivalent commands are:

**Claude with OAuth:**
```bash
docker run -it --rm \
  -v ~/work/my-app:/workspace \
  -v "$HOME/.claude/.credentials.json":/root/.claude/.credentials.json:ro \
  ghcr.io/p9labs-io/claude-cli:latest
```

**Claude with API key:**
```bash
docker run -it --rm \
  -v ~/work/my-app:/workspace \
  -e ANTHROPIC_API_KEY="your-key-here" \
  ghcr.io/p9labs-io/claude-cli:latest
```

**Gemini:**
```bash
docker run -it --rm \
  -v ~/work/my-app:/workspace \
  -e GOOGLE_API_KEY="your-key-here" \
  ghcr.io/p9labs-io/gemini-cli:latest
```

### What each flag does

| Flag | Meaning |
|---|---|
| `-it` | Interactive — keeps the terminal session open |
| `--rm` | Deletes the container automatically on exit |
| `-v /your/project:/workspace` | Mounts your project folder into the container |
| `:ro` | Read-only — container can read but not modify the file |
| `-e KEY="..."` | Passes a value as an environment variable |

---

## What the AI can and cannot access

| Resource | Accessible |
|---|---|
| The project folder you specify | ✅ Yes |
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

**`make` says "No such file or directory"**
Make sure you're running commands from the repo root, not from inside a project folder.

**`make setup-claude-oauth` says login may not have completed**
Make sure you finished the browser login before typing `/exit` in the container. Run `make setup-claude-oauth` again.

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