# Contributing

We welcome contributions to Nicolino! Here's how to get started.

## Development Setup

```bash
# Clone the repository
git clone https://github.com/ralsina/nicolino.git
cd nicolino

# Install dependencies
shards install

# Build the binary
make bin
```

## Running Tests

Nicolino uses Ameba for linting as the primary quality gate:

```bash
# Run linter
make lint
# or
ameba --all
```

## Code Style

- Use descriptive parameter names in blocks (not single letters)
- No `not_nil!` usage
- Prefer explicit error handling over `to_s` for nilable values
- Run `ameba --fix` to auto-fix formatting issues

## Commit Messages

We use [Commitizen](https://commitizen-tools.github.io/commitizen/) for consistent commit messages:

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `chore:` - Maintenance tasks

## Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run the linter
5. Submit a pull request

## Adding Features

See the [Adding a New Feature](adding_a_new_feature.md) chapter for detailed guidance.
