#!/bin/sh
set -eu

TOTAL_MEM=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024 }' /proc/meminfo)
REDIS_MEM="128mb"
if [ "$TOTAL_MEM" -gt 1 ]; then REDIS_MEM="256mb"; fi
if [ "$TOTAL_MEM" -gt 3 ]; then REDIS_MEM="384mb"; fi
if [ "$TOTAL_MEM" -gt 5 ]; then REDIS_MEM="512mb"; fi
if [ "$TOTAL_MEM" -gt 7 ]; then REDIS_MEM="768mb"; fi
if [ "$TOTAL_MEM" -gt 8 ]; then REDIS_MEM="1024mb"; fi
if [ "$TOTAL_MEM" -gt 14 ]; then REDIS_MEM="2048mb"; fi

cp /usr/local/etc/redis/redis.conf /tmp/redis.conf
sed -i "s/maxmemory 256mb/maxmemory ${REDIS_MEM}/" /tmp/redis.conf

exec redis-server /tmp/redis.conf
