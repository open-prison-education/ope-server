# OPE CodeCombat

CodeCombat learning environment for the Open Prison Education platform.

## Overview

CodeCombat is a game-based platform for learning programming. Students learn to code by playing through levels that teach programming concepts.

## Features

- Game-based coding education
- Multiple programming languages (Python, JavaScript)
- Progressive difficulty levels
- Offline-capable

## Technical Details

- **Base Image:** Ubuntu 16.04
- **Database:** MongoDB (internal)
- **Runtime:** Node.js

## Usage

Enable CodeCombat in `config.yml` (or via the interactive setup wizard `./setup.sh`):

```yaml
services:
  - ope-codecombat
```

Then start services:

```bash
./up.sh
```

## Notes

CodeCombat requires significant resources. Ensure adequate memory is available before enabling.
