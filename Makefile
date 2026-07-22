ORG               := p9labs-io
REGISTRY          := ghcr.io
CLAUDE_IMAGE      := $(REGISTRY)/$(ORG)/claude-cli:latest
ANTIGRAVITY_IMAGE := $(REGISTRY)/$(ORG)/antigravity-cli:latest

BOLD   := \033[1m
RESET  := \033[0m
GREEN  := \033[32m
CYAN   := \033[36m
YELLOW := \033[33m

CLAUDE_CREDS := $(HOME)/.claude/.credentials.json
ENV_FILE     := $(HOME)/.env.ai-cli
PROJECT      ?= $(shell pwd)
ABS_PROJECT  := $(shell realpath $(PROJECT) 2>/dev/null)

.PHONY: help setup setup-claude-oauth setup-claude-key setup-claude setup-antigravity pull pull-claude pull-antigravity claude antigravity agy

help:
	@echo ""
	@echo "$(BOLD)llm-sandbox$(RESET)"
	@echo ""
	@echo "  First-time setup (run once):"
	@echo "  $(CYAN)make setup-claude-oauth$(RESET)  Authenticate with claude.ai Pro (recommended)"
	@echo "  $(CYAN)make setup-claude-key$(RESET)    Save Anthropic API key instead"
	@echo "  $(CYAN)make setup-antigravity$(RESET)   Save Antigravity API key"
	@echo ""
	@echo "  Run:"
	@echo "  $(CYAN)make claude$(RESET)              Run Claude CLI       (PROJECT=projects/my-app)"
	@echo "  $(CYAN)make antigravity$(RESET)           Run Antigravity CLI  (PROJECT=projects/my-app)"
	@echo "  $(CYAN)make agy$(RESET)                 Alias for make antigravity"
	@echo ""
	@echo "  Update images:"
	@echo "  $(CYAN)make pull$(RESET)                Pull latest Claude and Antigravity images"
	@echo "  $(CYAN)make pull-claude$(RESET)         Pull latest Claude image only"
	@echo "  $(CYAN)make pull-antigravity$(RESET)    Pull latest Antigravity image only"
	@echo ""

# ── Pull ───────────────────────────────────────────────────────────────────────
pull-claude:
	docker pull $(CLAUDE_IMAGE)

pull-antigravity:
	docker pull $(ANTIGRAVITY_IMAGE)

pull: pull-claude pull-antigravity

# ── Setup ──────────────────────────────────────────────────────────────────────
setup-claude-oauth:
	@echo ""
	@echo "$(BOLD)Setup — Claude OAuth (Pro plan)$(RESET)"
	@echo ""
	@if [ -f $(CLAUDE_CREDS) ]; then \
		echo "$(GREEN)✓ Credentials found at ~/.claude/.credentials.json$(RESET)"; \
		echo "  You are ready to run: make claude"; \
	else \
		echo "Pulling image..."; \
		docker pull $(CLAUDE_IMAGE) || { echo ""; echo "$(YELLOW)Failed to pull image. Is the package public? Check github.com/orgs/p9labs-io/packages$(RESET)"; exit 1; }; \
		echo ""; \
		echo "Claude will print a login URL — copy it and open it in your browser."; \
		echo "When done, type /exit inside Claude to close the session."; \
		echo ""; \
		mkdir -p $(HOME)/.claude; \
		docker run -it --rm \
			-v "$(HOME)/.claude":/home/claude/.claude \
			$(CLAUDE_IMAGE); \
		if [ -f $(CLAUDE_CREDS) ]; then \
			chmod 600 $(CLAUDE_CREDS); \
			echo ""; \
			echo "$(GREEN)✓ Credentials saved. You are ready to run: make claude$(RESET)"; \
		else \
			echo "$(YELLOW)Login may not have completed. Run make setup-claude-oauth again.$(RESET)"; \
		fi; \
	fi

setup-claude-key:
	@echo ""
	@echo "$(BOLD)Setup — Anthropic API key$(RESET)"
	@printf "Anthropic API key (console.anthropic.com/settings/keys): "; \
		read -r KEY; \
		touch $(ENV_FILE); \
		grep -v '^ANTHROPIC_API_KEY=' $(ENV_FILE) > $(ENV_FILE).tmp 2>/dev/null || true; \
		echo "ANTHROPIC_API_KEY=$$KEY" >> $(ENV_FILE).tmp; \
		mv $(ENV_FILE).tmp $(ENV_FILE); \
		chmod 600 $(ENV_FILE); \
		echo ""; \
		echo "$(GREEN)✓ Saved to ~/.env.ai-cli$(RESET)"; \
		echo "Pulling image..."; \
		docker pull $(CLAUDE_IMAGE) || { echo ""; echo "$(YELLOW)Failed to pull image. Is the package public? Check github.com/orgs/p9labs-io/packages$(RESET)"; exit 1; }; \
		echo "$(GREEN)✓ Ready. Run: make claude$(RESET)"

setup-claude: setup-claude-oauth

setup-antigravity:
	@echo ""
	@echo "$(BOLD)Setup — Antigravity API key$(RESET)"
	@printf "Antigravity API key (antigravity.google/docs/cli/reference): "; \
		read -r KEY; \
		touch $(ENV_FILE); \
		grep -v '^ANTIGRAVITY_API_KEY=' $(ENV_FILE) > $(ENV_FILE).tmp 2>/dev/null || true; \
		echo "ANTIGRAVITY_API_KEY=$$KEY" >> $(ENV_FILE).tmp; \
		mv $(ENV_FILE).tmp $(ENV_FILE); \
		chmod 600 $(ENV_FILE); \
		echo ""; \
		echo "$(GREEN)✓ Saved to ~/.env.ai-cli$(RESET)"; \
		echo "Pulling image..."; \
		docker pull $(ANTIGRAVITY_IMAGE); \
		echo "$(GREEN)✓ Ready. Run: make antigravity$(RESET)"

setup: setup-claude-oauth setup-antigravity

# ── Helpers ────────────────────────────────────────────────────────────────────
# Returns 0 if OAuth token is expired or missing, 1 if valid
_claude_token_expired:
	@EXPIRES=$$(python3 -c "import json,sys; d=json.load(open('$(CLAUDE_CREDS)')); print(d.get('claudeAiOauth',{}).get('expiresAt',0))" 2>/dev/null); \
	NOW=$$(python3 -c "import time; print(int(time.time()*1000))"); \
	[ -z "$$EXPIRES" ] || [ "$$NOW" -ge "$$EXPIRES" ]

# ── Run ────────────────────────────────────────────────────────────────────────
claude:
	@if [ -z "$(ABS_PROJECT)" ]; then \
		echo ""; echo "$(YELLOW)Project path not found: $(PROJECT)$(RESET)"; echo ""; exit 1; \
	fi; \
	docker image inspect $(CLAUDE_IMAGE) > /dev/null 2>&1 || docker pull $(CLAUDE_IMAGE); \
	if [ -f $(CLAUDE_CREDS) ]; then \
		EXPIRES=$$(python3 -c "import json; d=json.load(open('$(CLAUDE_CREDS)')); print(d.get('claudeAiOauth',{}).get('expiresAt',0))" 2>/dev/null); \
		NOW=$$(python3 -c "import time; print(int(time.time()*1000))"); \
		if [ -n "$$EXPIRES" ] && [ "$$NOW" -ge "$$EXPIRES" ]; then \
			echo "$(YELLOW)OAuth token expired. Re-authenticating...$(RESET)"; \
			rm -f $(CLAUDE_CREDS); \
			$(MAKE) setup-claude-oauth; \
		fi; \
	fi; \
	if [ -f $(CLAUDE_CREDS) ]; then \
		echo "$(GREEN)Auth: OAuth (Pro plan)$(RESET)"; \
		docker run -it --rm \
			-v "$(ABS_PROJECT)":/workspace \
			-v "$(CLAUDE_CREDS)":/home/claude/.claude/.credentials.json:ro \
			$(CLAUDE_IMAGE); \
	elif [ -f $(ENV_FILE) ] && grep -q '^ANTHROPIC_API_KEY=' $(ENV_FILE); then \
		echo "$(GREEN)Auth: API key$(RESET)"; \
		set -a; . $(ENV_FILE); set +a; \
		docker run -it --rm \
			-v "$(ABS_PROJECT)":/workspace \
			-e ANTHROPIC_API_KEY="$$ANTHROPIC_API_KEY" \
			$(CLAUDE_IMAGE); \
	else \
		echo ""; \
		echo "No Claude credentials found. Run one of:"; \
		echo "  make setup-claude-oauth   (Pro plan)"; \
		echo "  make setup-claude-key     (API key)"; \
		echo ""; \
		exit 1; \
	fi

antigravity:
	@if [ -z "$(ABS_PROJECT)" ]; then \
		echo ""; echo "$(YELLOW)Project path not found: $(PROJECT)$(RESET)"; echo ""; exit 1; \
	fi; \
	docker image inspect $(ANTIGRAVITY_IMAGE) > /dev/null 2>&1 || docker pull $(ANTIGRAVITY_IMAGE); \
	if [ ! -f $(ENV_FILE) ] || ! grep -q '^ANTIGRAVITY_API_KEY=' $(ENV_FILE); then \
		echo "No ANTIGRAVITY_API_KEY found. Run 'make setup-antigravity' first."; exit 1; \
	fi; \
	set -a; . $(ENV_FILE); set +a; \
	docker run -it --rm \
		-v "$(ABS_PROJECT)":/workspace \
		-e ANTIGRAVITY_API_KEY="$$ANTIGRAVITY_API_KEY" \
		$(ANTIGRAVITY_IMAGE)

agy: antigravity