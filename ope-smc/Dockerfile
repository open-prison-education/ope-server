FROM alpine:3.18
LABEL description="Student Management Console - Image for Open Prison Education"
LABEL version="1.9"

LABEL rebuild=1
# install base
RUN apk update  \
    && apk add --update --no-cache \
        bash musl musl-dev linux-headers pcre-dev coreutils build-base nasm ca-certificates curl tar \
        libc-dev zlib-dev yasm-dev lame-dev lame-libs freetype-dev opus-dev \
        rtmpdump-dev x264-dev x265-dev xvidcore-dev libass-dev libwebp-dev \
        libvorbis-dev libogg-dev libtheora-dev libvpx-dev \
        python3 python3-dev py3-pip mysql-client libxml2-dev \
        py3-cairo py3-cairo-dev py3-cffi \
        unzip wget net-tools git git-daemon unzip \
        openssl openssl-dev zip postgresql-dev openldap-dev \
        supervisor libffi-dev pcre  libxml2 libxslt-dev cargo \
        jpeg-dev zlib-dev libffi-dev cairo-dev pango-dev gdk-pixbuf-dev \
        font-noto msttcorefonts-installer fontconfig nano \
    && update-ms-fonts \
    && fc-cache -f \
    && python -m pip install --upgrade pip \
    && python -m pip install --upgrade 'setuptools < 82' ldap3 pycryptodome requests \
        paramiko ecdsa isodate pywinrm crypto PyMySQL \
        psycopg2-binary uwsgi uwsgitop psutil redis pycanvas lz4 \ 
        webvtt-py langcodes language_data bs4 lxml openpyxl Pillow WeasyPrint uwsgitop pydantic pylti1p3
RUN FFMPEG_VER=8.0.2 \ 
    && curl -s https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VER}.tar.gz | tar zxvf - -C . \
    && cd ffmpeg-${FFMPEG_VER} \
    && ./configure \
        --disable-debug --enable-version3 --enable-small --enable-gpl \
        --enable-nonfree --enable-openssl \
        --enable-libfreetype --enable-libmp3lame \
        --enable-libx264 --enable-libx265 --enable-libopus --enable-libass \
        --enable-libwebp --enable-librtmp --enable-libtheora \
        --enable-libvorbis --enable-libvpx --enable-libxvid \
    && make -j"$(nproc)" install \
    && cd .. \
    && rm -rf ffmpeg-${FFMPEG_VER} \
    && apk del --purge \
        musl-dev linux-headers pcre-dev coreutils build-base nasm curl tar openssl-dev zlib-dev yasm-dev \
        lame-dev freetype-dev opus-dev xvidcore-dev libass-dev libwebp-dev \
        libvorbis-dev libogg-dev libtheora-dev libvpx-dev \
        python3-dev \
    && apk add --no-cache \
        zlib lame lame-libs freetype faac opus xvidcore libass libwebp libvorbis libogg \
        libtheora libvpx \
    && rm -rf /var/cache/apk/* \
    && echo "FFMPEG Build complete"


LABEL REBUILD_PYTUBE=2
LABEL yt_dlp=1.0
RUN python -m pip install --upgrade yt_dlp
RUN python -m pip install --upgrade pytubefix

# Set ENV Vars
ENV IT_PW changeme
ENV OFFICE_PW changeme
ENV INSTALL_DIR /home/www-data
ENV W2P_DIR $INSTALL_DIR/smc

WORKDIR $INSTALL_DIR

USER root

RUN mkdir $W2P_DIR \
    && mkdir $INSTALL_DIR/git

# Setup users
RUN addgroup www-data; exit 0
RUN adduser -D -H -s /bin/bash git \
      && adduser -D -s /bin/bash -G www-data www-data


WORKDIR $W2P_DIR


# New clone smc which includes web2py already
LABEL rebuild_smc=12

ENV SMC_RELEASE 26.5.12.0

RUN cd $W2P_DIR \
    && git config --global --add safe.directory /home/www-data/smc \
    && git init \
    && git remote add origin https://github.com/operepo/smc \
    && git fetch origin --no-tags --depth 1 refs/tags/${SMC_RELEASE}:refs/tags/${SMC_RELEASE}  \
    && git checkout ${SMC_RELEASE}

RUN cd $W2P_DIR \
    && echo "${SMC_RELEASE}" > web2py/applications/smc/app_version.txt



# Copy our files in
LABEL rebuild=26
COPY set_admin_password /bin/set_admin_password
COPY start.sh /start.sh
COPY supervisord.conf /etc/supervisor/supervisord.conf
RUN chmod +x /start.sh \
     && chown -R www-data:www-data $W2P_DIR \
     && chown -R git:git $INSTALL_DIR/git \
     && chmod +x /bin/set_admin_password

ENV USER=www-data

VOLUME ["/home/www-data/git", "/home/www-data/smc/web2py/applications/smc/cache", \
 "/home/www-data/smc/web2py/applications/smc/databases", \
 "/home/www-data/smc/web2py/applications/smc/errors", \
 "/home/www-data/smc/web2py/applications/smc/private", \
 "/home/www-data/smc/web2py/applications/smc/static/media", \
 "/home/www-data/smc/web2py/applications/smc/uploads", \
 "/home/www-data/smc/web2py/applications/smc/sessions", \
 "/home/www-data/smc/web2py/applications/data_sync/static/blocks" \
 ]

EXPOSE 8000 9418

ENTRYPOINT ["/start.sh"]
