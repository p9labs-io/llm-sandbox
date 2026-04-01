FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash claude
USER claude
ENV PATH="/home/claude/.local/bin:${PATH}"

RUN curl -fsSL https://claude.ai/install.sh | bash

WORKDIR /workspace

ENTRYPOINT ["claude"]