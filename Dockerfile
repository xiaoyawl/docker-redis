FROM benyoo/alpine:3.4.20160812
MAINTAINER from www.dwhd.org by lookback (mondeolove@gmail.com)

ENV VERSION=3.2.3
ENV DOWN_URL=http://download.redis.io/releases/redis-${VERSION}.tar.gz \
	SHA256=674e9c38472e96491b7d4f7b42c38b71b5acbca945856e209cb428fbc6135f15 \
	TEMP_DIR=/tmp/redis

RUN set -x && \
	FILE_NAME=${DOWN_URL##*/} && \
	mkdir -p ${TEMP_DIR} /data && cd ${TEMP_DIR} && \
	apk --update --no-cache upgrade && \
# grab su-exec for easy step-down from root
	apk add --no-cache 'su-exec>=0.2' && \
	apk add --no-cache --virtual .build-deps gcc linux-headers make musl-dev tar && \
	addgroup -S redis && adduser -S -h /data/redis -s /sbin/nologin -G redis redis && \
	curl -Lk ${DOWN_URL} |tar xz -C ${TEMP_DIR} --strip-components=1 && \
	#{ while :;do \
	#	curl -Lk ${DOWN_URL} -o ${TEMP_DIR}/${FILE_NAME} && { \
	#		[ "$(sha256sum ${TEMP_DIR}/${FILE_NAME}|awk '{print $1}')" == "${SHA256}" ] && break; \
	#	}; \
	#done; } && \
	#cd ${FILE_NAME%.tar*} && \
	make -C ${TEMP_DIR} && \
	make -C ${TEMP_DIR} install && \
	apk del .build-deps tar gcc make && \
	rm -rf /var/cache/apk/* ${TEMP_DIR}

COPY entrypoint.sh /usr/entrypoint.sh
RUN chmod +x /usr/entrypoint.sh

VOLUME ["/data"]
WORKDIR /data

EXPOSE 6379/tcp

ENTRYPOINT ["/entrypoint.sh"]

CMD ["redis-server"]
