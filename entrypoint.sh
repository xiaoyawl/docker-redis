#!/bin/bash
#########################################################################
# File Name: entrypoint.sh
# Author: LookBack
# Email: admin#dwhd.org
# Version:
# Created Time: 2026年03月25日14:45:14
#########################################################################

set -Eeuo pipefail

DATA_DIR="${DATA_DIR:-/data/redis}"
CONFIG_FILE="${CONFIG_FILE:-/etc/redis.conf}"
DEFAULT_CONF="${DEFAULT_CONF:-enable}"
ENABLE_KERNEL_TUNING="${ENABLE_KERNEL_TUNING:-auto}"

log() {
    echo "[entrypoint] $*"
}

is_disabled() {
    local val="${1:-}"
    [[ "${val}" =~ ^([dD][iI][sS][aA][bB][lL][eE]|0|[fF][aA][lL][sS][eE]|[nN][oO])$ ]]
}

is_auto_password() {
    local val="${1:-}"
    [[ "${val}" =~ ^[aA][uU][tT][oO]$ ]]
}

generate_auto_password() {
    local charset='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local pass=""
    local i idx
    for ((i=0; i<24; i++)); do
        idx=$((RANDOM % ${#charset}))
        pass+="${charset:${idx}:1}"
    done
    printf "%s" "${pass}"
}

has_requirepass_arg() {
    local prev=""
    local arg
    for arg in "$@"; do
        if [ "${prev}" = "--requirepass" ] && [ -n "${arg}" ]; then
            return 0
        fi
        prev="${arg}"
    done
    return 1
}

kernel_tuning() {
    if is_disabled "${ENABLE_KERNEL_TUNING}"; then
        return 0
    fi

    sysctl -w net.core.somaxconn=8192 >/dev/null 2>&1 || log "跳过 net.core.somaxconn 调优（权限不足或平台不支持）"
    sysctl -w vm.overcommit_memory=1 >/dev/null 2>&1 || log "跳过 vm.overcommit_memory 调优（权限不足或平台不支持）"

    if [ -w /sys/kernel/mm/transparent_hugepage/enabled ]; then
        echo never > /sys/kernel/mm/transparent_hugepage/enabled || true
    fi
    if [ -w /sys/kernel/mm/transparent_hugepage/defrag ]; then
        echo never > /sys/kernel/mm/transparent_hugepage/defrag || true
    fi
}

# 兼容空参数、参数模式启动和直接传入配置文件启动。
if [ "$#" -eq 0 ]; then
    set -- redis-server "${CONFIG_FILE}"
elif [ "${1#-}" != "$1" ] || [ "${1%.conf}" != "$1" ]; then
    set -- redis-server "$@"
fi

# 如果仅传了 redis-server 或第二个参数是选项，则补默认配置文件。
if [ "$1" = "redis-server" ] && { [ "$#" -eq 1 ] || [[ "${2:-}" == -* ]]; }; then
    set -- redis-server "${CONFIG_FILE}" "${@:2}"
fi

# root 启动时先准备权限和内核参数，再降权运行。
if [ "$1" = "redis-server" ] && [ "$(id -u)" = "0" ]; then
    runtime_config="${2:-${CONFIG_FILE}}"
    mkdir -p "${DATA_DIR}"
    chown -R redis:redis "${DATA_DIR}" || true
    [ -f "${runtime_config}" ] && chown redis:redis "${runtime_config}" || true
    kernel_tuning
    exec su-exec redis "$0" "$@"
fi

if [ "$1" = "redis-server" ]; then
    config_file="${2:-${CONFIG_FILE}}"
    if [ -f "${config_file}" ] && ! is_disabled "${DEFAULT_CONF}" && ! has_requirepass_arg "$@"; then
        if ! grep -Eq '^[[:space:]]*requirepass[[:space:]]+' "${config_file}"; then
            if [ -n "${REDIS_PASS:-}" ]; then
                if is_auto_password "${REDIS_PASS}"; then
                    redis_pass="$(generate_auto_password)"
                    log "检测到 REDIS_PASS=auto，已生成 24 位随机密码"
                else
                    redis_pass="${REDIS_PASS}"
                fi
                if [ -w "${config_file}" ]; then
                    {
                        echo ""
                        echo "# 由 entrypoint 自动注入密码。可通过 DEFAULT_CONF=disable 关闭。"
                        echo "requirepass ${redis_pass}"
                    } >> "${config_file}"
                    log "已自动写入 requirepass 到 ${config_file}"
                else
                    set -- "$@" --requirepass "${redis_pass}"
                    log "配置文件不可写，已通过命令行参数注入 requirepass"
                fi
                log "Redis 密码: ${redis_pass}"
            else
                log "未提供 REDIS_PASS，保持无密码模式启动"
            fi
        fi
    fi
fi

exec "$@"
