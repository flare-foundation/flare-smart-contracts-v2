FROM node:24 AS deps

WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml .npmrc /app/

RUN pnpm install --frozen-lockfile

FROM node:24 AS builder

WORKDIR /app

RUN corepack enable

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN pnpm c

CMD ["bash"]
