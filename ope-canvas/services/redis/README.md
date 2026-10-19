# Canvas Redis

Canvas-owned Redis 8.8
SMC can flush DB 0. Protected mode is off so other containers can connect.
Canvas uses logical DB 0. MathMan uses DB 2 and the
`mml:` / `svg:` key prefixes.

`scripts/flush_redis_keys.sh` flushes DB 0.
