#FROM benyoo/centos:7.2.1511.20160630
FROM benyoo/centos-core:7.2.1511.20160706
MAINTAINER from www.dwhd.org by lookback (mondeolove@gmail.com)

ARG REDIS_VERSION=${REDIS_VERSION:-3.2.1}
ARG REDIS_TAR_SHA256=${REDIS_TAR_SHA256:-26c0fc282369121b4e278523fce122910b65fbbf}

RUN \
	DOWN_URL="http://download.redis.io/releases" && \
	DOWN_URL="${DOWN_URL}/redis-${REDIS_VERSION}.tar.gz" && \
	REDIS_FILE=${DOWN_URL##*/} && \
	mkdir /tmp/redis && \
	cd /tmp/redis && \
	{ while :;do curl -Lk ${DOWN_URL} -o /tmp/redis/${FILE_NAME} && { [ "$(sha256sum /tmp/redis/${FILE_NAME}|awk '{print $1}')" == "${REDIS_TAR_SHA256}" ] && break; }; done; } && \
	curl -Lk "$REDIS_DOWNLOAD_URL" -o ${REDIS_DOWNLOAD_URL##*/} && \
	tar xf ${REDIS_DOWNLOAD_URL##*/} && \
	cd ${REDIS_FILE%.tar*} && \
	yum install epel-release -y && \
	#sed -i 's@mirrorlist@#&@;s@#baseurl=http://mirror.centos.org@baseurl=http://mirrors.ds.com@' /etc/yum.repos.d/CentOS-Base.repo && \
	#sed -i 's@mirrorlist@#&@;s@#baseurl=http://download.fedoraproject.org/pub@baseurl=http://mirrors.ds.com@' /etc/yum.repos.d/epel.repo && \
	yum install jemalloc-devel gcc make -y && \
	make -j $(awk '/processor/{i++}END{print i}' /proc/cpuinfo) && \
	mkdir -p /usr/local/redis/{bin,etc,var} && \
	cp -af src/{redis-benchmark,redis-check-aof,redis-check-rdb,redis-cli,redis-sentinel,redis-server} /usr/local/redis/bin/ && \
	cp -a redis.conf /usr/local/redis/etc/ && \
	echo "export PATH=/usr/local/redis/bin:\$PATH" > /etc/profile.d/redis.sh && \
	source /etc/profile.d/redis.sh && \
	useradd -r -s /sbin/nologin -c "Redis Server" -d /data -m -k no redis && \
	yum clean all && \
	rm -rf /tmp/redis

COPY entrypoint.sh /usr/local/redis/bin/entrypoint.sh
RUN chmod +x /usr/local/redis/bin/entrypoint.sh
ENV PATH=/usr/local/redis/bin:$PATH

VOLUME ["/data"]
WORKDIR /data

EXPOSE 6379/tcp

ENTRYPOINT ["entrypoint.sh"]

CMD ["redis-server"]
