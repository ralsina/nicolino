# Pocketbase CMS for Nicolino

This directory contains the Docker setup for running Pocketbase as a headless CMS with Nicolino.

## Quick Start

```bash
# From the repository root, start Pocketbase
cd pocketbase && docker compose up -d

# Open Admin UI at http://localhost:8090/_/
# Create an admin account

# Add import config to conf.yml (see POCKETBASE.md)

# Import content
./bin/nicolino import

# Build site
./bin/nicolino build
```

## Files

- `docker/pocketbase.Dockerfile` - Docker image with pre-configured migrations
- `migrations/` - Database schema for posts and pages collections
- `docker-compose.yml` - Docker Compose configuration

## Documentation

See [POCKETBASE.md](./POCKETBASE.md) for complete documentation.
