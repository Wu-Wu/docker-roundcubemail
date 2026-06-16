# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine-nginx:3.23-1.28.3-r3_8.5.6-r0-ls30

# set arguments
ARG BUILD_DATE
ARG BUILD_VERSION
ARG BUILD_REV_ID
ARG ROUNDCUBEMAIL_VERSION

ARG ROUNDCUBEMAIL_RELEASE_KEYID="F3E4C04BB3DB5D4215C45F7F5AB2BAA141C4F7D5"
ARG ROUNDCUBEMAIL_MEMORY_LIMIT="128M"
ARG ROUNDCUBEMAIL_UPLOAD_LIMIT="10M"
ARG ROUNDCUBEMAIL_POST_LIMIT="12M"
ARG SOURCE_REPO="roundcube/roundcubemail"

RUN \
  apk add --no-cache --virtual=build-dependencies \
    gpg \
    gpg-agent \
    gnupg-dirmngr && \
  apk add --no-cache \
    aspell \
    aspell-en \
    aspell-ru \
    rsync \
    php83-dom \
    php83-intl \
    php83-pdo_pgsql \
    php83-pdo_mysql \
    php83-pdo_sqlite \
    php83-exif \
    php83-ldap \
    php83-gd \
    php83-opcache \
    php83-pecl-imagick \
    php83-pecl-redis \
    php83-zip \
    php83-pspell && \
  echo "**** configure php-fpm to pass env vars ****" && \
  sed -E -i 's/^;?clear_env ?=.*$/clear_env = no/g' /etc/php83/php-fpm.d/www.conf && \
  grep -qxF 'clear_env = no' /etc/php83/php-fpm.d/www.conf || echo 'clear_env = no' >> /etc/php83/php-fpm.d/www.conf && \
  echo "env[PATH] = /usr/local/bin:/usr/bin:/bin" >> /etc/php83/php-fpm.conf && \
  echo "**** setup php session ****" && \
  { \
    echo "session.auto_start=Off"; \
    echo "session.gc_maxlifetime=21600"; \
    echo "session.gc_divisor=500"; \
    echo "session.gc_probability=1"; \
  } > /etc/php83/conf.d/session-misc.ini; \
  echo "**** setup php limits ****" && \
  { \
    echo "memory_limit=${ROUNDCUBEMAIL_MEMORY_LIMIT}"; \
    echo "post_max_size=${ROUNDCUBEMAIL_POST_LIMIT}"; \
    echo "upload_max_filesize=${ROUNDCUBEMAIL_UPLOAD_LIMIT}"; \
  } > /etc/php83/conf.d/roundcube-limits.ini && \
  echo "**** setup php misc ****" && \
  { \
    echo "display_errors=Off"; \
    echo "log_errors=On"; \
    echo "zlib.output_compression=Off"; \
  } > /etc/php83/conf.d/roundcube-misc.ini && \
  echo "**** install roundcubemail ****" && \
  mkdir -p /app/www/src && \
  if [ -z ${ROUNDCUBEMAIL_VERSION+x} ]; then \
    ROUNDCUBEMAIL_VERSION=$(curl -sL "https://api.github.com/repos/${SOURCE_REPO}/releases" \
    | jq -r '.[] | select(.prerelease != true) | .tag_name' \
    | sort -rV | head -1); \
  fi && \
  echo "**** download roundcubemail v${ROUNDCUBEMAIL_VERSION} ****" && \
  curl -s -o \
    /tmp/roundcubemail.tar.gz -L \
    "https://github.com/${SOURCE_REPO}/releases/download/${ROUNDCUBEMAIL_VERSION}/roundcubemail-${ROUNDCUBEMAIL_VERSION}-complete.tar.gz" && \
  curl -s -o \
    /tmp/roundcubemail.tar.gz.asc -L \
    "https://github.com/${SOURCE_REPO}/releases/download/${ROUNDCUBEMAIL_VERSION}/roundcubemail-${ROUNDCUBEMAIL_VERSION}-complete.tar.gz.asc" && \
  export GNUPGHOME="$(mktemp -d)" && \
  gpg --batch -q --keyserver keyserver.ubuntu.com --recv-keys "${ROUNDCUBEMAIL_RELEASE_KEYID}" \
    || gpg --batch -q --keyserver pgp.mit.edu --recv-keys "${ROUNDCUBEMAIL_RELEASE_KEYID}" \
    || gpg --batch -q --keyserver keyserver.pgp.com --recv-keys "${ROUNDCUBEMAIL_RELEASE_KEYID}" \
    || gpg --batch -q --keyserver keys.openpgp.org --recv-keys "${ROUNDCUBEMAIL_RELEASE_KEYID}" && \
  if ! gpg --batch -q --verify "/tmp/roundcubemail.tar.gz.asc" "/tmp/roundcubemail.tar.gz"; then \
    echo "File signature mismatch"; \
    exit 1; \
  fi && \
  tar xf \
    /tmp/roundcubemail.tar.gz -C \
    /app/www/src/ --strip-components=1 && \
  echo "**** create root config ****" && \
  { \
    echo "<?php"; \
    echo ""; \
    echo "/*"; \
    echo "   Roundcube Mail v${ROUNDCUBEMAIL_VERSION}"; \
    echo "   Build-version: ${BUILD_VERSION}"; \
    echo "   Build-date: ${BUILD_DATE}"; \
    echo "*/"; \
    echo ""; \
    echo "\$config = [];"; \
    echo ""; \
    echo "include('/config/roundcubemail/config.inc.php');"; \
    echo ""; \
  } > /app/www/src/config/config.inc.php && \
  printf "Build-version: ${BUILD_VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/* \
    /app/www/src/installer

COPY rootfs/ /

VOLUME /config
VOLUME /data

LABEL \
  org.opencontainers.image.title="docker-roundcubemail" \
  org.opencontainers.image.description="Roundcube Webmail" \
  org.opencontainers.image.authors="Wu-Wu" \
  org.opencontainers.image.created="${BUILD_DATE}" \
  org.opencontainers.image.version="${BUILD_VERSION}"\
  org.opencontainers.image.ref.name="${BUILD_REV_ID}" \
  org.opencontainers.image.revision="${BUILD_REV_ID}" \
  org.opencontainers.image.url="" \
  org.opencontainers.image.source="" \
  org.opencontainers.image.documentation="" \
  org.opencontainers.image.vendor=""
