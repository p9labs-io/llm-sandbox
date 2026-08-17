# llm-sandbox

Run [Claude Code](https://claude.ai/code) and [Antigravity CLI (agy)](https://antigravity.google) in isolated Docker containers — no runtimes installed on your machine, no access to your home directory, SSH keys, or anything outside the project you point them at.

## How it works

When you launch a tool, only the project folder you specify gets mounted into the container. Everything else on your system is invisible to the AI. When the session ends the container is deleted automatically.

```
your system
└── projects/my-app     ← only this is visible inside the container
    ├── src/
    ├── package.json
    └── ...
```

The agent gets its own persistent config directory under `~/.llm-sandbox/`. Your real `~/.claude` — settings, hooks, plugins, and the session history of every other project — is never mounted.

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- For Claude: a **Claude Pro/Max** account — or an **Anthropic API key** from [console.anthropic.com](https://console.anthropic.com)
- For Antigravity: an **Antigravity API key** from [antigravity.google/docs/cli/reference](https://antigravity.google/docs/cli/reference)

---

## Setup

Clone the repo. All `make` commands must be run from the repo root.

```bash
git clone https://github.com/p9labs-io/llm-sandbox.git
cd llm-sandbox
```

### Choosing a credential

Whatever credential you put in the container, the agent can read it. Assume any credential you hand it is a credential you have handed to the repository it is working on. So the question is not *how* it is stored, but *how much a stolen copy is worth*:

| Option | Command | What a stolen copy gives an attacker |
|---|---|---|
| **Long-lived token** (recommended for Pro/Max) | `make setup-claude-token` | Model requests on your subscription, for up to a year. No Remote Control, no claude.ai connectors. Revoke by logging out of the session that minted it. |
| **API key** (recommended overall) | `make setup-claude-key` | Model requests billed to that key. Scope it to its own Console workspace with a spend limit and revoke it independently. |
| **Full OAuth login** | `make setup-claude-oauth` | Your `.credentials.json` refresh token — full account access until you log out everywhere. |

### Claude — Option A: long-lived token (Pro/Max)

Runs `claude setup-token` in a throwaway container. Follow the browser login, then paste the printed token back in. It is stored in `~/.env.ai-cli` with mode `0600` and passed in as `CLAUDE_CODE_OAUTH_TOKEN`.

```bash
make setup-claude-token
```

### Claude — Option B: Anthropic API key

Create the key at [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys). Put it in its own workspace with a spend limit so it can be revoked without touching anything else.

```bash
make setup-claude-key
```

### Claude — Option C: full OAuth login

Logs in inside the container and stores the result in `~/.llm-sandbox/claude/`. Convenient, but it puts a refresh token where the agent can read it.

```bash
make setup-claude-oauth
```

### Antigravity

```bash
make setup-antigravity
```

---

## Running

All commands are run from the **repo root**. Point them at your project using `PROJECT=`. Relative paths, absolute paths, and `~` are all supported. `PROJECT=~` and `PROJECT=/` are refused.

```bash
# Auto-detect credential (token → API key → OAuth)
make claude PROJECT=projects/my-app

# Force a specific credential
make claude-token PROJECT=projects/my-app
make claude-key   PROJECT=projects/my-app
make claude-oauth PROJECT=projects/my-app

# Antigravity
make agy PROJECT=projects/my-app
```

### Restricting network egress

By default the container can reach the entire internet, which means anything it reads — your source, your `.env`, your git history — can leave. `LOCK=1` puts the container on an internal Docker network whose only route out is an allowlisting proxy:

```bash
make claude-key PROJECT=projects/my-app LOCK=1
```

The allowlist lives in [`images/egress/allowlist`](images/egress/allowlist). Edit it and run `make egress-restart` to apply. `make egress-down` removes the proxy and its networks.

This is what makes `--dangerously-skip-permissions` a defensible trade rather than a reckless one: with egress pinned to hosts you chose, a bypassed session can still wreck the mounted workspace, but it has nowhere to send what it read.

### Options

| Variable | Default | Meaning |
|---|---|---|
| `PROJECT` | current directory | Directory mounted at `/workspace` |
| `LOCK` | unset | `LOCK=1` restricts egress to the allowlist |
| `DOCKER_MEM` | `4g` | Memory ceiling |
| `DOCKER_CPUS` | `4` | CPU ceiling |
| `DOCKER_PIDS` | `512` | Process ceiling |

### Updating images

```bash
make pull                # both images
make pull-claude         # Claude only
make pull-antigravity    # Antigravity only
```

---

## Running without Make

```bash
docker run -it --rm \
  --init --cap-drop=ALL --security-opt=no-new-privileges:true \
  --pids-limit=512 --memory=4g --cpus=4 \
  -v /absolute/path/to/my-app:/workspace \
  -v "$HOME/.llm-sandbox/claude":/home/claude/.claude \
  -e ANTHROPIC_API_KEY="your-key-here" \
  ghcr.io/p9labs-io/claude-cli:latest
```

Swap `-e ANTHROPIC_API_KEY=...` for `-e CLAUDE_CODE_OAUTH_TOKEN=...`, or drop it entirely if `~/.llm-sandbox/claude/.credentials.json` already holds a login.

### What each flag does

| Flag | Meaning |
|---|---|
| `-it` | Interactive — keeps the terminal session open |
| `--rm` | Deletes the container automatically on exit |
| `--init` | Reaps zombie processes and forwards signals |
| `--cap-drop=ALL` | Removes every Linux capability |
| `--security-opt=no-new-privileges:true` | Blocks setuid privilege escalation |
| `--pids-limit`, `--memory`, `--cpus` | Caps runaway or hostile resource use |
| `-v /absolute/path:/workspace` | Mounts your project folder into the container |
| `-e KEY="..."` | Passes a value as an environment variable |

---

## Threat model

What this actually protects against, and what it doesn't.

### Protected

| Resource | Accessible |
|---|---|
| The project folder you specify | ✅ Yes |
| Any other folder on your host | ❌ No |
| `~/.ssh`, `~/Documents`, `~/Downloads` | ❌ No |
| Your host `~/.claude` (settings, hooks, plugins, history) | ❌ No — the sandbox has its own under `~/.llm-sandbox/` |
| Your shell environment variables | ❌ No — only what is passed explicitly |
| Host root, setuid escalation, kernel capabilities | ❌ No — non-root, `--cap-drop=ALL`, `no-new-privileges` |
| Host CPU/RAM/PID exhaustion | ❌ Capped |

### Not protected

- **The credential you pass in.** Env var or mounted file makes no difference — the agent runs as the same user and can read either. The mitigation is a narrow, revocable credential, not a hiding place. Claude Code's [`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`](https://code.claude.com/docs/en/env-vars) strips it from subprocesses it spawns, which raises the bar for a malicious build script but not for the agent itself.
- **Everything in the mounted project.** Committed secrets, `.env` files, and full git history are all readable, and writable. The container is the boundary; the workspace is not.
- **Network egress**, unless you run with `LOCK=1`. Without it the container reaches the whole internet, your LAN, and anything listening on `host.docker.internal`.
- **Prompt injection.** A hostile `README`, dependency, or issue body can steer the agent. The container limits the blast radius; it does not limit the agent's willingness to be steered.
- **Whatever the allowlist allows.** `github.com` and `registry.npmjs.org` are in the default allowlist because real work needs them, and both are usable as exfiltration channels by anything holding a token. Trim the list to what your project actually needs.
- **Container escape.** Rare, but the boundary is the Docker daemon. On macOS there is an additional VM boundary; on Linux there is not.

---

## Images

| Image | Base | Platforms | Runs as |
|---|---|---|---|
| `ghcr.io/p9labs-io/claude-cli` | `debian:bookworm-slim` | `linux/amd64`, `linux/arm64` | `claude` (non-root) |
| `ghcr.io/p9labs-io/antigravity-cli` | `debian:bookworm-slim` | `linux/amd64`, `linux/arm64` | `antigravity` (non-root) |
| `llm-sandbox/egress-proxy` (built locally) | `debian:bookworm-slim` | host arch | `tinyproxy` (non-root) |

The Claude image installs from the `stable` channel and then verifies the installed binary's SHA-256 against Anthropic's GPG-signed release manifest (key fingerprint `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`), so a tampered installer fails the build instead of shipping. In-container auto-update is disabled, which means the image is the only thing that decides which version runs — run `make pull` to move forward.

Images are published to [GitHub Container Registry](https://github.com/orgs/p9labs-io/packages) and rebuilt weekly and on Dockerfile changes.

---

## Troubleshooting

**`make` says "No such file or directory"**
You are not in the repo root. `cd` into the `llm-sandbox` folder first.

**`make setup-claude-oauth` says login may not have completed**
Make sure you finished the browser login before typing `/exit`. Run it again.

**`Refusing to mount ...`**
`PROJECT` resolved to your home directory or `/`. Point it at a single project directory.

**Requests hang or fail with `LOCK=1`**
A host is missing from `images/egress/allowlist`. Check the proxy log with `docker logs llm-sandbox-proxy`, add the host, and run `make egress-restart`.

**I upgraded and my old login is gone**
The sandbox config directory moved from `~/.claude` to `~/.llm-sandbox/claude` so the container no longer touches your host Claude Code config. Re-run a setup command, or move the old file:
`mkdir -p ~/.llm-sandbox/claude && mv ~/.claude/.credentials.json ~/.llm-sandbox/claude/`
