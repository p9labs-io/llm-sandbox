FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/p9labs-io/llm-sandbox"

# "latest", "stable", or an exact version like "2.1.89".
# "stable" is ~1 week behind latest and skips releases with major regressions.
ARG CLAUDE_CHANNEL=stable

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    less \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash claude
USER claude
ENV PATH="/home/claude/.local/bin:${PATH}"

# Install Claude Code, then verify the installed binary against Anthropic's
# GPG-signed release manifest. Without this step `curl | bash` is trust-on-first-use:
# a compromised installer would be baked straight into the weekly image rebuild.
# Signing key fingerprint: 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
RUN set -eu; \
    curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_CHANNEL}"; \
    version="$(claude --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"; \
    [ -n "$version" ] || { echo "could not determine installed version" >&2; exit 1; }; \
    tmp="$(mktemp -d)"; \
    curl -fsSL https://downloads.claude.ai/keys/claude-code.asc -o "$tmp/key.asc"; \
    gpg --batch --import "$tmp/key.asc"; \
    gpg --batch --with-colons --fingerprint security@anthropic.com \
      | grep -q '^fpr:::::::::31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE:'; \
    repo=https://downloads.claude.ai/claude-code-releases; \
    curl -fsSL "$repo/$version/manifest.json"     -o "$tmp/manifest.json"; \
    curl -fsSL "$repo/$version/manifest.json.sig" -o "$tmp/manifest.json.sig"; \
    gpg --batch --verify "$tmp/manifest.json.sig" "$tmp/manifest.json"; \
    case "$(dpkg --print-architecture)" in \
      amd64) plat=linux-x64 ;; \
      arm64) plat=linux-arm64 ;; \
      *) echo "unsupported architecture" >&2; exit 1 ;; \
    esac; \
    want="$(jq -r --arg p "$plat" '.platforms[$p].checksum' "$tmp/manifest.json")"; \
    got="$(sha256sum "$(readlink -f "$(command -v claude)")" | cut -d' ' -f1)"; \
    [ -n "$want" ] && [ "$want" != "null" ] || { echo "no checksum for $plat" >&2; exit 1; }; \
    [ "$want" = "$got" ] || { echo "checksum mismatch: want=$want got=$got" >&2; exit 1; }; \
    echo "verified claude $version ($plat) against signed manifest"; \
    rm -rf "$tmp" "$HOME/.gnupg"

# Auto-update would silently replace the binary verified above at runtime, so the
# image is the only thing that decides which version runs. Refresh with `make pull`.
ENV DISABLE_AUTOUPDATER=1

# Keep ~/.claude.json (OAuth session, project trust, API-key approval) inside the
# mounted config directory instead of the ephemeral container filesystem — without
# this you re-approve the API key and re-trust the workspace on every run.
ENV CLAUDE_CONFIG_DIR=/home/claude/.claude

# Optional operational telemetry / error reporting to Datadog. Off by default here;
# remove these lines if you want them.
ENV DISABLE_TELEMETRY=1
ENV DISABLE_ERROR_REPORTING=1

WORKDIR /workspace

ENTRYPOINT ["claude"]
