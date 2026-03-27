ARG BASE_IMAGE=benyoo/alpine:3.21.20260327
FROM ${BASE_IMAGE}
LABEL maintainer="from www.dwhd.org by lookback (mondeolove@gmail.com)"

ARG REDIS_VERSION=7.2.11
ENV TEMP_DIR=/tmp/redis \
    DATA_DIR=/data/redis

RUN set -eux; \
    [ -n "${REDIS_VERSION}" ]; \
    DOWN_URL="https://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz"; \
    mkdir -p "${TEMP_DIR}" "${DATA_DIR}"; \
    apk add --no-cache bash 'su-exec>=0.2'; \
    apk add --no-cache --virtual .build-deps curl gcc linux-headers make musl-dev tar; \
    addgroup -S redis; \
    adduser -S -h "${DATA_DIR}" -s /sbin/nologin -G redis redis; \
    curl -fsSL "${DOWN_URL}" | tar -xz -C "${TEMP_DIR}" --strip-components=1; \
    make -C "${TEMP_DIR}" -j"$(getconf _NPROCESSORS_ONLN)"; \
    make -C "${TEMP_DIR}" install; \
    rm -rf "${TEMP_DIR}"; \
    apk del .build-deps; \
    chown -R redis:redis "${DATA_DIR}"

COPY entrypoint.sh /entrypoint.sh
COPY redis.conf /etc/redis.conf
RUN chmod +x /entrypoint.sh

VOLUME /data/redis
WORKDIR /data/redis

EXPOSE 6379/tcp
STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]
CMD ["redis-server", "/etc/redis.conf"]
