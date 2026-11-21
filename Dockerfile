# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine-nginx:3.21

# set arguments
ARG BUILD_DATE
ARG BUILD_VERSION
ARG BUILD_REVISION
ARG APP_VERSION

# fingerprint of the signing key shipped at keys/roundcube-devs.asc;
# the build imports that file only and asserts this fingerprint,
# no network keyserver is contacted
ARG ROUNDCUBEMAIL_RELEASE_KEYID="F3E4C04BB3DB5D4215C45F7F5AB2BAA141C4F7D5"
ARG ROUNDCUBEMAIL_MEMORY_LIMIT="128M"
ARG ROUNDCUBEMAIL_UPLOAD_LIMIT="10M"
ARG ROUNDCUBEMAIL_POST_LIMIT="12M"
ARG SOURCE_REPO="roundcube/roundcubemail"

# layer 1: system packages and PHP extensions (stable across app version bumps)
RUN \
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
    php83-pspell

# layer 2: php-fpm env passthrough and runtime php tunables
RUN \
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
  } > /etc/php83/conf.d/roundcube-misc.ini

# layer 3: roundcube itself — the only layer that rebuilds on an app version bump
COPY keys/roundcube-devs.asc /tmp/roundcube-devs.asc
RUN \
  apk add --no-cache --virtual=build-dependencies gpg gpg-agent && \
  echo "**** assert pinned signing key fingerprint ****" && \
  key_fpr=$(gpg --batch --with-colons --import-options show-only --import /tmp/roundcube-devs.asc \
    | awk -F: '/^fpr:/ {print $10; exit}') && \
  if [ "${key_fpr}" != "${ROUNDCUBEMAIL_RELEASE_KEYID}" ]; then \
    echo "Signing key fingerprint mismatch: ${key_fpr}"; \
    exit 1; \
  fi && \
  export GNUPGHOME="$(mktemp -d)" && \
  gpg --batch -q --import /tmp/roundcube-devs.asc && \
  mkdir -p /app/www/src && \
  if [ -z ${APP_VERSION+x} ]; then \
    APP_VERSION=$(curl -fsSL "https://api.github.com/repos/${SOURCE_REPO}/releases" \
    | jq -r '.[] | select(.prerelease != true and .draft != true) | .tag_name' \
    | sort -rV | head -1); \
  fi && \
  echo "**** download roundcubemail v${APP_VERSION} ****" && \
  curl -fsSL --retry 3 --retry-connrefused -o \
    /tmp/roundcubemail.tar.gz -L \
    "https://github.com/${SOURCE_REPO}/releases/download/${APP_VERSION}/roundcubemail-${APP_VERSION}-complete.tar.gz" && \
  curl -fsSL --retry 3 --retry-connrefused -o \
    /tmp/roundcubemail.tar.gz.asc -L \
    "https://github.com/${SOURCE_REPO}/releases/download/${APP_VERSION}/roundcubemail-${APP_VERSION}-complete.tar.gz.asc" && \
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
    echo "   Roundcube Mail v${APP_VERSION}"; \
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
  org.opencontainers.image.description="[Roundcube Webmail](https://roundcube.net) is a browser-based multilingual IMAP client with an application-like user interface." \
  org.opencontainers.image.authors="Wu-Wu" \
  org.opencontainers.image.created="${BUILD_DATE}" \
  org.opencontainers.image.version="${BUILD_VERSION}" \
  org.opencontainers.image.ref.name="${BUILD_REVISION}" \
  org.opencontainers.image.revision="${BUILD_REVISION}" \
  org.opencontainers.image.licenses="GPL-3.0-only" \
  org.opencontainers.image.url="https://hub.docker.com/r/wuwux/roundcubemail" \
  org.opencontainers.image.source="https://github.com/Wu-Wu/docker-roundcubemail" \
  org.opencontainers.image.documentation="https://github.com/roundcube/roundcubemail/wiki" \
  org.opencontainers.image.vendor="Wu-Wu"
