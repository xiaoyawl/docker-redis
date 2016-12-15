#!/bin/bash
#########################################################################
# File Name: entrypoint.sh
# Author: LookBack
# Email: admin#dwhd.org
# Version:
# Created Time: 2016年06月30日 星期四 19时38分40秒
#########################################################################

set -e

DEFAULT_CONF=${DEFAULT_CONF:-enable}
REDIS_PASS=${REDIS_PASS:-$(date +"%s%N"| sha256sum | base64 | head -c 16)}
CONFIG_FILE=${CONFIG_FILE:-/etc/redis.conf}
SENTINEL_FILE=${SENTINEL_FILE:-/etc/sentinel.conf}
SUPERVISORCTL_NAME=${SUPERVISORCTL_NAME:-admin}
SUPERVISORCTL_PASS=${SUPERVISORCTL_PASS:-admin}

#Sentinel variable
S_PORT=${S_PORT:-26379}
S_BIND=${S_BIND:-0.0.0.0}
S_DATA=${S_DATA:-/data/redis}
S_AUTH_PASS=${S_AUTH_PASS:-dwhd}
S_MASTER_NAME=${S_MASTER_NAME:-master6379}
S_PIDFILE=${S_PIDFILE:-/var/run/sentinel6379.pid}
S_LOGFILE=${S_LOGFILE:-/var/log/sentinel6379.log}
S_MASTER_IP=${S_MASTER_IP:-127.0.0.1}
S_MASTER_PORT=${S_MASTER_PORT:-6379}
S_MASTER_QUORUM=${S_MASTER_QUORUM:-2}
S_FAILOVER_TIMEOUT=${S_FAILOVER_TIMEOUT:-3000}
S_DOWN_AFTER_MILLISECONDS=${S_DOWN_AFTER_MILLISECONDS:-3000}
S_RECONFIG_SCRIPT=${S_RECONFIG_SCRIPT:-disable}
S_CLIENT_RECONFIG_SCRIPT=${S_CLIENT_RECONFIG_SCRIPT:-/opt/notify_master6379.sh}

[ ! -d /var/log/supervisor ] && mkdir -p /var/log/supervisor
sed -ri "s/^(username).*/\1 = ${SUPERVISORCTL_NAME}/" /etc/supervisord.conf
sed -ri "s/^(password).*/\1 = ${SUPERVISORCTL_PASS}/" /etc/supervisord.conf

if [ "$(id -u)" = '0' ] && [[ $(sysctl -w net.core.somaxconn=8192) ]]; then
	sysctl -w vm.overcommit_memory=1
	echo never|tee /sys/kernel/mm/transparent_hugepage/{defrag,enabled}
fi

if [[ "$SENTINEL" =~ ^[eE][nN][aA][bB][lL][eE]$ ]]; then
	if  [[ ! -f ${SENTINEL_FILE} ]]; then
		cat > ${SENTINEL_FILE} <<-EOF
			port ${S_PORT}
			bind ${S_BIND}
			dir "${S_DATA}"
			pidfile "${S_PIDFILE}"
			logfile "${S_LOGFILE}"
			sentinel monitor ${S_MASTER_NAME} ${S_MASTER_IP} ${S_MASTER_PORT} ${S_MASTER_QUORUM}
			sentinel down-after-milliseconds ${S_MASTER_NAME} ${S_DOWN_AFTER_MILLISECONDS}
			sentinel failover-timeout ${S_MASTER_NAME} ${S_FAILOVER_TIMEOUT}
			sentinel auth-pass ${S_MASTER_NAME} ${S_AUTH_PASS}
		EOF
		if [[ "${S_RECONFIG_SCRIPT}" =~ ^[eE][nN][aA][bB][lL][eE]$ ]]; then
			if [ ! -f ${S_CLIENT_RECONFIG_SCRIPT} ]; then
				echo >&2 -e 'error:  \033[41;37;1mmissing sentinel configfile\033[39;49;0m'
				echo >&2 '  Did you forget to add a sentinel config file?'
				exit 1
			fi
			echo "sentinel client-reconfig-script ${S_MASTER_NAME} ${S_CLIENT_RECONFIG_SCRIPT}" >> ${SENTINEL_FILE}
			chmod +x ${S_CLIENT_RECONFIG_SCRIPT}
		fi
	fi

	cat >> /etc/supervisord.conf <<-EOF
		[program:redis-sentinel]
		command=/bin/bash -c "redis-server ${SENTINEL_FILE} --sentinel"
		autostart=true
		autorestart=false
		startretries=0
		stdout_events_enabled=true
		stderr_events_enabled=true
	EOF
fi

if [[ ${DEFAULT_CONF} =~ ^[eE][nN][aA][bB][lL][eE]$ ]]; then
	[[ -z $(grep '^requirepass' "$CONFIG_FILE") ]] && echo "requirepass ${REDIS_PASS}" >> $CONFIG_FILE
	echo -e "\033[45;37;1mRedis Server Auth Password : $(awk '/^requirepass/{print $NF}' $CONFIG_FILE)\033[39;49;0m"
fi

if [[ -n ${SUPERVISOR_PORT} ]]; then
	sed -i 's/^port.*/port = 0.0.0.0:${SUPERVISOR_PORT}/' /etc/supervisord.conf
fi

supervisord -n -c /etc/supervisord.conf
