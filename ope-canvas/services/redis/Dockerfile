FROM redis:8.8.3-alpine

LABEL description="Canvas-owned Redis 8.8 for Open Prison Education"

COPY redis.conf /usr/local/etc/redis/redis.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

VOLUME ["/data"]
EXPOSE 6379
CMD ["/start.sh"]
