Let's get you up and running with Nicolino.

## Installing Nicolino

Clone the Nicolino repository and build it:

```bash
git clone https://github.com/ralsina/nicolino.git
cd nicolino
shards build
```

The compiled binary will be at `./bin/nicolino`. To use `nicolino` from anywhere, copy it to a directory in your PATH:

```bash
cp ./bin/nicolino ~/.local/bin/
# or
sudo cp ./bin/nicolino /usr/local/bin/
```

Verify the installation:

```bash
nicolino --version
```

## Creating a New Site

The easiest way to create a new site is using the `nicolino init` command:

```bash
nicolino init my-site
cd my-site
```

This creates a [basic site structure](directory-layout.md) with:

- `conf.yml` - Site configuration
- `content/` - Empty directories for your content
- Sample configuration to get you started

## Creating New Content

Use the `nicolino new` command to create new content:

```bash
# Create a new blog post
nicolino new post "My First Post"

# Create a new gallery
nicolino new gallery "vacation-photos"

# Create a new page
nicolino new page "about"
```

See the [CLI reference](cli/new.html) for all available content types.

## Building Your Site

Once you have some content, build your site:

```bash
nicolino build
```

This processes all your content and generates the static site in the `output/` directory.

## Previewing Your Site

To see your site in action while you work, use the built-in development server:

```bash
nicolino serve
```

The server starts on `http://localhost:8080` by default. Open this URL in your browser to see your site.

### Custom Port

To use a different port:

```bash
nicolino serve --port 3000
```

## Live Auto-Rebuild Mode

For automatic rebuilding when files change, use auto mode:

```bash
nicolino auto
```

This watches for file changes and rebuilds automatically. Nicolino only rebuilds what's needed, so it's fast even on large sites.

You can combine auto mode with the serve command in two terminals:

```bash
# Terminal 1: Watch for changes and rebuild
nicolino auto

# Terminal 2: Serve the site
nicolino serve
```

This gives you live reload - edit a file, save, and refresh your browser to see changes.

## Deploying Your Site

Once you're happy with your site, the `output/` directory contains everything you need to deploy. Simply upload the contents of `output/` to any web server.

Because Nicolino generates static files, you can host your site anywhere:

- GitHub Pages
- Netlify
- Vercel
- Any traditional web server
- CDN storage (S3, Cloudflare, etc.)

## Next Steps

Now that you have a site running:

1. Read about the [Directory Layout](directory-layout.md) to understand the structure
2. Check the [Configuration](configuration.md) chapter to customize your site
3. Learn about [Markdown](markdown.md) for writing content
4. Explore the [Features](#) section to add posts, galleries, books, and more
