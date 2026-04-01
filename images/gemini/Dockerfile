FROM node:20-slim

RUN npm install -g @google/gemini-cli \
    && npm cache clean --force

USER node

WORKDIR /workspace

ENTRYPOINT ["gemini"]