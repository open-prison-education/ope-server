# Immutable Canvas LMS image. Source and dependencies are pinned.
# Build on a connected builder, then export the image for air-gapped hosts.
# Runtime does not clone, install, or patch source.
ARG RUBY_IMAGE=ruby:3.4.1-bookworm@sha256:24d87689bd5c1821388b9fa2fcfd743938f1baa5c4ceffcd34bdc9633113fe38
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
    QTI_COMMIT=aab28af7a05142140c6fd2f45ed67a4c925a7d1b

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      libxmlsec1-dev python3 python-is-python3 libicu-dev libidn11-dev \
      parallel postgresql-client-16 tzdata unzip pbzip2 git build-essential \
      libpq-dev libxml2-dev libxslt1-dev libyaml-dev imagemagick libmagickwand-dev \
      shared-mime-info curl ca-certificates xz-utils python3-lxml \
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
    && chown -R canvas:canvas "$APP_HOME"

USER canvas
RUN bundle config set --local build.nokogiri --use-system-libraries \
    && bundle config set --local build.ffi --enable-system-libffi \
    && bundle install --jobs "$(nproc)" \
    && python3 /tmp/apply_ope_patches.py "$APP_HOME" "$(bundle show switchman)" \
    && yarn install --frozen-lockfile \
    && COMPILE_ASSETS_BRAND_CONFIGS=0 COMPILE_ASSETS_NPM_INSTALL=0 bin/rails canvas:compile_assets --trace \
    && rm -rf node_modules tmp/cache /usr/local/bundle/cache

USER root
RUN rm -f /tmp/apply_ope_patches.py
USER canvas

EXPOSE 3000
CMD ["/usr/local/bin/canvas-web.sh"]
