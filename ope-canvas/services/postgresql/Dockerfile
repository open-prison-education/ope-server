FROM postgres:16.15-alpine@sha256:1a66d744c1b459e13b05a8fca341da84cb63383e99ce262210efee5a319d4551

LABEL description="Canvas-owned PostgreSQL 16 for Open Prison Education"

COPY initdb/ /docker-entrypoint-initdb.d/

ENV POSTGRES_USER=postgres \
    PGDATA=/var/lib/postgresql/data/pgdata-16.15

CMD ["postgres", "-c", "max_locks_per_transaction=640", "-c", "max_stack_depth=5MB", "-c", "shared_buffers=256MB", "-c", "password_encryption=scram-sha-256"]
