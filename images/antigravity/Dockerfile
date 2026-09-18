FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/p9labs-io/llm-sandbox"

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

# Terraform, verified the same way as the Claude image does: HashiCorp signs the
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

RUN useradd -m -s /bin/bash antigravity
USER antigravity
ENV PATH="/home/antigravity/.local/bin:${PATH}"

RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

RUN mkdir -p /home/antigravity/.gemini/antigravity-cli

# Fallback defaults for `docker run` without a mounted config directory. When the
# Makefile mounts ~/.llm-sandbox/antigravity over this path the bind mount hides
# this file, so the Makefile seeds the same defaults on the host side.
COPY --chown=antigravity:antigravity settings.json /home/antigravity/.gemini/antigravity-cli/settings.json

WORKDIR /workspace

ENTRYPOINT ["agy"]
