FROM node:20-slim

RUN npm install -g @google/gemini-cli \
    && npm cache clean --force

WORKDIR /workspace

ENTRYPOINT ["gemini"]