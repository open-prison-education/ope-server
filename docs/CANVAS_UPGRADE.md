# Canvas upgrade

This runbook is for an existing OPE site moving onto the current Canvas stack,
or applying a newer pinned Canvas image later. A brand-new install stops at
[First-time database](#first-time-database): `ope-canvas-init` creates the
schema when the database is empty.

`ope-canvas-init` runs `initial` only when `canvas_production` has no tables,
then exits. Web and jobs start after that. `ope-canvas-migrate`
(`--profile migrate`) is the manual command for `predeploy` and `upgrade`.

## What operators should expect

- **Canvas owns PostgreSQL and Redis.** Enabling `ope-canvas` (or `ope-smc`,
  which depends on it) starts `ope-postgresql`, `ope-redis`, `ope-canvas-rce`,
  `ope-canvas-mathman`, `ope-canvas-init`, `ope-canvas`, and `ope-canvas-jobs`.
- **PostgreSQL is 16.15.** Data lives in `pgdata-16.15` on the existing
  `postgresql/data` volume. An old PostgreSQL 12 datadir on that volume is left
  alone; the new container does not upgrade it in place.
- **Redis is 8.8** on a new `redis/data2` volume. There is no Redis password.
  SMC still flushes Canvas cache (logical DB 0) that way. Do not add
  `requirepass`.
- **Jobs live in `canvas_production`.** There is no `canvas_queue` database.
- **Images are built or imported, then stay offline.** `./up.sh` starts
  containers. Runtime startup does not `git pull` or download gems. Air-gapped
  hosts use the [Offline Deployment Guide](OFFLINE_DEPLOYMENT.md).

Rehearse the restore and upgrade on a spare host with egress blocked before you
touch production. Measure how long backup and restore actually take on your
data; do not invent recovery targets.

## First-time database

On a new PostgreSQL 16 volume, `ope-canvas-init` starts after PostgreSQL and
Redis are healthy. When `canvas_production` has no tables in `public` (or
the database is not there yet), it runs `canvas-migrate.sh initial`. When
any public table is already present, it leaves the schema unchanged. Web and
jobs start after that container exits successfully.

`initial` is for an empty database. Use `upgrade` (and `predeploy` when
moving to a newer image) on a database that already has Canvas tables.

Admin login is `admin@<your-domain>` with the `it_pw` value from `config.yml`.

## Upgrade an existing site

1. Take an off-host Canvas snapshot. FOG does not need to be running.

   ```bash
   OPE_BACKUP_ROOT=/mnt/backup/canvas ./scripts/backup_canvas.sh
   ```

   Confirm the snapshot has `postgresql/canvas_production.dump`, files, keys,
   and `config/`. See [Canvas backup and restore](CANVAS_BACKUP_RESTORE.md).

2. Restore that snapshot onto an isolated rehearsal host that already has the
   new images (or build them there with `./up.sh b`). Keep production running
   until rehearsal succeeds.

3. On the cutover host (production after rehearsal, or the same server if you
   accept that risk), render config and start PostgreSQL only. A full
   `./up.sh` on an empty database runs `ope-canvas-init`, which would create
   a new schema before the snapshot is loaded.

   ```bash
   ./scripts/rebuild.sh
   docker compose up -d ope-postgresql
   ```

   PostgreSQL initializes `pgdata-16.15` if that directory is empty. An old
   PostgreSQL 12 datadir on the same volume is not reused and is not deleted.
   Redis starts on a new `data2` volume when the Canvas services start.

4. Restore the snapshot onto that empty PostgreSQL 16 volume. Then, from the
   **new** image, run predeploy:

   ```bash
   docker compose --profile migrate run --rm ope-canvas-migrate \
     /usr/local/bin/canvas-migrate.sh predeploy
   ```

5. Drain the old web and job containers if they are still on the previous
   image.

6. Run the final upgrade:

   ```bash
   docker compose --profile migrate run --rm ope-canvas-migrate \
     /usr/local/bin/canvas-migrate.sh upgrade
   ```

7. Start Canvas. `ope-canvas-init` sees the restored tables and exits;
   web and jobs then start:

   ```bash
   docker compose up -d ope-canvas ope-canvas-jobs
   ```

8. Exercise admin login, a student import from SMC, a file upload, an equation
   in the rich content editor, and a reboot. SMC laptop login still writes
   Canvas access tokens and flushes Redis with no password.

9. Keep the previous images, the old PostgreSQL 12 files on the volume (if
   they are still there), the file snapshot, and the keys until you are
   satisfied the new site is stable. Then you can remove the old datadir.

Database rollback after forward migrations is restore, not a container restart:

```bash
./scripts/restore_canvas.sh /mnt/backup/canvas/<stamp>
```

## Secret rotation

| Secret | Where | How to rotate |
|--------|--------|----------------|
| `IT_PW` | `config.yml` | Postgres superuser, `canvas` role, and Canvas admin login. Redis has no password. Change the value, run `./up.sh`, then restart Postgres, Canvas, and jobs. Update the `canvas` role password in Postgres if it was created under the old value. |
| `CANVAS_SECRET` | `.secrets.yml` → `security.yml` `encryption_key` | Changing this without a rehearsal can make existing encrypted rows unreadable. `ope:production_apply` (run by migrate) calls `db:reset_encryption_key_hash`. |
| `CANVAS_JWT_ENCRYPTION_KEY` | `.secrets.yml` → `security.yml` `jwt_encryption_keys` | Replacing the single generated key invalidates issued JWTs. To rotate safely, add the new 64-character key above the old one in `ope-canvas/runtime/security.yml.tmpl` and keep both until those tokens expire. |
| `CANVAS_ENC_SECRET` / `CANVAS_SIGN_SECRET` | `.secrets.yml`, vault contents, RCE `ECOSYSTEM_KEY` / `ECOSYSTEM_SECRET` | Rotate together. Existing RCE JWTs fail until Canvas and RCE both have the new values. |
| JWKs | `<volumes_root>/canvas/keys` | Generate a new future key. Do not delete past or present keys that already issued tokens. |

Do not commit `.env`, `config.yml`, or `.secrets.yml`.
