FROM node:20-slim

RUN npm install -g @google/gemini-cli \
    && npm cache clean --force

USER node

RUN mkdir -p /home/node/.gemini && \
    echo '{"selectedAuthType":"gemini-api-key"}' > /home/node/.gemini/settings.json

WORKDIR /workspace

ENTRYPOINT ["gemini"]