# Immutable Canvas LMS image. Source and dependencies are pinned.
# Build on a connected builder, then export the image for air-gapped hosts.
ARG RUBY_IMAGE=ruby:3.4.1-bookworm
FROM ${RUBY_IMAGE}

ENV RAILS_ENV=production \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    RAILS_LOAD_ALL_LOCALES=1 \
    CANVAS_RAILS=8.0 \
    APP_HOME=/usr/src/app \
    NODE_VERSION=20.9.0 \
    NODE_TARBALL_SHA256=9033989810bf86220ae46b1381bdcdc6c83a0294869ba2ad39e1061f1e69217a \
    BUNDLER_VERSION=2.6.7 \
    CANVAS_COMMIT=44bfdc264d5fe6a942ebdb5f10a0eb63ee04df3a \
    QTI_COMMIT=aab28af7a05142140c6fd2f45ed67a4c925a7d1b \
    PGDG_KEY_SHA256=0144068502a1eddd2a0280ede10ef607d1ec592ce819940991203941564e8e76

# Bookworm's own archive has postgresql-client-15 only. Client 16, matching the
# PostgreSQL 16 server, comes from the PGDG apt repository. libpq-dev is taken
# from that same repository.
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && install -d /usr/share/postgresql-common/pgdg \
    && curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "${PGDG_KEY_SHA256}  /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc" | sha256sum -c - \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends \
      libxmlsec1-dev python3 python-is-python3 libicu-dev libidn11-dev \
      parallel postgresql-client-16 tzdata unzip pbzip2 git build-essential \
      libpq-dev libxml2-dev libxslt1-dev libyaml-dev imagemagick libmagickwand-dev \
      shared-mime-info xz-utils python3-lxml \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz \
    && echo "${NODE_TARBALL_SHA256}  /tmp/node.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm -f /tmp/node.tar.xz \
    && npm install -g npm@9.8.1 \
    && corepack enable && corepack prepare yarn@1.19.1 --activate \
    && gem install bundler -v "$BUNDLER_VERSION" --no-document \
    && groupadd --gid 9999 canvas && useradd --uid 9999 --gid canvas --create-home canvas

WORKDIR $APP_HOME

# Fetch happens at image-build time on the connected builder.
RUN git clone --depth 1 https://github.com/instructure/canvas-lms.git "$APP_HOME" \
    && git -C "$APP_HOME" fetch --depth 1 origin "$CANVAS_COMMIT" \
    && git -C "$APP_HOME" checkout --detach "$CANVAS_COMMIT" \
    && git clone --depth 1 https://github.com/instructure/QTIMigrationTool.git "$APP_HOME/vendor/QTIMigrationTool" \
    && git -C "$APP_HOME/vendor/QTIMigrationTool" fetch --depth 1 origin "$QTI_COMMIT" \
    && git -C "$APP_HOME/vendor/QTIMigrationTool" checkout --detach "$QTI_COMMIT" \
    && chmod +x "$APP_HOME/vendor/QTIMigrationTool/migrate.py"

COPY patches/apply_ope_patches.py /tmp/apply_ope_patches.py
COPY ope.rake lib/tasks/ope.rake
COPY fonts/ public/fonts/
COPY ajax/ public/ajax/
COPY ViewerJS/ public/vendor/ViewerJS/
COPY bin/canvas-web.sh bin/canvas-jobs.sh bin/canvas-migrate.sh /usr/local/bin/

RUN python3 /tmp/apply_ope_patches.py "$APP_HOME" \
    && find . \( -name '*.html' -o -name '*.css' -o -name '*.erb' -o -name '*.js' \) -type f -print0 \
      | xargs -0 sed -i \
        -e 's#https://fonts.googleapis.com/css#/fonts/css.css#g' \
        -e 's#/fonts/css.css2#/fonts/css.css#g' \
        -e 's#//cdnjs.cloudflare.com##g' \
    && chmod 755 /usr/local/bin/canvas-*.sh \
    && mkdir -p tmp/files log tmp/pids \
    && chown -R canvas:canvas "$APP_HOME" /usr/local/bundle

USER canvas
RUN bundle config set --local build.nokogiri --use-system-libraries \
    && bundle config set --local build.ffi --enable-system-libffi \
    && bundle install --jobs "$(nproc)" \
    && python3 /tmp/apply_ope_patches.py "$APP_HOME" "$(bundle show switchman)" \
    && yarn install --frozen-lockfile

COPY patches/silence_sass.js /tmp/silence-sass.js

# One asset task at a time. Production rspack plus CSS, styleguide, and API
# docs together exhaust this builder. Compile output stays in a file so Sass
# warnings cannot fill the BuildKit log and hide the real failure.
# This Canvas commit imports @instructure/platform-alerts and omits it from package.json.
RUN yarn add @instructure/platform-alerts@0.2.0 --ignore-scripts -W \
    && NODE_OPTIONS="--max-old-space-size=4096 --require /tmp/silence-sass.js" \
      CANVAS_BUILD_CONCURRENCY=1 \
      COMPILE_ASSETS_API_DOCS=0 \
      COMPILE_ASSETS_BRAND_CONFIGS=0 \
      COMPILE_ASSETS_NPM_INSTALL=0 \
      COMPILE_ASSETS_STYLEGUIDE=0 \
      SKIP_SOURCEMAPS=1 \
      bin/rails canvas:compile_assets --trace > /tmp/canvas-compile.log 2>&1 & \
    compile_pid=$!; \
    while kill -0 "$compile_pid" 2>/dev/null; do \
      echo "canvas assets still compiling ($(wc -l < /tmp/canvas-compile.log) log lines)"; \
      sleep 20; \
    done; \
    wait "$compile_pid" \
    || { echo '----- canvas compile log tail -----'; tail -n 200 /tmp/canvas-compile.log; exit 1; } \
    && rm -rf node_modules tmp/cache /usr/local/bundle/cache /tmp/canvas-compile.log

USER root
RUN rm -f /tmp/apply_ope_patches.py /tmp/silence-sass.js
USER canvas

EXPOSE 3000
CMD ["/usr/local/bin/canvas-web.sh"]
