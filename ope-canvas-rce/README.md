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

The RCE domain is derived from the `domain` setting in `config.yml`
(e.g. `rce.<domain>`). No separate configuration is needed.

## Usage

This service is a **dependency** of `ope-canvas` and is enabled automatically
when Canvas is listed in `config.yml`. There is no need to enable it manually.

## Technical Details

This service is required for Canvas LMS rich content editing functionality.
