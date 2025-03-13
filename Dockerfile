FROM node:18 AS deps

WORKDIR /app

COPY package.json yarn.lock /app

RUN yarn --frozen-lockfile

FROM node:18 AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN yarn c

CMD ["bash"]
