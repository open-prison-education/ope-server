# OPE SMC (Student Management Console)

Student Management Console for the Open Prison Education platform.

## Overview

SMC is the central management interface for OPE, providing tools to manage student accounts, content, and integration with Canvas LMS and OPE Laptops.

## Features

- **User Management:** Import and manage student accounts
- **Document Upload:** Upload documents directly to Canvas
- **Video Management:** Pull YouTube videos for offline conversion
- **Media Library:** Organize and manage media content
- **Document Library:** Central document repository
- **PDF Conversion:** Convert web links to PDF files
- **Canvas Integration:** Sync content with Canvas LMS

## Technical Details

- **Base Image:** Alpine 3.18
- **Framework:** Web2py
- **Port:** 8000

## Configuration

Configure the SMC domain in `.env`:

```
SMC_DEFAULT_DOMAIN=smc.<DOMAIN>
```

## Usage

Enable the service:

```bash
touch ope-smc/.enabled
./up.sh
```
