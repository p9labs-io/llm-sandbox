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

.PHONY: help setup setup-claude-oauth setup-claude-key setup-claude setup-gemini claude gemini

help:
	@echo ""
	@echo "$(BOLD)llm-sandbox$(RESET)"
	@echo ""
	@echo "  Claude auth (pick one):"
	@echo "  $(CYAN)make setup-claude-oauth$(RESET)  Use claude.ai Pro subscription (recommended)"
	@echo "  $(CYAN)make setup-claude-key$(RESET)    Use Anthropic API key (console.anthropic.com)"
	@echo ""
	@echo "  Gemini auth:"
	@echo "  $(CYAN)make setup-gemini$(RESET)        Save Google API key"
	@echo ""
	@echo "  Run:"
	@echo "  $(CYAN)make claude$(RESET)              Run Claude CLI  (PROJECT=projects/my-app)"
	@echo "  $(CYAN)make gemini$(RESET)              Run Gemini CLI  (PROJECT=projects/my-app)"
	@echo ""

# ── Setup Claude ───────────────────────────────────────────────────────────────
setup-claude-oauth:
	@echo ""
	@echo "$(BOLD)Setup — Claude OAuth (Pro plan)$(RESET)"
	@echo ""
	@if [ -f $(CLAUDE_CREDS) ]; then \
		echo "$(GREEN)✓ Credentials found at ~/.claude/.credentials.json$(RESET)"; \
		echo "  You are ready to run: make claude"; \
	else \
		echo "Launching container to authenticate with claude.ai..."; \
		echo "A browser window will open — log in with your claude.ai account."; \
		echo "When done, type /exit inside Claude to close the session."; \
		echo ""; \
		mkdir -p $(HOME)/.claude; \
		docker run -it --rm \
			-v "$(HOME)/.claude":/root/.claude \
			$(CLAUDE_IMAGE); \
		if [ -f $(CLAUDE_CREDS) ]; then \
			chmod 600 $(CLAUDE_CREDS); \
			echo ""; \
			echo "$(GREEN)✓ Credentials saved to ~/.claude/.credentials.json$(RESET)"; \
			echo "  You are ready to run: make claude"; \
		else \
			echo "$(YELLOW)Login may not have completed. Try running make setup-claude-oauth again.$(RESET)"; \
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
		echo "$(GREEN)✓ Saved to ~/.env.ai-cli$(RESET)"

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
		echo "$(GREEN)✓ Saved to ~/.env.ai-cli$(RESET)"

setup: setup-claude-oauth setup-gemini

# ── Run ────────────────────────────────────────────────────────────────────────
claude:
	@if [ -f $(CLAUDE_CREDS) ]; then \
		echo "$(GREEN)Auth: OAuth (Pro plan)$(RESET)"; \
		docker run -it --rm \
			-v "$(PROJECT)":/workspace \
			-v "$(CLAUDE_CREDS)":/root/.claude/.credentials.json:ro \
			$(CLAUDE_IMAGE); \
	elif [ -f $(ENV_FILE) ] && grep -q '^ANTHROPIC_API_KEY=' $(ENV_FILE); then \
		echo "$(GREEN)Auth: API key$(RESET)"; \
		set -a; . $(ENV_FILE); set +a; \
		docker run -it --rm \
			-v "$(PROJECT)":/workspace \
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
	@if [ ! -f $(ENV_FILE) ] || ! grep -q '^GOOGLE_API_KEY=' $(ENV_FILE); then \
		echo "No GOOGLE_API_KEY found. Run 'make setup-gemini' first."; exit 1; \
	fi; \
	set -a; . $(ENV_FILE); set +a; \
	docker run -it --rm \
		-v "$(PROJECT)":/workspace \
		-e GOOGLE_API_KEY="$$GOOGLE_API_KEY" \
		$(GEMINI_IMAGE)