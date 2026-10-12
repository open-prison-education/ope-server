# Canvas Redis

Canvas-owned Redis 7.4. No password, same as the previous stack, so unmodified
SMC can flush DB 0. Canvas uses logical DB 0. MathMan uses DB 2 and the
`mml:` / `svg:` key prefixes.

`scripts/flush_redis_keys.sh` flushes DB 0.
