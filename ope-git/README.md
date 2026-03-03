# OPE Git

Git server for the Open Prison Education platform.

## Usage

Enable the Git server in `config.yml` (or via the interactive setup wizard `./setup.sh`):

```yaml
services:
  - ope-git
```

Then start services:

```bash
./up.sh
```

## Technical Details

Repositories are stored in the configured volume and can be accessed by authenticated users.
