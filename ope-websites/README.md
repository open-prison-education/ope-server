# OPE Websites

OSN approved websites

## Overview

A page of all of the OSN approved websites

## Usage

Enable OPE Websites in `config.yml` (or via the interactive setup wizard `./setup.sh`):

```yaml
services:
  - ope-websites
```

You may need to build the image locally as it's uploaded to the registry yet.

```bash
./scripts/rebuild.sh
docker compose build ope-websites
```
Then start services:

```bash
./up.sh
```


