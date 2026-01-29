Initialize and manage TinaCMS for content management.

## Usage

```text
{{% shell command="bin/nicolino tinacms --help" %}}
```

## Commands

### `nicolino tinacms init`

Initialize TinaCMS in an existing Nicolino site. This command sets up all necessary files and dependencies for TinaCMS integration.

**What it does:**
- Creates the `tina/` configuration directory
- Generates default TinaCMS configuration files
- Creates `package.json` with TinaCMS dependencies
- Installs npm packages automatically
- Creates `content/media/` for uploaded media

**Example:**
```bash
nicolino tinacms init
```

### `nicolino tinacms serve`

Start the TinaCMS development server along with Nicolino's auto-rebuild mode.

**What it does:**
- Starts the TinaCMS admin interface at `http://localhost:8080/admin/`
- Starts Nicolino in auto mode to rebuild on content changes
- Manages both processes together (stops both on Ctrl+C)

**Example:**
```bash
nicolino tinacms serve
```

## Description

TinaCMS provides a visual content management interface for Nicolino sites, allowing you to create and edit content through a web-based admin panel instead of editing files directly.

See the [TinaCMS documentation](../tinacms.md) for detailed information about using TinaCMS with Nicolino.
