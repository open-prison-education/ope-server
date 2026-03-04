# OPE freeCodeCamp

Offline freeCodeCamp content for the Open Prison Education platform.

## Overview

Provides offline access to freeCodeCamp curriculum, allowing students to learn web development without internet access.

## Usage

Enable freeCodeCamp in `config.yml` (or via the interactive setup wizard `./setup.sh`):

```yaml
services:
  - ope-freecodecamp
```

Then start services:

```bash
./up.sh
```

## Notes

Content must be downloaded and placed in the appropriate volume for offline access.
