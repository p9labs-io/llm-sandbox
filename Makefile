ORG          := p9labs-io
REGISTRY     := ghcr.io
CLAUDE_IMAGE := $(REGISTRY)/$(ORG)/claude-cli:latest
GEMINI_IMAGE := $(REGISTRY)/$(ORG)/gemini-cli:latest

BOLD   := \033[1m
RESET  := \033[0m
GREEN  := \033[32m
CYAN   := \033[36m
YELLOW := \033[33m

CLAUDE_CREDS := $(HOME)/.claude/.credentials.json
ENV_FILE     := $(HOME)/.env.ai-cli
PROJECT      ?= $(shell pwd)
ABS_PROJECT  := $(shell realpath $(PROJECT))

.PHONY: help setup setup-claude-oauth setup-claude-key setup-claude setup-gemini pull pull-claude pull-gemini claude gemini

help:
	@echo ""
	@echo "$(BOLD)llm-sandbox$(RESET)"
	@echo ""
	@echo "  First-time setup (run once):"
	@echo "  $(CYAN)make setup-claude-oauth$(RESET)  Authenticate with claude.ai Pro (recommended)"
	@echo "  $(CYAN)make setup-claude-key$(RESET)    Save Anthropic API key instead"
	@echo "  $(CYAN)make setup-gemini$(RESET)        Save Google API key"
	@echo ""
	@echo "  Run:"
	@echo "  $(CYAN)make claude$(RESET)              Run Claude CLI  (PROJECT=projects/my-app)"
	@echo "  $(CYAN)make gemini$(RESET)              Run Gemini CLI  (PROJECT=projects/my-app)"
	@echo ""
	@echo "  Update images:"
	@echo "  $(CYAN)make pull$(RESET)                Pull latest Claude and Gemini images"
	@echo "  $(CYAN)make pull-claude$(RESET)         Pull latest Claude image only"
	@echo "  $(CYAN)make pull-gemini$(RESET)         Pull latest Gemini image only"
	@echo ""

# ── Pull ───────────────────────────────────────────────────────────────────────
pull-claude:
	docker pull $(CLAUDE_IMAGE)

pull-gemini:
	docker pull $(GEMINI_IMAGE)

pull: pull-claude pull-gemini

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
		if grep -q '^ANTHROPIC_API_KEY=' $(ENV_FILE) 2>/dev/null; then \
			sed -i '' 's|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY='"$$KEY"'|' $(ENV_FILE); \
		else \
			echo "ANTHROPIC_API_KEY=$$KEY" >> $(ENV_FILE); \
		fi; \
		chmod 600 $(ENV_FILE); \
		echo ""; \
		echo "$(GREEN)✓ Saved to ~/.env.ai-cli$(RESET)"; \
		echo "Pulling image..."; \
		docker pull $(CLAUDE_IMAGE) || { echo ""; echo "$(YELLOW)Failed to pull image. Is the package public? Check github.com/orgs/p9labs-io/packages$(RESET)"; exit 1; }; \
		echo "$(GREEN)✓ Ready. Run: make claude$(RESET)"

setup-claude: setup-claude-oauth

setup-gemini:
	@echo ""
	@echo "$(BOLD)Setup — Google API key$(RESET)"
	@printf "Google API key (aistudio.google.com/apikey): "; \
		read -r KEY; \
		touch $(ENV_FILE); \
		if grep -q '^GOOGLE_API_KEY=' $(ENV_FILE) 2>/dev/null; then \
			sed -i '' 's|^GOOGLE_API_KEY=.*|GOOGLE_API_KEY='"$$KEY"'|' $(ENV_FILE); \
		else \
			echo "GOOGLE_API_KEY=$$KEY" >> $(ENV_FILE); \
		fi; \
		chmod 600 $(ENV_FILE); \
		echo ""; \
		echo "$(GREEN)✓ Saved to ~/.env.ai-cli$(RESET)"; \
		echo "Pulling image..."; \
		docker pull $(GEMINI_IMAGE); \
		echo "$(GREEN)✓ Ready. Run: make gemini$(RESET)"

setup: setup-claude-oauth setup-gemini

# ── Run ────────────────────────────────────────────────────────────────────────
claude:
	@docker image inspect $(CLAUDE_IMAGE) > /dev/null 2>&1 || docker pull $(CLAUDE_IMAGE); \
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

gemini:
	@docker image inspect $(GEMINI_IMAGE) > /dev/null 2>&1 || docker pull $(GEMINI_IMAGE); \
	if [ ! -f $(ENV_FILE) ] || ! grep -q '^GOOGLE_API_KEY=' $(ENV_FILE); then \
		echo "No GOOGLE_API_KEY found. Run 'make setup-gemini' first."; exit 1; \
	fi; \
	set -a; . $(ENV_FILE); set +a; \
	docker run -it --rm \
		-v "$(ABS_PROJECT)":/workspace \
		-e GOOGLE_API_KEY="$$GOOGLE_API_KEY" \
		$(GEMINI_IMAGE)