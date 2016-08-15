# docker-redis

How to use this image
start a redis instanc

```bash
$ dock build -t benyoo/redis:3.2.3 ./
$ docker run --name redis -v /data/redis.conf:/etc/redis.conf -p 6379:6379 -d benyoo/redis:3.2.1 /etc/redis.conf
```

This image includes EXPOSE 6379 (the redis port), so standard container linking will make it automatically available to the linked containers (as the following examples illustrate).

start with persistent storage
```bash
$ docker run --name redis -v /data/redis.conf:/etc/redis.conf -p 6379:6379 -d benyoo/redis:3.2.1 --appendonly yes --bind 0.0.0.0
```

快速启动
```bash
curl -Lks http://git.dwhd.org/lookback/docker-redis/raw/master/docker-compose.yml -o docker-compose.yml
docker-compose up -d
```


