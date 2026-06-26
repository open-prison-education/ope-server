# OPE Download Site (ope-dl)

A simple download site for the Open Prison Education platform. 
a plain Apache HTTP server with `mod_autoindex`
directory listing enabled. It serves a folder of static files like 
OPE apps and docker images that faculty can browse and download.

There is no application framework, database, or login - it is intentionally a
read-only static file index, which keeps it robust in limited / offline
correctional environments.

## Usage

Enable the download site in `config.yml` (or via the interactive setup wizard
`./setup.sh`):

```yaml
services:
  - ope-dl
```

Then start services:

```bash
./up.sh
```

The site is reachable at `https://dl.<DOMAIN>` or locally at (e.g. `https://dl.ed`) once
`ope-dns` and the `ope-gateway` certificate are in place.

## Content

Files to publish are served from the host directory `volumes/dl/`, which is
mounted **read-only** into the container at `/downloads`. Drop files and
folders into `volumes/dl/` and they appear in the directory listing
immediately - no rebuild required:

Notes:

- If a directory contains an `index.html`, Apache serves that instead of the
  auto-generated listing. Omit `index.html` to keep the browsable index.
- The mount is read-only by design, so the site cannot be modified through the
  web - add or remove files directly under `volumes/dl/` on the server.

## How it works

- Base image: `httpd:2.4` (Apache HTTP Server on Debian).
- The `DocumentRoot` and its `<Directory>` block are repointed to `/downloads`,
  with `FancyIndexing` enabled for a tidier listing.
