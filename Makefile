ORG               := p9labs-io
REGISTRY          := ghcr.io
CLAUDE_IMAGE      := $(REGISTRY)/$(ORG)/claude-cli:latest
ANTIGRAVITY_IMAGE := $(REGISTRY)/$(ORG)/antigravity-cli:latest
PROXY_IMAGE       := llm-sandbox/egress-proxy:latest

BOLD   := \033[1m
RESET  := \033[0m
GREEN  := \033[32m
CYAN   := \033[36m
YELLOW := \033[33m

# Container-only config directories. Deliberately NOT $(HOME)/.claude: the agent
# gets a persistent home of its own without ever seeing the host's Claude Code
# settings, hooks, plugins or session history.
SANDBOX_HOME := $(HOME)/.llm-sandbox
CLAUDE_HOME  := $(SANDBOX_HOME)/claude
AGY_HOME     := $(SANDBOX_HOME)/antigravity
CLAUDE_CREDS := $(CLAUDE_HOME)/.credentials.json
ENV_FILE     := $(HOME)/.env.ai-cli

# Expand a leading ~ before quoting, so paths containing spaces still work.
PROJECT      ?= $(shell pwd)
PROJECT_EXP  := $(patsubst ~%,$(HOME)%,$(PROJECT))
ABS_PROJECT  := $(shell realpath "$(PROJECT_EXP)" 2>/dev/null)

# Resource ceilings: a runaway or hostile session cannot exhaust the host.
DOCKER_MEM   ?= 4g
DOCKER_CPUS  ?= 4
DOCKER_PIDS  ?= 512

HARDEN := --init \
	--cap-drop=ALL \
	--security-opt=no-new-privileges:true \
	--pids-limit=$(DOCKER_PIDS) \
	--memory=$(DOCKER_MEM) \
	--cpus=$(DOCKER_CPUS)

# Refuse to mount $HOME or / — the whole point of the sandbox is a narrow mount.
GUARD_PROJECT = if [ -z "$(ABS_PROJECT)" ] || [ ! -d "$(ABS_PROJECT)" ]; then echo ""; echo "$(YELLOW)Project path not found: $(PROJECT)$(RESET)"; echo ""; exit 1; fi; case "$(ABS_PROJECT)" in "$(HOME)"|"/") echo ""; echo "$(YELLOW)Refusing to mount $(ABS_PROJECT) — point PROJECT at a single project directory.$(RESET)"; echo ""; exit 1;; esac

# ── Egress allowlist (LOCK=1) ─────────────────────────────────────────────────
NET_INT := llm-sandbox-internal
NET_EXT := llm-sandbox-egress
PROXY   := llm-sandbox-proxy

ifeq ($(LOCK),1)
NET_FLAGS := --network=$(NET_INT) \
	-e HTTPS_PROXY=http://$(PROXY):8888 \
	-e HTTP_PROXY=http://$(PROXY):8888 \
	-e NO_PROXY=localhost,127.0.0.1
NET_DEP   := egress-up
NET_LABEL := $(GREEN)Network: allowlisted egress via $(PROXY)$(RESET)
else
NET_FLAGS :=
NET_DEP   :=
NET_LABEL := $(YELLOW)Network: unrestricted (add LOCK=1 for an egress allowlist)$(RESET)
endif

.PHONY: help setup setup-claude setup-claude-token setup-claude-key setup-claude-oauth \
	setup-antigravity pull pull-claude pull-antigravity claude claude-token claude-key \
	claude-oauth claude-shell antigravity agy egress-build egress-up egress-down egress-restart

help:
	@echo ""
	@echo "$(BOLD)llm-sandbox$(RESET)"
	@echo ""
	@echo "  First-time setup (run once):"
	@echo "  $(CYAN)make setup-claude-token$(RESET)  Pro/Max plan, scoped long-lived token (recommended)"
	@echo "  $(CYAN)make setup-claude-key$(RESET)    Anthropic API key (pay-per-token, revocable)"
	@echo "  $(CYAN)make setup-claude-oauth$(RESET)  Full OAuth login stored in the sandbox (least isolated)"
	@echo "  $(CYAN)make setup-antigravity$(RESET)   Save Antigravity API key"
	@echo ""
	@echo "  Run:"
	@echo "  $(CYAN)make claude$(RESET)              Run Claude CLI (auto-detects auth)"
	@echo "  $(CYAN)make claude-token$(RESET)        Force CLAUDE_CODE_OAUTH_TOKEN"
	@echo "  $(CYAN)make claude-key$(RESET)          Force ANTHROPIC_API_KEY"
	@echo "  $(CYAN)make claude-oauth$(RESET)        Force stored OAuth login"
	@echo "  $(CYAN)make claude-shell$(RESET)        Shell in the Claude image (debugging)"
	@echo "  $(CYAN)make antigravity$(RESET)         Run Antigravity CLI"
	@echo "  $(CYAN)make agy$(RESET)                 Alias for make antigravity"
	@echo ""
	@echo "  Options:"
	@echo "  $(CYAN)PROJECT=path/to/app$(RESET)      Directory to mount at /workspace"
	@echo "  $(CYAN)LOCK=1$(RESET)                   Restrict egress to images/egress/allowlist"
	@echo "  $(CYAN)DOCKER_MEM/DOCKER_CPUS$(RESET)   Resource ceilings (default $(DOCKER_MEM) / $(DOCKER_CPUS))"
	@echo ""
	@echo "  Maintenance:"
	@echo "  $(CYAN)make pull$(RESET)                Pull latest Claude and Antigravity images"
	@echo "  $(CYAN)make egress-build$(RESET)        Build the allowlist proxy image"
	@echo "  $(CYAN)make egress-down$(RESET)         Stop and remove the proxy and its networks"
	@echo ""

# ── Pull ───────────────────────────────────────────────────────────────────────
pull-claude:
	docker pull $(CLAUDE_IMAGE)

pull-antigravity:
	docker pull $(ANTIGRAVITY_IMAGE)

pull: pull-claude pull-antigravity

# ── Setup ──────────────────────────────────────────────────────────────────────
# Writes KEY=VALUE into $(ENV_FILE) without ever exposing the value on a command
# line, in `ps`, or in a world-readable temp file.
# $(1) variable name, $(2) prompt text
define read_secret
	umask 077; \
	touch "$(ENV_FILE)"; \
	chmod 600 "$(ENV_FILE)"; \
	printf "$(2): "; \
	stty -echo 2>/dev/null; read -r VALUE; stty echo 2>/dev/null; echo ""; \
	if [ -z "$$VALUE" ]; then echo "$(YELLOW)Nothing entered — aborting.$(RESET)"; exit 1; fi; \
	grep -v '^$(1)=' "$(ENV_FILE)" > "$(ENV_FILE).tmp" 2>/dev/null || true; \
	printf '%s=%s\n' '$(1)' "$$VALUE" >> "$(ENV_FILE).tmp"; \
	chmod 600 "$(ENV_FILE).tmp"; \
	mv "$(ENV_FILE).tmp" "$(ENV_FILE)"; \
	echo "$(GREEN)✓ Saved $(1) to $(ENV_FILE)$(RESET)"
endef

setup-claude-token:
	@echo ""
	@echo "$(BOLD)Setup — Claude Pro/Max long-lived token (recommended)$(RESET)"
	@echo ""
	@echo "A throwaway container will run 'claude setup-token'. Follow the browser"
	@echo "login, then copy the token it prints and paste it below."
	@echo ""
	@echo "Unlike a full OAuth login, this token can only make model requests — it"
	@echo "cannot open Remote Control sessions or reach your claude.ai connectors."
	@echo ""
	@docker image inspect $(CLAUDE_IMAGE) > /dev/null 2>&1 || docker pull $(CLAUDE_IMAGE)
	@docker run -it --rm $(HARDEN) --entrypoint claude $(CLAUDE_IMAGE) setup-token || true
	@echo ""
	@$(call read_secret,CLAUDE_CODE_OAUTH_TOKEN,Paste the token)
	@echo "$(GREEN)✓ Ready. Run: make claude-token PROJECT=path/to/app$(RESET)"

setup-claude-key:
	@echo ""
	@echo "$(BOLD)Setup — Anthropic API key$(RESET)"
	@echo ""
	@echo "Create a key scoped to its own workspace with a spend limit at"
	@echo "console.anthropic.com/settings/keys, so it can be revoked on its own."
	@echo ""
	@$(call read_secret,ANTHROPIC_API_KEY,Anthropic API key)
	@docker pull $(CLAUDE_IMAGE) || { echo ""; echo "$(YELLOW)Failed to pull image. Is the package public? Check github.com/orgs/$(ORG)/packages$(RESET)"; exit 1; }
	@echo "$(GREEN)✓ Ready. Run: make claude-key PROJECT=path/to/app$(RESET)"

setup-claude-oauth:
	@echo ""
	@echo "$(BOLD)Setup — Claude OAuth login (stored in the sandbox)$(RESET)"
	@echo ""
	@if [ -f "$(CLAUDE_CREDS)" ]; then \
		echo "$(GREEN)✓ Credentials found at $(CLAUDE_CREDS)$(RESET)"; \
		echo "  You are ready to run: make claude-oauth"; \
	else \
		echo "$(YELLOW)Note: this stores a refresh token the agent can read. Prefer$(RESET)"; \
		echo "$(YELLOW)make setup-claude-token or make setup-claude-key.$(RESET)"; \
		echo ""; \
		docker image inspect $(CLAUDE_IMAGE) > /dev/null 2>&1 || docker pull $(CLAUDE_IMAGE) || { echo "$(YELLOW)Failed to pull image.$(RESET)"; exit 1; }; \
		echo "Claude will print a login URL — copy it and open it in your browser."; \
		echo "When done, type /exit inside Claude to close the session."; \
		echo ""; \
		mkdir -p "$(CLAUDE_HOME)"; chmod 700 "$(SANDBOX_HOME)" "$(CLAUDE_HOME)"; \
		docker run -it --rm $(HARDEN) -v "$(CLAUDE_HOME)":/home/claude/.claude $(CLAUDE_IMAGE); \
		if [ -f "$(CLAUDE_CREDS)" ]; then \
			chmod 600 "$(CLAUDE_CREDS)"; \
			echo ""; \
			echo "$(GREEN)✓ Credentials saved. You are ready to run: make claude-oauth$(RESET)"; \
		else \
			echo "$(YELLOW)Login may not have completed. Run make setup-claude-oauth again.$(RESET)"; \
		fi; \
	fi

setup-claude: setup-claude-token

setup-antigravity:
	@echo ""
	@echo "$(BOLD)Setup — Antigravity API key$(RESET)"
	@echo "  (antigravity.google/docs/cli/reference)"
	@echo ""
	@$(call read_secret,ANTIGRAVITY_API_KEY,Antigravity API key)
	@docker pull $(ANTIGRAVITY_IMAGE)
	@echo "$(GREEN)✓ Ready. Run: make antigravity PROJECT=path/to/app$(RESET)"

setup: setup-claude-token setup-antigravity

# ── Egress allowlist proxy ────────────────────────────────────────────────────
egress-build:
	docker build -t $(PROXY_IMAGE) images/egress

egress-up:
	@docker image inspect $(PROXY_IMAGE) > /dev/null 2>&1 || $(MAKE) --no-print-directory egress-build
	@docker network inspect $(NET_INT) > /dev/null 2>&1 || docker network create --internal $(NET_INT) > /dev/null
	@docker network inspect $(NET_EXT) > /dev/null 2>&1 || docker network create $(NET_EXT) > /dev/null
	@if [ -z "$$(docker ps -q -f name=^$(PROXY)$$)" ]; then \
		docker rm -f $(PROXY) > /dev/null 2>&1 || true; \
		docker run -d --name $(PROXY) \
			--network=$(NET_INT) \
			--init \
			--cap-drop=ALL --cap-add=SETUID --cap-add=SETGID \
			--security-opt=no-new-privileges:true \
			--read-only --tmpfs /tmp \
			--memory=256m --pids-limit=128 \
			$(PROXY_IMAGE) > /dev/null; \
		docker network connect $(NET_EXT) $(PROXY) > /dev/null 2>&1 || true; \
		echo "$(GREEN)✓ Egress proxy started$(RESET)"; \
	fi

egress-down:
	-@docker rm -f $(PROXY) > /dev/null 2>&1
	-@docker network rm $(NET_INT) $(NET_EXT) > /dev/null 2>&1
	@echo "$(GREEN)✓ Egress proxy removed$(RESET)"

egress-restart: egress-down egress-build egress-up

# ── Run ────────────────────────────────────────────────────────────────────────
# Common flags. The config directory is per-sandbox, never the host's ~/.claude.
CLAUDE_RUN = docker run -it --rm $(HARDEN) $(NET_FLAGS) \
	-v "$(ABS_PROJECT)":/workspace \
	-v "$(CLAUDE_HOME)":/home/claude/.claude

PREP_CLAUDE = $(GUARD_PROJECT); \
	docker image inspect $(CLAUDE_IMAGE) > /dev/null 2>&1 || docker pull $(CLAUDE_IMAGE); \
	mkdir -p "$(CLAUDE_HOME)"; chmod 700 "$(SANDBOX_HOME)" "$(CLAUDE_HOME)"; \
	echo "$(NET_LABEL)"

claude-token: $(NET_DEP)
	@$(PREP_CLAUDE); \
	if [ ! -f "$(ENV_FILE)" ] || ! grep -q '^CLAUDE_CODE_OAUTH_TOKEN=' "$(ENV_FILE)"; then \
		echo "$(YELLOW)No CLAUDE_CODE_OAUTH_TOKEN found. Run 'make setup-claude-token' first.$(RESET)"; exit 1; \
	fi; \
	echo "$(GREEN)Auth: Pro/Max long-lived token (model requests only)$(RESET)"; \
	set -a; . "$(ENV_FILE)"; set +a; \
	$(CLAUDE_RUN) -e CLAUDE_CODE_OAUTH_TOKEN $(CLAUDE_IMAGE)

claude-key: $(NET_DEP)
	@$(PREP_CLAUDE); \
	if [ ! -f "$(ENV_FILE)" ] || ! grep -q '^ANTHROPIC_API_KEY=' "$(ENV_FILE)"; then \
		echo "$(YELLOW)No ANTHROPIC_API_KEY found. Run 'make setup-claude-key' first.$(RESET)"; exit 1; \
	fi; \
	echo "$(GREEN)Auth: API key (revocable, spend-limitable)$(RESET)"; \
	set -a; . "$(ENV_FILE)"; set +a; \
	$(CLAUDE_RUN) -e ANTHROPIC_API_KEY $(CLAUDE_IMAGE)

# Stored OAuth login. The credentials directory is mounted read-write on purpose:
# a read-only mount breaks token refresh, and read-only never protected the token
# anyway — anything that can read it can replay it.
claude-oauth: $(NET_DEP)
	@$(PREP_CLAUDE); \
	if [ ! -f "$(CLAUDE_CREDS)" ]; then \
		echo "$(YELLOW)No stored OAuth credentials. Run 'make setup-claude-oauth' first.$(RESET)"; exit 1; \
	fi; \
	echo "$(YELLOW)Auth: stored OAuth login — the agent can read this refresh token$(RESET)"; \
	$(CLAUDE_RUN) $(CLAUDE_IMAGE)

# Auto-detect, narrowest credential first.
claude:
	@if [ -f "$(ENV_FILE)" ] && grep -q '^CLAUDE_CODE_OAUTH_TOKEN=' "$(ENV_FILE)"; then \
		$(MAKE) --no-print-directory claude-token; \
	elif [ -f "$(ENV_FILE)" ] && grep -q '^ANTHROPIC_API_KEY=' "$(ENV_FILE)"; then \
		$(MAKE) --no-print-directory claude-key; \
	elif [ -f "$(CLAUDE_CREDS)" ]; then \
		$(MAKE) --no-print-directory claude-oauth; \
	else \
		echo ""; \
		echo "No Claude credentials found. Run one of:"; \
		echo "  make setup-claude-token   (Pro/Max, recommended)"; \
		echo "  make setup-claude-key     (API key)"; \
		echo "  make setup-claude-oauth   (full OAuth login)"; \
		echo ""; \
		exit 1; \
	fi

# Shell inside the image with no credentials attached, for debugging the sandbox.
claude-shell: $(NET_DEP)
	@$(GUARD_PROJECT); \
	docker run -it --rm $(HARDEN) $(NET_FLAGS) \
		-v "$(ABS_PROJECT)":/workspace \
		--entrypoint /bin/bash $(CLAUDE_IMAGE)

antigravity: $(NET_DEP)
	@$(GUARD_PROJECT); \
	docker image inspect $(ANTIGRAVITY_IMAGE) > /dev/null 2>&1 || docker pull $(ANTIGRAVITY_IMAGE); \
	mkdir -p "$(AGY_HOME)"; chmod 700 "$(SANDBOX_HOME)" "$(AGY_HOME)"; \
	echo "$(NET_LABEL)"; \
	KEYFLAG=""; \
	if [ -f "$(ENV_FILE)" ] && grep -q '^ANTIGRAVITY_API_KEY=' "$(ENV_FILE)"; then \
		set -a; . "$(ENV_FILE)"; set +a; \
		KEYFLAG="-e ANTIGRAVITY_API_KEY"; \
	fi; \
	docker run -it --rm $(HARDEN) $(NET_FLAGS) $$KEYFLAG \
		-v "$(ABS_PROJECT)":/workspace \
		-v "$(AGY_HOME)":/home/antigravity/.gemini/antigravity-cli \
		$(ANTIGRAVITY_IMAGE)

agy: antigravity
