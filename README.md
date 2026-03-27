# docker-redis

基于 Alpine 源码编译 Redis 7/8 的容器项目，提供以下能力：

- 体积更小且构建过程更可控（源码编译 + 构建依赖清理）。
- 默认启用数据持久化（RDB + AOF）。
- `entrypoint.sh` 支持按需注入 `requirepass`（仅在设置 `REDIS_PASS` 时启用）。
- 提供可直接使用的 `docker-compose.yml`。

---

## 目录结构

```text
.
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── redis.conf
└── README.md
```

---

## 版本与默认信息

- 默认基础镜像：`benyoo/alpine:3.21.20260327`
- 默认 Redis 版本：`7.2.11`（可通过构建参数 `BASE_IMAGE`、`REDIS_VERSION` 覆盖）
- 默认数据目录：`/data/redis`
- 默认配置文件：`/etc/redis.conf`

### 推荐组合（与 Git tag 对应）

| Git tag | 基础镜像 | Redis 版本 |
| --- | --- | --- |
| `7.2.11` | `benyoo/alpine:3.21.20260327` | `7.2.11` |
| `8.0.4` | `benyoo/alpine:3.22.20260327` | `8.0.4` |
| `8.4.2` | `benyoo/alpine:3.23.20260327` | `8.4.2` |

同一仓库提交下通过不同构建参数产出对应镜像；检出对应 tag 后按上表 `docker build` 即可。

Redis 8.x 在编译 `redis-benchmark` 时会链接 `libstdc++`，Dockerfile 已在构建阶段安装 `g++`（构建结束后随 `.build-deps` 一并卸载，不留在最终镜像里）。

---

## 快速开始（推荐：Docker Compose）

1. 按需决定是否启用密码（需要密码时在 `docker-compose.yml` 中设置 `REDIS_PASS`）。
2. 启动服务：

```bash
docker compose up -d --build
```

3. 查看状态：

```bash
docker compose ps
docker compose logs -f redis
```

4. 测试连接：

```bash
# 无密码模式
redis-cli -h 127.0.0.1 -p 6379 ping

# 有密码模式
redis-cli -h 127.0.0.1 -p 6379 -a <你的密码> ping
```

返回 `PONG` 即为正常。

---

## 使用 Docker 命令运行

### 1) 本地构建镜像

默认（Redis 7.2.11 + Alpine 3.21）：

```bash
docker build -t benyoo/redis:7.2.11 .
```

Redis 8.0.4（Alpine 3.22）：

```bash
docker build \
  --build-arg BASE_IMAGE=benyoo/alpine:3.22.20260327 \
  --build-arg REDIS_VERSION=8.0.4 \
  -t benyoo/redis:8.0.4 .
```

Redis 8.4.2（Alpine 3.23）：

```bash
docker build \
  --build-arg BASE_IMAGE=benyoo/alpine:3.23.20260327 \
  --build-arg REDIS_VERSION=8.4.2 \
  -t benyoo/redis:8.4.2 .
```

### 2) 启动容器

```bash
docker run -d \
  --name redis \
  -p 6379:6379 \
  -e DEFAULT_CONF=enable \
  -e ENABLE_KERNEL_TUNING=auto \
  -v "$(pwd)/data:/data/redis" \
  -v "$(pwd)/redis.conf:/etc/redis.conf" \
  --restart unless-stopped \
  docker-redis:7.2.11
```

启用密码时追加：

```bash
-e REDIS_PASS='replace_with_strong_password'
```

自动生成 16 位随机密码时使用：

```bash
-e REDIS_PASS='auto'
```

---

## 环境变量说明

| 变量名 | 默认值 | 说明 |
| --- | --- | --- |
| `DATA_DIR` | `/data/redis` | Redis 数据目录 |
| `CONFIG_FILE` | `/etc/redis.conf` | Redis 配置文件路径 |
| `DEFAULT_CONF` | `enable` | 是否允许 entrypoint 自动补充配置（如 `requirepass`） |
| `REDIS_PASS` | 空（不启用密码） | 仅在设置后才自动注入 `requirepass`；取值为 `auto` 时自动生成 16 位大小写字母+数字随机密码 |
| `ENABLE_KERNEL_TUNING` | `auto` | 是否尝试设置 `somaxconn`、`overcommit_memory` 与 THP（失败不退出） |

### `DEFAULT_CONF` 的禁用值

以下值会被识别为禁用：`disable`、`false`、`no`、`0`（不区分大小写）。

---

## `redis.conf` 设计说明

当前默认配置是“容器友好 + 单实例生产可用”的折中方案：

- 网络：`bind 0.0.0.0`，`protected-mode no`
- 持久化：`save` + `appendonly yes`
- AOF：`appendfsync everysec`，兼顾安全与性能
- 内存淘汰策略：`maxmemory-policy noeviction`
- 慢日志：默认开启阈值与长度控制

如需更严格安全策略，可在 `redis.conf` 内手动固定 `requirepass`，并将 `DEFAULT_CONF=disable`。

---

## 数据持久化与挂载建议

- 建议始终挂载 `./data:/data/redis`，避免容器销毁导致数据丢失。
- 若挂载了宿主机 `redis.conf`，只有在设置了 `REDIS_PASS` 时 entrypoint 才会自动追加 `requirepass`。
- 生产场景建议将配置文件纳入版本管理，并固定密码来源（如 Secret 管理系统）。

---

## 健康检查

`docker-compose.yml` 已内置健康检查：

- 配置了 `REDIS_PASS` 时：`redis-cli -a "$REDIS_PASS" ping`
- 未配置密码时：`redis-cli ping`

可通过以下命令查看：

```bash
docker inspect --format='{{json .State.Health}}' redis | jq
```

---

## 常用运维命令

```bash
# 查看日志
docker logs -f redis

# 进入容器
docker exec -it redis bash

# 查看 Redis 信息（无密码）
docker exec -it redis redis-cli INFO server

# 查看 Redis 信息（有密码）
docker exec -it redis redis-cli -a <你的密码> INFO server

# 安全停止
docker stop redis
```

---

## 安全建议

- 不要在公网直接暴露 6379，建议配合防火墙/安全组限制来源。
- 如对外暴露或生产使用，务必设置强密码（`REDIS_PASS` 或手动配置 `requirepass`）。
- 如使用 Kubernetes 或 Swarm，建议用 Secret 注入密码。
- 生产环境建议监控 `used_memory`、`connected_clients`、`aof_current_size` 和慢日志。

---

## 兼容性说明

- `ENABLE_KERNEL_TUNING=auto` 在无权限或不支持的平台会自动跳过，不影响容器启动。
- 在 macOS/Windows 的 Docker Desktop 上，部分内核参数不可写属于正常现象。
- Linux 生产机如需严格对齐内核参数，建议在宿主机或 `sysctls` 中统一设置。
