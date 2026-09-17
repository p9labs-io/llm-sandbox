# llm-sandbox

Run [Claude Code](https://claude.ai/code) and [Antigravity CLI (agy)](https://antigravity.google) in isolated Docker containers — no runtimes installed on your machine, no access to your home directory, SSH keys, or anything outside the project you point them at.

## How it works

Only the project folder you specify gets mounted into the container. Everything else on your system is invisible to the agent, and the container is deleted when the session ends.

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
- For Claude: a **Claude Pro/Max** account, or an **Anthropic API key** from [console.anthropic.com](https://console.anthropic.com/settings/keys)
- For Antigravity: a Google account, or a **Gemini API key** from [Google AI Studio](https://aistudio.google.com/apikey)

---

## Setup

Clone the repo. All `make` commands must be run from the repo root.

```bash
git clone https://github.com/p9labs-io/llm-sandbox.git
cd llm-sandbox
```

### Choosing a Claude credential

Whatever credential you put in the container, the agent can read it. Assume any credential you hand it is a credential you have handed to the repository it is working on. So the question is not *how* it is stored, but *how much a stolen copy is worth*:

| Command | Credential | What a stolen copy is worth |
|---|---|---|
| `make setup-claude-token` | Long-lived token, best for Pro/Max | Model requests on your subscription for up to a year. No Remote Control, no claude.ai connectors. Revoke by logging out of the session that minted it. |
| `make setup-claude-key` | Anthropic API key, best overall | Model requests billed to that key. Scope it to its own Console workspace with a spend limit and revoke it independently. |
| `make setup-claude-oauth` | Full OAuth login | Your refresh token — full account access until you log out everywhere. |

The first two prompt for a value and store it in `~/.env.ai-cli` with mode `0600`; `setup-claude-token` first runs `claude setup-token` in a throwaway container so you have something to paste. `setup-claude-oauth` logs in inside the container and leaves the refresh token in `~/.llm-sandbox/claude/` where the agent can read it.

### Antigravity

```bash
make setup-antigravity     # then: make agy-key PROJECT=...
```

Stores a `GEMINI_API_KEY` in `~/.env.ai-cli`. The key alone does nothing — Antigravity also needs `"modelProvider": "gemini"` in its settings, which `make agy-key` seeds into `~/.llm-sandbox/antigravity/` on first run. Only `GEMINI_API_KEY` is read; `GOOGLE_API_KEY` and `.env` files are ignored.

Browser sign-in (`make agy`) also works: the container has no keyring and no browser, so the CLI prints a URL to open on your host and you paste the resulting code back. That stores a session the agent can read — the same trade as `make claude-oauth`.

---

## Running

Point at your project with `PROJECT=`. Relative paths, absolute paths and `~` all work; `PROJECT=~` and `PROJECT=/` are refused.

```bash
make claude       PROJECT=projects/my-app    # auto-detects credential
make claude-token PROJECT=projects/my-app    # or force one
make claude-key   PROJECT=projects/my-app
make claude-oauth PROJECT=projects/my-app

make agy          PROJECT=projects/my-app    # browser sign-in
make agy-key      PROJECT=projects/my-app    # GEMINI_API_KEY
```

| Variable | Default | Meaning |
|---|---|---|
| `PROJECT` | current directory | Directory mounted at `/workspace` |
| `LOCK` | unset | `LOCK=1` restricts egress to the allowlist |
| `DOCKER_MEM` | `4g` | Memory ceiling |
| `DOCKER_CPUS` | `4` | CPU ceiling |
| `DOCKER_PIDS` | `512` | Process ceiling |

Run `make` with no arguments for the full target list, and `make pull` to update the images.

### Restricting network egress

By default the container reaches the entire internet, which means anything it reads — your source, your `.env`, your git history — can leave. `LOCK=1` puts it on an internal Docker network whose only route out is an allowlisting proxy:

```bash
make claude-key PROJECT=projects/my-app LOCK=1
```

Edit [`images/egress/allowlist`](images/egress/allowlist) and run `make egress-restart` to apply; `make egress-down` removes the proxy and its networks. The defaults cover both agents, common package registries, and Terraform/Ansible — trim it to what your project actually needs.

This is what makes `--dangerously-skip-permissions` a defensible trade rather than a reckless one: with egress pinned to hosts you chose, a bypassed session can still wreck the mounted workspace, but it has nowhere to send what it read.

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

Swap in `-e CLAUDE_CODE_OAUTH_TOKEN=...`, or drop the `-e` entirely if `~/.llm-sandbox/claude/.credentials.json` already holds a login.

For Antigravity, change the image to `ghcr.io/p9labs-io/antigravity-cli:latest`, the config mount to `-v "$HOME/.llm-sandbox/antigravity":/home/antigravity/.gemini/antigravity-cli`, and the variable to `GEMINI_API_KEY`. That mount **hides** the `settings.json` baked into the image, so seed one on the host first:

```bash
cp images/antigravity/settings.gemini.json "$HOME/.llm-sandbox/antigravity/settings.json"
```

| Flag | Meaning |
|---|---|
| `-it` | Interactive — keeps the terminal session open |
| `--rm` | Deletes the container automatically on exit |
| `--init` | Reaps zombie processes and forwards signals |
| `--cap-drop=ALL` | Removes every Linux capability |
| `--security-opt=no-new-privileges:true` | Blocks setuid privilege escalation |
| `--pids-limit`, `--memory`, `--cpus` | Caps runaway or hostile resource use |

---

## Threat model

### Protected

| Resource | Accessible |
|---|---|
| The project folder you specify | ✅ Yes |
| Any other folder on your host | ❌ No |
| `~/.ssh`, `~/Documents`, `~/Downloads` | ❌ No |
| Your host `~/.claude` (settings, hooks, plugins, history) | ❌ No — the sandbox has its own |
| Your shell environment variables | ❌ No — only what is passed explicitly |
| Host root, setuid escalation, kernel capabilities | ❌ No — non-root, `--cap-drop=ALL`, `no-new-privileges` |
| Host CPU/RAM/PID exhaustion | ❌ Capped |

### Not protected

- **The credential you pass in.** Env var or mounted file makes no difference — the agent runs as the same user and can read either. The mitigation is a narrow, revocable credential, not a hiding place.
- **Everything in the mounted project.** Committed secrets, `.env` files and full git history are readable and writable. The container is the boundary; the workspace is not.
- **Network egress.** Without `LOCK=1` the container reaches the whole internet, your LAN, and `host.docker.internal`. With it, you are still exposed to whatever you allowlisted — `github.com` and `registry.npmjs.org` are both fine exfiltration channels for anything holding a token.
- **Prompt injection.** A hostile README, dependency or issue body can steer the agent. The container limits the blast radius; it does not limit the agent's willingness to be steered.
- **Your infrastructure.** `terraform` and `ansible` ship in the images and are exactly as dangerous as the credentials you give them. With none in the container they can reach nothing.
- **Container escape.** Rare, but the boundary is the Docker daemon. On macOS there is an additional VM boundary; on Linux there is not.

---

## Images

| Image | Base | Platforms | Runs as |
|---|---|---|---|
| `ghcr.io/p9labs-io/claude-cli` | `debian:bookworm-slim` | `linux/amd64`, `linux/arm64` | `claude` (non-root) |
| `ghcr.io/p9labs-io/antigravity-cli` | `debian:bookworm-slim` | `linux/amd64`, `linux/arm64` | `antigravity` (non-root) |
| `llm-sandbox/egress-proxy` (built locally) | `debian:bookworm-slim` | host arch | `tinyproxy` (non-root) |

Published to [GHCR](https://github.com/orgs/p9labs-io/packages) and rebuilt weekly and on Dockerfile changes.

The Claude binary and Terraform are both checksum-verified against a GPG-signed manifest at build time, so a tampered download fails the build instead of shipping. Antigravity publishes no equivalent, so that install is trust-on-first-use. In-container updates are disabled — `make pull` is the only way a version moves forward. Telemetry is off, which also disables Claude Code's feature-flag fetching and so makes Remote Control unavailable.

### What's installed

The agent can't `apt-get install` mid-session — it runs non-root, and under `LOCK=1` can't reach the Debian archive anyway. So both images carry the same toolchain:

| Group | Tools |
|---|---|
| Network | `curl`, `wget`, `nc`, `socat`, `dig`, `ip`/`ss`, `ping`, `openssl` |
| Process & files | `ps`/`top`, `lsof`, `rg`, `tree`, `file`, `unzip`, `rsync`, `make`, `jq`, `less` |
| Languages | `python3` (+ `pip`, `venv`) |
| Infrastructure | `terraform` (pinned by `ARG TERRAFORM_VERSION`), `ansible` (Debian's version), `git` |

Three things that will otherwise cost you time:

- **`tcpdump`, `strace` and `traceroute` are deliberately absent.** They need `CAP_NET_RAW` or `CAP_SYS_PTRACE`, which `--cap-drop=ALL` removes, so they could only ever fail. `ping` works because Docker grants unprivileged ICMP through a sysctl instead.
- **`pip install` needs a venv** — Debian marks the system Python externally managed (PEP 668).
- **Anything reaching a private git repo over SSH will fail.** `~/.ssh` is not mounted and no agent socket is forwarded, which is the point of the sandbox. `terraform init` on private modules, `ansible-galaxy` on private roles and `git clone git@...` all stop at authentication. Vendor the modules into the project, or use HTTPS with a token you are willing to hand the agent.

---

## Troubleshooting

**`make` says "No such file or directory"**
You are not in the repo root. `cd` into the `llm-sandbox` folder first.

**`Refusing to mount ...`**
`PROJECT` resolved to your home directory or `/`. Point it at a single project directory.

**`make setup-claude-oauth` says login may not have completed**
Finish the browser login before typing `/exit`, then run it again.

**Antigravity won't start, or ignores the key and asks you to sign in**
`~/.llm-sandbox/antigravity/settings.json` and your environment disagree about `"modelProvider": "gemini"`. Delete that file and run `make agy-key` (key) or `make agy` (browser) to reseed it.

**`ANTIGRAVITY_API_KEY` stopped working**
It never did anything — the CLI reads `GEMINI_API_KEY` only. Run `make setup-antigravity` and delete the old line from `~/.env.ai-cli`.

**Requests hang or fail with `LOCK=1`**
A host is missing from the allowlist. Check `docker logs llm-sandbox-proxy`, add it, and run `make egress-restart`.

**My old login is gone after upgrading**
The sandbox config directory moved from `~/.claude` to `~/.llm-sandbox/claude`. Re-run a setup command, or move the old file:
`mkdir -p ~/.llm-sandbox/claude && mv ~/.claude/.credentials.json ~/.llm-sandbox/claude/`
