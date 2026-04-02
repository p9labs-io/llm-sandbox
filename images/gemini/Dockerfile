FROM node:20-slim

RUN npm install -g @google/gemini-cli \
    && npm cache clean --force

USER node

RUN mkdir -p /home/node/.gemini/policies
COPY --chown=node:node settings.json /home/node/.gemini/settings.json
COPY --chown=node:node no-search.toml /home/node/.gemini/policies/no-search.toml

WORKDIR /workspace

ENTRYPOINT ["gemini"]