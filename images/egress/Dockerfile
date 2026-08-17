FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/p9labs-io/llm-sandbox"

RUN apt-get update && apt-get install -y --no-install-recommends \
    tinyproxy \
    && rm -rf /var/lib/apt/lists/*

COPY tinyproxy.conf /etc/tinyproxy/tinyproxy.conf
COPY allowlist      /etc/tinyproxy/allowlist

# Starts as root only so tinyproxy can drop to the unprivileged `tinyproxy` user
# (see User/Group in tinyproxy.conf). Run the container with
# --cap-drop=ALL --cap-add=SETUID --cap-add=SETGID --security-opt=no-new-privileges.
# This container holds no credentials and mounts nothing.
EXPOSE 8888

ENTRYPOINT ["tinyproxy", "-d", "-c", "/etc/tinyproxy/tinyproxy.conf"]
