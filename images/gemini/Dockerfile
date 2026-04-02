FROM node:20-slim

RUN npm install -g @google/gemini-cli \
    && npm cache clean --force

USER node

RUN mkdir -p /home/node/.gemini
COPY --chown=node:node settings.json /home/node/.gemini/settings.json

WORKDIR /workspace

ENTRYPOINT ["gemini"]