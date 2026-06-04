FROM node:24-bookworm AS builder
LABEL description="FreeCodeCamp - Image for Open Prison Education"
LABEL version="2.0"

RUN apt-get update && apt-get install -y git jq && rm -rf /var/lib/apt/lists/*
RUN npm i -g pnpm@10

USER node
WORKDIR /home/node/build

RUN git clone --depth 1 https://github.com/freeCodeCamp/freeCodeCamp.git .
RUN cp sample.env .env

RUN pnpm config set dedupe-peer-dependents false
RUN pnpm install --frozen-lockfile --ignore-scripts
RUN cd api && pnpm prisma generate

ARG SHOW_UPCOMING_CHANGES=false
ENV SHOW_UPCOMING_CHANGES=$SHOW_UPCOMING_CHANGES
ARG CURRICULUM_LOCALE=english
ENV CURRICULUM_LOCALE=$CURRICULUM_LOCALE

RUN pnpm turbo -F=@freecodecamp/api build

# --- Production dependencies stage ---
FROM node:24-bookworm AS deps

RUN apt-get update && apt-get install -y jq && rm -rf /var/lib/apt/lists/*
RUN npm i -g pnpm@10

USER node
WORKDIR /home/node/build

COPY --from=builder --chown=node:node /home/node/build/pnpm*.yaml .
COPY --from=builder --chown=node:node /home/node/build/package.json .
COPY --from=builder --chown=node:node /home/node/build/api/ api/
COPY --from=builder --chown=node:node /home/node/build/packages/ packages/

RUN pnpm config set dedupe-peer-dependents false
RUN pnpm install --prod --ignore-scripts -F=api -F=packages/shared --frozen-lockfile
RUN cd api && npx prisma@$(jq -r '.devDependencies.prisma' < package.json) generate

# --- Final runtime stage ---
FROM node:24-bookworm

USER node
WORKDIR /home/node/fcc

COPY --from=builder --chown=node:node /home/node/build/api/dist/ ./
COPY --from=builder --chown=node:node /home/node/build/api/package.json api/
COPY --from=builder --chown=node:node /home/node/build/curriculum/generated/curriculum.json curriculum/generated/
COPY --from=builder --chown=node:node /home/node/build/packages/ packages/

COPY --from=deps --chown=node:node /home/node/build/node_modules/ node_modules/
COPY --from=deps --chown=node:node /home/node/build/api/node_modules/ api/node_modules/

COPY sample.env .env

EXPOSE 3000

CMD ["node", "api/src/server.js"]
