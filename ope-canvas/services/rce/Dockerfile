ARG NODE_VERSION=20.9.0
ARG NODE_TARBALL_SHA256=9033989810bf86220ae46b1381bdcdc6c83a0294869ba2ad39e1061f1e69217a
FROM debian:bookworm-slim

ENV NODE_VERSION=${NODE_VERSION} \
    RCE_COMMIT=d702ab3bd201cc3bad19abd32cec22e7fd9e1701 \
    NODE_ENV=production \
    PORT=3010

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      curl ca-certificates xz-utils git \
    && curl -fsSL "https://nodejs.org/dist/v20.9.0/node-v20.9.0-linux-x64.tar.xz" -o /tmp/node.tar.xz \
    && echo "9033989810bf86220ae46b1381bdcdc6c83a0294869ba2ad39e1061f1e69217a  /tmp/node.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && npm install -g npm@9.8.1 \
    && rm -rf /var/lib/apt/lists/* /tmp/node.tar.xz \
    && groupadd --gid 9999 canvas && useradd --uid 9999 --gid canvas --create-home canvas

WORKDIR /usr/src/rce
RUN git clone --depth 1 https://github.com/instructure/canvas-rce-api.git . \
    && git fetch --depth 1 origin "$RCE_COMMIT" \
    && git checkout --detach "$RCE_COMMIT"

COPY packageBookmark.js app/api/packageBookmark.js
COPY start.sh /usr/src/start.sh
RUN npm ci --omit=dev \
    && chmod 755 /usr/src/start.sh \
    && chown -R canvas:canvas /usr/src/rce /usr/src/start.sh

USER canvas
EXPOSE 3010
CMD ["node", "app.js"]
