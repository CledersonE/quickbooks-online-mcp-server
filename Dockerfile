# syntax=docker/dockerfile:1
# Hardened image for the QuickBooks Online MCP server (added by fork; not upstream).
# Multi-stage: build TS in a full env, ship only prod deps + dist as non-root.

# ---- build: compile TypeScript ----
FROM node:22-bookworm-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
# install full deps (incl. typescript/shx); skip lifecycle scripts (prepare) until source is present
RUN npm ci --ignore-scripts
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# ---- runtime: prod deps only, non-root ----
FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force
COPY --from=build /app/dist ./dist
# the node:22 base image ships a non-root `node` user (uid/gid 1000)
USER node
# MCP server entrypoint (dist/index.js per package.json "bin"/"main").
CMD ["node", "dist/index.js"]
