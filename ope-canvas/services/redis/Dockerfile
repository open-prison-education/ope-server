FROM redis:7.4.11-alpine@sha256:ca0acbb137c1dc3339c8b147a58fd6f42775d4599327b50e7b116c23de501af2

LABEL description="Canvas-owned Redis 7.4 for Open Prison Education"

COPY redis.conf /usr/local/etc/redis/redis.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

VOLUME ["/data"]
EXPOSE 6379
CMD ["/start.sh"]
