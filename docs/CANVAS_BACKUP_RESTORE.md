# Canvas backup, restore, and upgrade

Use this page to copy Canvas data, put that copy back, or upgrade the server from an older Canvas version to the current one.

A brand-new deployment does not need these steps. `./up.sh` creates an empty Canvas for you. See the [Deployment Guide](DEPLOYMENT.md).

Run the commands from the `ope-server` folder. Let each command finish. Some of them take a long time, and the screen can sit still while they work.

## Which steps do I follow?

- **Save a copy of Canvas:** [Make a backup](#make-a-backup)
- **Put a copy back onto this same version:** [Restore a backup](#restore-a-backup)
- **Upgrade the server from an older Canvas version to the current one:** [Upgrade the server from an older Canvas version](#upgrade-the-server-from-an-older-canvas-version)
- **The upgrade failed:** [Go back](#go-back)

## Make a backup

The Canvas database container (`ope-canvas-postgres`) must be running.

```bash
./scripts/backup_canvas.sh
```

The script prints a folder name like `backups/canvas/20261021T195300Z`. That folder is the backup. Copy the whole folder to another disk or another computer.

Open the folder and confirm it contains:

- `postgresql/canvas_production.dump` — courses, users, and background jobs
- `config/` — your settings, including `config.yml` and `secrets.yml`
- `files/files.tar` — uploaded files, when the site has any
- `keys/keys.tar` — the keys Canvas uses to read saved data, when the site has any

The backup leaves out the temporary cache. Canvas rebuilds that on its own.

The backup holds passwords and keys, so only the user who ran the script can open it. If you ran it with `sudo`, use `sudo` to copy it too.

This command does not run by itself. To run it every night, see [Backup and Restore](DEPLOYMENT.md#backup-and-restore) in the Deployment Guide. Each successful backup deletes older backup folders (named like `20261021T195300Z`) in that same folder when they are more than 30 days old. It leaves other files alone. Keep the off-computer copy.

To write the backup straight to another disk:

```bash
OPE_BACKUP_ROOT=/mnt/backup/canvas ./scripts/backup_canvas.sh
```

Change `/mnt/backup/canvas` to a folder on that disk.

## Restore a backup

Use this when the backup was made by **the same** version of Canvas.

A backup from an **older** Canvas version follows [Upgrade the server from an older Canvas version](#upgrade-the-server-from-an-older-canvas-version). Those steps update the database before Canvas starts.

Run the commands below. On an empty database, `./up.sh` creates a new Canvas before your backup is loaded, and the restore can then fail.

1. On a different computer, copy the settings out of the backup first:
   - `config/config.yml` → `config.yml` in `ope-server`
   - `config/secrets.yml` → `.secrets.yml` in `ope-server`

   The second name starts with a dot. The restore script does not copy these files for you. On the same computer, `config.yml` and `.secrets.yml` are already in place.

2. Write the Docker settings from `config.yml`, stop the website and background jobs, then start only the database. Stopping is safe when they are already stopped:

   ```bash
   ./scripts/rebuild.sh
   docker compose stop ope-canvas ope-canvas-jobs
   docker compose up -d --no-deps ope-canvas-postgres
   ```

3. Wait until the database is ready:

   ```bash
   docker compose ps ope-canvas-postgres
   ```

   Continue when the status says `healthy`. If it says `starting`, wait a minute and run the command again.

4. Load the backup. Pass the backup folder. For example, for the folder `backups/canvas/20261021T195300Z`:

   ```bash
   ./scripts/restore_canvas.sh backups/canvas/20261021T195300Z
   ```

   Wait until it prints `Restore complete.` If it prints `Database restore failed.`, leave the website and background jobs stopped. A failed restore can leave the database only partly loaded. Read the lines above that message, fix the cause, then run the restore again with the same backup folder:

   ```bash
   ./scripts/restore_canvas.sh backups/canvas/20261021T195300Z
   ```

   Start Canvas only after the script prints `Restore complete.`

5. Start Canvas:

   ```bash
   docker compose up -d ope-canvas ope-canvas-jobs
   ```

6. [Check that Canvas works](#check-that-canvas-works).

## Upgrade the server from an older Canvas version

Use these steps when the server is running an older Canvas version than the current ope-server. Do this once.

The new database files live in `volumes/postgresql/data/pgdata-16.15` (or under your custom volumes folder). Leave the other folders next to `pgdata-16.15` alone until the new site has been working for a while.

The website is down from the stop command until Canvas starts again. If you have a spare computer, copy the backup there and run this whole section on it first. Leave the real site running until that copy works.

1. On the current server, make a backup of the older Canvas. The older ope-server has no backup script, and its database container is named `ope-postgresql`, so use the script from this version:

   - Copy `scripts/backup_canvas.sh` from this version of ope-server into the `scripts` folder of the older ope-server on the current server.
   - From the older ope-server folder, with the older Canvas still running, run:

     ```bash
     ./scripts/backup_canvas.sh --old-stack
     ```

   It prints a folder name like `backups/canvas/20261021T195300Z` and ends with `Canvas backup complete.` Check the folder contents as in [Make a backup](#make-a-backup). Copy the whole backup folder off the computer. Keep it until you trust the new server.

2. On the computer that will run this version, put this version of ope-server and its images in place. From the backup folder, copy:
   - `config/config.yml` → `config.yml`
   - `config/secrets.yml` → `.secrets.yml`

   A server/site with no internet connection follows the [Offline Deployment Guide](OFFLINE_DEPLOYMENT.md) to load the images first, then continues here. Start the Canvas website at step 6, after the database update.

3. Write the Docker settings, stop Canvas, and start only the database:

   ```bash
   ./scripts/rebuild.sh
   docker compose stop ope-canvas ope-canvas-jobs
   docker compose up -d --no-deps ope-canvas-postgres
   ```

   Wait until `docker compose ps ope-canvas-postgres` shows `healthy`.

4. Load the backup. Pass the backup folder. For example, for the folder `backups/canvas/20261021T195300Z`:

   ```bash
   ./scripts/restore_canvas.sh backups/canvas/20261021T195300Z
   ```

   Wait until it prints `Restore complete.` The restore makes the `canvas` database user the owner of everything it loads. The older version used `postgres`. If it prints `Database restore failed.`, leave Canvas stopped and follow [Go back](#go-back).

5. Update the database. Keep the website and jobs stopped. Run the first command and wait until you are back at the prompt. Then run the second command the same way.

   ```bash
   docker compose --profile migrate run --rm ope-canvas-migrate \
     /usr/local/bin/canvas-migrate.sh predeploy
   ```

   ```bash
   docker compose --profile migrate run --rm ope-canvas-migrate \
     /usr/local/bin/canvas-migrate.sh upgrade
   ```

   If either command prints `rake aborted!` or stops with an error, leave Canvas stopped and follow [Go back](#go-back).

6. Start Canvas:

   ```bash
   docker compose up -d ope-canvas ope-canvas-jobs
   ```

7. [Check that Canvas works](#check-that-canvas-works).

8. Keep the backup folder and the previous copy of ope-server until the new site has been stable.

## Check that Canvas works

- Open Canvas and log in as `admin@<your-domain>`. The password is the `it_pw` value in `config.yml`.
- Upload a file.
- Insert an equation in the editor.
- If you use SMC, import a student and log in from a student laptop.
- Reboot the server, then log in again.

## Go back

Starting Canvas again leaves a half-finished database update in place.

- **Return to the older Canvas version.** Stop this version with `./down.sh`. Put the older copy of ope-server back in place and start it with its own `./up.sh`. The older version reads its own database folder next to `pgdata-16.15` (for example `pgdata-12.9`), and the upgrade does not change that folder. If you ran the upgrade on a spare computer, the real server was never changed, so keep using it.
- **Try the upgrade again.** On the current version, repeat steps 4 and 5 in [Upgrade the server from an older Canvas version](#upgrade-the-server-from-an-older-canvas-version). The restore replaces the database. Start Canvas after both update commands finish and the prompt returns.

## Passwords and keys

Leave passwords and keys unchanged while you back up, restore, or upgrade. The backup already contains the keys that match the database.

- `it_pw` in `config.yml` is both the database password and the Canvas admin password. Changing it means updating the database user as well. Get help before changing it.
- Redis has no password. Leave it that way. SMC clears the Canvas cache by connecting without one.
- `canvas_secret` in `.secrets.yml` protects data already stored in Canvas. Changing it can make that data unreadable.
- `canvas_jwt_encryption_key` in `.secrets.yml` signs API and service tokens. It does not sign the browser login cookie. Replacing the only key makes existing tokens fail. To change it while old tokens still work:
  1. In `.secrets.yml`, add a line `canvas_jwt_encryption_key_previous:` and move the current `canvas_jwt_encryption_key` value onto it.
  2. Set `canvas_jwt_encryption_key` to a new value. `openssl rand -hex 32` prints one.
  3. Run `./scripts/rebuild.sh`, then `docker compose restart ope-canvas ope-canvas-jobs`.

  Canvas then signs new tokens with the new key and still accepts tokens signed with the previous one. After those tokens expire, delete the `canvas_jwt_encryption_key_previous` line and run the two commands in step 3 again. Only one previous key is kept, so finish one change before you start another.
- `canvas_enc_secret` and `canvas_sign_secret` in `.secrets.yml` change together. The editor uses the same values. Existing editor sessions fail until Canvas and the editor both have the new pair.
- Keys in the Canvas `keys` folder can be added. Keep every key that is already there. Deleting one can make older content unreadable.

Do not commit `.env`, `config.yml`, or `.secrets.yml`.
