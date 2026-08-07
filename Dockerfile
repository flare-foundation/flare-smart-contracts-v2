FROM node:24 AS deps

# checkov:skip=CKV_DOCKER_2:Build-only image - it compiles the contracts and exits, there is no
# long-running process for a healthcheck to probe.
# checkov:skip=CKV_DOCKER_3:Build-only image - never network-exposed, and `pnpm compile` writes into
# /app, which is created and owned by root. Same waiver as .devcontainer/Dockerfile.

WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml .npmrc /app/

RUN pnpm install --frozen-lockfile

FROM node:24 AS builder

WORKDIR /app

RUN corepack enable

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN pnpm compile

CMD ["bash"]
