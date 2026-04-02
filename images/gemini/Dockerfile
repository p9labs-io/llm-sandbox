FROM node:20-slim

RUN npm install -g @google/gemini-cli \
    && npm cache clean --force

USER node

RUN mkdir -p /home/node/.gemini && \
    echo '{"security":{"auth":{"selectedType":"gemini-api-key"}},"excludeTools":["google_web_search"]}' \
    > /home/node/.gemini/settings.json

WORKDIR /workspace

ENTRYPOINT ["gemini"]