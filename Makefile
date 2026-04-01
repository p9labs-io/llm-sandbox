ORG          := p9labs-io
REGISTRY     := ghcr.io
CLAUDE_IMAGE := $(REGISTRY)/$(ORG)/claude-cli:latest
GEMINI_IMAGE := $(REGISTRY)/$(ORG)/gemini-cli:latest

BOLD  := \033[1m
RESET := \033[0m
GREEN := \033[32m
CYAN  := \033[36m

.PHONY: help setup setup-claude setup-gemini claude gemini

help:
	@echo ""
	@echo "$(BOLD)llm-sandbox$(RESET)"
	@echo ""
	@echo "  $(CYAN)make setup$(RESET)         Save keys for both Claude and Gemini"
	@echo "  $(CYAN)make setup-claude$(RESET)  Save Anthropic API key only"
	@echo "  $(CYAN)make setup-gemini$(RESET)  Save Google API key only"
	@echo "  $(CYAN)make claude$(RESET)        Run Claude CLI in current directory"
	@echo "  $(CYAN)make gemini$(RESET)        Run Gemini CLI in current directory"
	@echo ""

# ── Setup ──────────────────────────────────────────────────────────────────────
setup-claude:
	@echo ""
	@echo "$(BOLD)Setup — Anthropic API key$(RESET)"
	@printf "Anthropic API key (claude.ai/settings/keys): "; \
		read -r KEY; \
		touch $(HOME)/.env.ai-cli; \
		if grep -q '^ANTHROPIC_API_KEY=' $(HOME)/.env.ai-cli 2>/dev/null; then \
			sed -i '' 's|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY='"$$KEY"'|' $(HOME)/.env.ai-cli; \
		else \
			echo "ANTHROPIC_API_KEY=$$KEY" >> $(HOME)/.env.ai-cli; \
		fi; \
		chmod 600 $(HOME)/.env.ai-cli; \
		echo ""; \
		echo "$(GREEN)✓ Saved to ~/.env.ai-cli$(RESET)"

setup-gemini:
	@echo ""
	@echo "$(BOLD)Setup — Google API key$(RESET)"
	@printf "Google API key (aistudio.google.com/apikey): "; \
		read -r KEY; \
		touch $(HOME)/.env.ai-cli; \
		if grep -q '^GOOGLE_API_KEY=' $(HOME)/.env.ai-cli 2>/dev/null; then \
			sed -i '' 's|^GOOGLE_API_KEY=.*|GOOGLE_API_KEY='"$$KEY"'|' $(HOME)/.env.ai-cli; \
		else \
			echo "GOOGLE_API_KEY=$$KEY" >> $(HOME)/.env.ai-cli; \
		fi; \
		chmod 600 $(HOME)/.env.ai-cli; \
		echo ""; \
		echo "$(GREEN)✓ Saved to ~/.env.ai-cli$(RESET)"

setup: setup-claude setup-gemini

# ── Run ────────────────────────────────────────────────────────────────────────
claude:
	@set -a; . $(HOME)/.env.ai-cli; set +a; \
	if [ -z "$$ANTHROPIC_API_KEY" ]; then \
		echo "No ANTHROPIC_API_KEY found. Run 'make setup-claude' first."; exit 1; \
	fi; \
	docker run -it --rm \
		-v "$$(pwd)":/workspace \
		-e ANTHROPIC_API_KEY="$$ANTHROPIC_API_KEY" \
		$(CLAUDE_IMAGE)

gemini:
	@set -a; . $(HOME)/.env.ai-cli; set +a; \
	if [ -z "$$GOOGLE_API_KEY" ]; then \
		echo "No GOOGLE_API_KEY found. Run 'make setup-gemini' first."; exit 1; \
	fi; \
	docker run -it --rm \
		-v "$$(pwd)":/workspace \
		-e GOOGLE_API_KEY="$$GOOGLE_API_KEY" \
		$(GEMINI_IMAGE)