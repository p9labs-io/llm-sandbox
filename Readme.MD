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

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- An **Anthropic API key** for Claude → [console.anthropic.com](https://console.anthropic.com)
- A **Google API key** for Gemini → [aistudio.google.com/apikey](https://aistudio.google.com/apikey)

You only need the key for the tool(s) you plan to use.

---

## Quick start

### 1. Save your API key(s)

Set up only the tool you need:

```bash
make setup-claude   # Anthropic key only
make setup-gemini   # Google key only
make setup          # both
```

Keys are saved to `~/.env.ai-cli` on your machinehine — readable only by you, never committed to git. Running setup again for the same tool overwrites just that key, leaving the other untouched.

### 2. Go to your project

```bash
cd ~/projects/my-app
```

### 3. Run the CLI

```bash
make claude   # start Claude Code
make gemini   # start Gemini CLI
```

That's it. The tool starts inside a container with your current folder mounted at `/workspace`.

---

## Running without Make

If you prefer plain Docker:

**Claude:**
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
| `-e KEY="..."` | Passes your API key as an environment variable |

---

## What the AI can and cannot access

| Resource | Accessible |
|---|---|
| Your current project folder | ✅ Yes |
| Any other folder on your machine | ❌ No |
| `~/.ssh` | ❌ No |
| `~/Documents`, `~/Downloads` | ❌ No |
| Your environment variables | ❌ No (only the key you pass explicitly) |

The container has no knowledge of anything outside the folder you mount.

---

## Images

| Image | Base | Notes |
|---|---|---|
| `ghcr.io/p9labs-io/claude-cli` | `debian:bookworm-slim` | Native binary, no Node.js required |
| `ghcr.io/p9labs-io/gemini-cli` | `node:20-slim` | Requires Node.js — Google hasn't released a native binary yet |

Images are built automatically on every push to `main` and published to [GitHub Container Registry](https://github.com/orgs/p9labs-io/packages).

---

## Troubleshooting

**`make claude` says "No ANTHROPIC_API_KEY found"**
Run `make setup-claude` to save your key.

**`make gemini` says "No GOOGLE_API_KEY found"**
Run `make setup-gemini` to save your key.

**Docker says "image not found"**
Make sure Docker Desktop is running, then try pulling manually:
```bash
docker pull ghcr.io/p9labs-io/claude-cli:latest
docker pull ghcr.io/p9labs-io/gemini-cli:latest
```

**The container starts but the CLI asks me to log in**
Your API key may be invalid or expired. Double-check it and re-run the relevant setup command.

**I want to use a specific subfolder, not my whole project**
Just `cd` into that subfolder before running `make claude` or `make gemini`. Only that directory will be mounted.