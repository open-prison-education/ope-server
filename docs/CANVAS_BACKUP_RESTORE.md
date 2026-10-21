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

This command does not run by itself. To run it every night, see [Backup and Restore](DEPLOYMENT.md#backup-and-restore) in the Deployment Guide. Each successful backup deletes copies in that same folder that are more than 30 days old, so keep the off-computer copy.

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

4. Load the backup. Pass the backup folder, and use your folder name:

   ```bash
   ./scripts/restore_canvas.sh /path/to/the/backup/folder>
   e.g. ./scripts/restore_canvas.sh backups/canvas/20261021T195300Z
   ```

   Wait until it prints `Restore complete.`

5. Start Canvas:

   ```bash
   docker compose up -d ope-canvas ope-canvas-jobs
   ```

6. [Check that Canvas works](#check-that-canvas-works).

## Upgrade the server from an older Canvas version

Use these steps when the server is running an older Canvas version than the current ope-server. Do this once.

The new database files live in `volumes/postgresql/data/pgdata-16.15` (or under your custom volumes folder). Leave the other folders next to `pgdata-16.15` alone until the new site has been working for a while.

The website is down from the stop command until Canvas starts again. If you have a spare computer, copy the backup there and run this whole section on it first. Leave the real site running until that copy works.

1. On the current server, [make a backup](#make-a-backup). Copy the whole backup folder off the computer. Keep it until you trust the new server.

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

4. Load the backup. Use the path to your backup folder:

   ```bash
   ./scripts/restore_canvas.sh /path/to/the/backup/folder
   e.g. ./scripts/restore_canvas.sh backups/canvas/20261021T195300Z
   ```

   Wait until it prints `Restore complete.`

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

- **Return to the older Canvas version.** Install the older ope-server again and follow [Restore a backup](#restore-a-backup) with the backup you saved before the upgrade. Skip the two update commands. Those belong only to the current version.
- **Try the upgrade again.** On the current version, repeat steps 4 and 5 in [Upgrade the server from an older Canvas version](#upgrade-the-server-from-an-older-canvas-version). The restore replaces the database. Start Canvas after both update commands finish and the prompt returns.

## Passwords and keys

Leave passwords and keys unchanged while you back up, restore, or upgrade. The backup already contains the keys that match the database.

- `it_pw` in `config.yml` is both the database password and the Canvas admin password. Changing it means updating the database user as well. Get help before changing it.
- Redis has no password. Leave it that way. SMC clears the Canvas cache by connecting without one.
- `CANVAS_SECRET` in `.secrets.yml` protects data already stored in Canvas. Changing it can make that data unreadable.
- `CANVAS_JWT_ENCRYPTION_KEY` in `.secrets.yml` is used for login tokens. To change it, add the new key above the old one and keep both until old sessions expire. Replacing the only key logs everyone out.
- `CANVAS_ENC_SECRET` and `CANVAS_SIGN_SECRET` change together. The editor uses the same values. Existing editor sessions fail until Canvas and the editor both have the new pair.
- Keys in the Canvas `keys` folder can be added. Keep every key that is already there. Deleting one can make older content unreadable.

Do not commit `.env`, `config.yml`, or `.secrets.yml`.
