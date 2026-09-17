FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/p9labs-io/llm-sandbox"

# "latest", "stable", or an exact version like "2.1.89".
# "stable" is ~1 week behind latest and skips releases with major regressions.
ARG CLAUDE_CHANNEL=stable

# ── Toolchain ─────────────────────────────────────────────────────────────────
# Baked in because it cannot be added later: the container runs as a non-root
# user with --cap-drop=ALL, so `apt-get install` inside a session always fails,
# and under LOCK=1 the archive is not even reachable. Anything the agent might
# need to debug with has to be here at build time.
#
# Deliberately absent: tcpdump, strace and traceroute need CAP_NET_RAW or
# CAP_SYS_PTRACE, which --cap-drop=ALL removes, so they would only ever fail.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    less \
    \
    dnsutils \
    iproute2 \
    iputils-ping \
    netcat-openbsd \
    socat \
    openssl \
    lsof \
    procps \
    wget \
    \
    ripgrep \
    tree \
    file \
    unzip \
    rsync \
    make \
    \
    python3 \
    python3-pip \
    python3-venv \
    \
    ansible \
    && rm -rf /var/lib/apt/lists/*

# Terraform, verified the same way as the agent binary above: HashiCorp signs the
# SHA256SUMS file, so a tampered download fails the build instead of shipping.
# Signing key fingerprint: C874011F0AB405110D02105534365D9472D7468F
# Installed as root into /usr/local/bin so the agent cannot overwrite it.
ARG TERRAFORM_VERSION=1.16.3
RUN set -eu; \
    case "$(dpkg --print-architecture)" in \
      amd64) tfarch=amd64 ;; \
      arm64) tfarch=arm64 ;; \
      *) echo "unsupported architecture" >&2; exit 1 ;; \
    esac; \
    tmp="$(mktemp -d)"; \
    base="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"; \
    zip="terraform_${TERRAFORM_VERSION}_linux_${tfarch}.zip"; \
    curl -fsSL "$base/$zip"                                        -o "$tmp/$zip"; \
    curl -fsSL "$base/terraform_${TERRAFORM_VERSION}_SHA256SUMS"   -o "$tmp/SHA256SUMS"; \
    curl -fsSL "$base/terraform_${TERRAFORM_VERSION}_SHA256SUMS.72D7468F.sig" -o "$tmp/SHA256SUMS.sig"; \
    curl -fsSL https://www.hashicorp.com/.well-known/pgp-key.txt   -o "$tmp/key.asc"; \
    export GNUPGHOME="$tmp/gnupg"; mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"; \
    gpg --batch --import "$tmp/key.asc"; \
    gpg --batch --with-colons --fingerprint security@hashicorp.com \
      | grep -q '^fpr:::::::::C874011F0AB405110D02105534365D9472D7468F:'; \
    gpg --batch --verify "$tmp/SHA256SUMS.sig" "$tmp/SHA256SUMS"; \
    want="$(awk -v f="$zip" '$2 == f { print $1 }' "$tmp/SHA256SUMS")"; \
    got="$(sha256sum "$tmp/$zip" | cut -d' ' -f1)"; \
    [ -n "$want" ] || { echo "no checksum for $zip" >&2; exit 1; }; \
    [ "$want" = "$got" ] || { echo "checksum mismatch: want=$want got=$got" >&2; exit 1; }; \
    unzip -q "$tmp/$zip" terraform -d /usr/local/bin; \
    chmod 0755 /usr/local/bin/terraform; \
    terraform version; \
    rm -rf "$tmp"

# Terraform otherwise calls checkpoint-api.hashicorp.com on every run to check for
# a newer version — noise under LOCK=1, and one more host to allowlist.
ENV CHECKPOINT_DISABLE=1

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

# An update would silently replace the binary verified above at runtime, so the
# image is the only thing that decides which version runs. Refresh with `make pull`.
# DISABLE_UPDATES is the strict form: DISABLE_AUTOUPDATER alone stops only the
# background updater and leaves `claude update` able to overwrite the binary.
ENV DISABLE_UPDATES=1

# Keep ~/.claude.json (OAuth session, project trust, API-key approval) inside the
# mounted config directory instead of the ephemeral container filesystem — without
# this you re-approve the API key and re-trust the workspace on every run.
ENV CLAUDE_CONFIG_DIR=/home/claude/.claude

# Telemetry and error reporting off. Note that DISABLE_TELEMETRY also turns off
# feature-flag fetching, so features that depend on it (Remote Control among them)
# are unavailable in this image. Unset both lines if you want them back.
ENV DISABLE_TELEMETRY=1
ENV DISABLE_ERROR_REPORTING=1

WORKDIR /workspace

ENTRYPOINT ["claude"]
