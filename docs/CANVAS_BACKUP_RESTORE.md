# Canvas backup and restore

Use these scripts when you need a Canvas snapshot you can restore later — before
an upgrade or after a failed cutover.

| Situation | Command |
|-----------|---------|
| Backup Canvas occasionally or before an upgrade | `./scripts/backup_canvas.sh` |
| Restore a Canvas snapshot | `./scripts/restore_canvas.sh backups/canvas/<stamp>` |

`ope-postgresql` must be running for backup and restore. The scripts talk to
that container; they do not dump files from inside the live PostgreSQL data
directory.

## What a Canvas backup contains

`backup_canvas.sh` writes a timestamped directory (`YYYYMMDDTHHMMSSZ`, UTC)
under `backups/canvas/` unless you set `OPE_BACKUP_ROOT`.

| Path in the snapshot | Contents |
|----------------------|----------|
| `postgresql/canvas_production.dump` | The Canvas database (courses, users, and background jobs) |
| `files/files.tar` | Uploaded files from `<volumes_root>/canvas/tmp/files` |
| `keys/keys.tar` | Canvas encryption keys from `<volumes_root>/canvas/keys` |
| `config/` | A copy of the config that was running (`config.yml`, `.secrets.yml`, rendered Canvas YAML, `docker-compose.yml`) |

The snapshot is a directory, not a tarball. Copy the whole directory off the
host if you need it on another machine.

The script does **not** dump Redis. Canvas cache and MathMan equation cache
are rebuilt at runtime. It also does **not** write a second SQL dump next to
the PostgreSQL volume.

## Run a backup

```bash
# Default destination: ./backups/canvas/<stamp>
./scripts/backup_canvas.sh

# Off-host destination and custom retention (days)
OPE_BACKUP_ROOT=/mnt/backup/canvas OPE_BACKUP_KEEP_DAYS=60 ./scripts/backup_canvas.sh
```

Both backup and restore read `VOLUMES_ROOT` from `.env` when the environment
variable is unset, so a custom `volumes_root` in `config.yml` is picked up
after `./scripts/rebuild.sh` or `./up.sh`.

After a successful run, backups older than `OPE_BACKUP_KEEP_DAYS` (default 30)
are deleted from the backup root.

## Restore

Restore onto a PostgreSQL 16 volume that uses the current `pgdata-16.15`
datadir. Do not point the new container at an old PostgreSQL 12 data directory
and expect an in-place upgrade.

1. On a new host, copy `config.yml` and `.secrets.yml` from the snapshot's
   `config/` directory first (saved there as `config.yml` and `secrets.yml`).
   Render config and start PostgreSQL only. Starting the full stack on an
   empty database runs `ope-canvas-init`, which would create a new schema
   before the snapshot is loaded.

   ```bash
   ./scripts/rebuild.sh
   docker compose up -d ope-postgresql
   ```

   Wait until `docker compose ps` shows `ope-postgresql` healthy. If Canvas
   web or jobs are already running, stop them first:

   ```bash
   docker compose stop ope-canvas ope-canvas-jobs
   ```

2. Restore the snapshot directory (not an archive):

   ```bash
   ./scripts/restore_canvas.sh backups/canvas/20261015T090000Z
   ```

   That loads `canvas_production.dump` into Postgres, then unpacks `files.tar`
   and `keys.tar` when those files exist. Files and keys go under
   `VOLUMES_ROOT` from `.env` (or `./volumes` if unset). It does not write
   `config.yml` or `.secrets.yml` back into the repo (step 1 is how those get
   onto a new host), and it does not restore Redis.

3. Bring the database tables up to date **only if** this host is running a
   newer Canvas image than the one that created the backup. Restore puts back
   the tables as they were that day. A newer image expects newer columns and
   tables, so Canvas will fail until you run:

   ```bash
   docker compose --profile migrate run --rm ope-canvas-migrate \
     /usr/local/bin/canvas-migrate.sh upgrade
   ```

   Skip this when you are restoring onto the **same** Canvas image you backed
   up from (same-version recovery). Use it when the restore is part of an
   [upgrade](CANVAS_UPGRADE.md).

4. Start Canvas. `ope-canvas-init` sees the restored tables and exits;
   web and jobs then start:

   ```bash
   docker compose up -d ope-canvas ope-canvas-jobs
   ```

Rolling back after a forward migration is this restore path, not a container
restart. See [Canvas upgrade](CANVAS_UPGRADE.md).
