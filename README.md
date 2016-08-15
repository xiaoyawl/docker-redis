# docker-redis

How to use this image
start a redis instanc

```bash
$ dock build -t redis-serve:3.2.1 ./
$ docker run --name redis -d redis-serve:3.2.1
```

This image includes EXPOSE 6379 (the redis port), so standard container linking will make it automatically available to the linked containers (as the following examples illustrate).

start with persistent storage
```bash
$ docker run --name redis -d redis-server:3.2.1 redis-server --appendonly yes
```

快速启动
```bash
curl -Lks http://git.dwhd.org/lookback/docker-redis/raw/master/docker-compose.yml -o docker-compose.yml
docker-compose up -d
```
