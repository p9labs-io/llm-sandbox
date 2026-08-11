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

RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

# Create config directory and add settings.json
RUN mkdir -p /home/antigravity/.gemini/antigravity-cli
COPY --chown=antigravity:antigravity settings.json /home/antigravity/.gemini/antigravity-cli/settings.json

WORKDIR /workspace

ENTRYPOINT ["agy"]