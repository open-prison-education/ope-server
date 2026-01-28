# OPE Canvas RCE

Rich Content Editor service for Canvas LMS.

## Overview

Provides the Rich Content Editor (RCE) functionality for Canvas LMS, enabling rich text editing, media embedding, and content creation within courses.

## Features

- Rich text editing with formatting options
- Media embedding support
- Equation editor integration
- Link management

## Configuration

Configure the RCE domain in `.env`:

```
CANVAS_RCE_DEFAULT_DOMAIN=rce.<DOMAIN>
```

## Usage

Enable the service:

```bash
touch ope-canvas-rce/.enabled
./up.sh
```

## Technical Details

This service is required for Canvas LMS rich content editing functionality.
