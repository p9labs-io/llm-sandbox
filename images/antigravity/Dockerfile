FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/p9labs-io/llm-sandbox"

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash antigravity
USER antigravity
ENV PATH="/home/antigravity/.local/bin:${PATH}"

# Unlike Claude Code, Antigravity publishes no signed release manifest, so this
# install is trust-on-first-use. --skip-aliases/--skip-path keep the installer out
# of the shell profile; the ENV PATH above is what makes `agy` resolvable.
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- --skip-aliases --skip-path

RUN mkdir -p /home/antigravity/.gemini/antigravity-cli

# Fallback defaults for `docker run` without a mounted config directory. When the
# Makefile mounts ~/.llm-sandbox/antigravity over this path the bind mount hides
# this file, so the Makefile seeds the same defaults on the host side.
COPY --chown=antigravity:antigravity settings.json /home/antigravity/.gemini/antigravity-cli/settings.json

WORKDIR /workspace

ENTRYPOINT ["agy"]
