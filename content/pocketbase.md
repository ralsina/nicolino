# Adding Pocketbase CMS to Your Nicolino Site

This is a step-by-step guide to add Pocketbase as a headless CMS to an existing Nicolino site.

## Prerequisites

- Nicolino installed and working
- Docker installed (for running Pocketbase)
- Basic familiarity with YAML configuration

## Step 1: Copy the Pocketbase Directory

Copy the entire `pocketbase/` directory from the Nicolino repository to your site's root directory:

```bash
# If you have Nicolino as a dependency
cp -r path/to/nicolino/pocketbase /your/site/root/

# Or if you're in the Nicolino repo and want to set up a test site
cp -r pocketbase /your/site/root/
```

Also copy the Pocketbase templates to your `user_templates/` directory:

```bash
cp pocketbase/templates/*.tmpl user_templates/
```

Your site structure should now look like:

```
your-site/
├── conf.yml
├── content/
├── user_templates/
│   ├── pocketbase_post.tmpl   <-- NEW
│   └── pocketbase_page.tmpl   <-- NEW
├── pocketbase/                <-- NEW
│   ├── docker/
│   ├── migrations/
│   ├── templates/
│   ├── docker-compose.yml
│   └── POCKETBASE.md
└── ...other files
```

## Step 2: Start Pocketbase

Navigate to the pocketbase directory, create the data directories, and start Pocketbase using Docker Compose:

```bash
cd pocketbase
mkdir -p pb_data pb_public
docker compose up -d
```

You should see output like:

```
[+] Running 2/2
 ✔ Network pocketbase_default      Created
 ✔ Container nicolino-pocketbase    Started
```

Verify Pocketbase is running:

```bash
docker compose logs
```

You should see logs indicating Pocketbase is serving on port 8090.

Pocketbase is now available at:

- **Admin UI**: http://localhost:8090/_/
- **API**: http://localhost:8090/api/

## Step 3: Get Admin API Token

Nicolino needs an admin token to access the Pocketbase API:

1. In Pocketbase Admin UI, go to **Dashboard** (house icon)
2. Click **Collections** in the sidebar
3. Scroll down to **System** and click **_superusers**
4. Click on your superuser account to open it
5. Click the **Impersonate** dropdown in the top-right
6. Set duration to `99999999` seconds (effectively permanent)
7. Click **Generate token**
8. Copy the generated token

**Export the token:**

```bash
export POCKETBASE_ADMIN_TOKEN="paste_token_here"
```

You may want to add this to your `~/.bashrc` or `~/.zshrc` to persist it.

## Step 4: Verify Collections

After logging in, you should see two collections in the sidebar:

- **posts** - For blog posts
- **pages** - For static pages

These were created automatically by the migrations. Click on each to verify they have the correct fields.

## Step 5: Add Import Configuration to conf.yml

Open your site's `conf.yml` and add the `import` section. Add it at the top level, alongside other sections like `site`, `posts`, etc.

```yaml
import:
  posts:
    urls:
      - "http://localhost:8090/api/collections/posts/records"
    feed_format: json
    token: "your-token-here"
    fields:
      title: title
      date: published
      tags: tags
      content: content
      slug: slug
      excerpt: excerpt
    output_folder: posts
    format: html
    template: pocketbase_post.tmpl
    lang: en

  pages:
    urls:
      - "http://localhost:8090/api/collections/pages/records"
    feed_format: json
    token: "your-token-here"
    fields:
      title: title
      content: content
      slug: slug
    static:
      format: html
    output_folder: pages
    format: html
    template: pocketbase_page.tmpl
    lang: en
```

{{% admonition note %}}
If you don't want the token in your `conf.yml` for security reasons, you
can set environment variables `NICOLINO_IMPORT_{FEEDNAME}_TOKEN`
{{% /admonition%}}

## Step 6: Create Test Content in Pocketbase

### Create a Post

1. In Pocketbase Admin UI, click **posts** in the sidebar
2. Click the **+ New** button
3. Fill in the fields:
   - **title**: "My First Post"
   - **content**: "This is my first post from Pocketbase!"
   - **published**: Select today's date
   - **tags**: "test, pocketbase" (optional)
   - **slug**: "my-first-post" (optional)
4. Click **Create**

### Create a Page

1. Click **pages** in the sidebar
2. Click the **+ New** button
3. Fill in the fields:
   - **title**: "About"
   - **content**: "About this site"
   - **slug**: "about"
4. Click **Create**

## Step 7: Import Content

Now import the content from Pocketbase into Nicolino:

```bash
# From your site root (not the pocketbase directory)
./bin/nicolino import
```

You should see output like:

```
[INFO] Importing feed: posts
[INFO] Fetching JSON feed from: http://localhost:8090/api/collections/posts/records
[INFO] Parsed 1 items from http://localhost:8090/api/collections/posts/records
[INFO] Created: content/posts/my-first-post.html
[INFO] Imported 1 posts, skipped 0

[INFO] Importing feed: pages
[INFO] Fetching JSON feed from: http://localhost:8090/api/collections/pages/records
[INFO] Parsed 1 items from http://localhost:8090/api/collections/pages/records
[INFO] Created: content/pages/about.html
[INFO] Imported 1 posts, skipped 0
```

## Step 8: Build Your Site

```bash
./bin/nicolino build
```

Verify the files were created:

```bash
ls content/posts/
# Should see: my-first-post.html

ls content/pages/
# Should see: about.html
```

## Step 9: Serve and View

```bash
./bin/nicolino serve
```

Open http://localhost:8000 in your browser to see your site with the imported content.

## Step 10: Test Updating Content

1. Go back to Pocketbase Admin UI (http://localhost:8090/_/)
2. Edit "My First Post" - change the content
3. Click **Save changes**
4. Run import again: `./bin/nicolino import`
5. You should see "Updated:" instead of "Created:"
6. Build again: `./bin/nicolino build`

The file should be updated with your changes.

## Pocketbase Collections Reference

### Posts Collection

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| title | text | Yes | Post title |
| content | editor | Yes | Post content (HTML/Markdown) |
| published | date | No | Publication date |
| status | select | Yes | "draft" or "published" |
| tags | text | No | Comma-separated tags |
| slug | text | No | URL slug (a-z0-9-) |
| excerpt | editor | No | Short excerpt/summary |
| featured_image | file | No | Featured image upload |

### Pages Collection

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| title | text | Yes | Page title |
| content | editor | Yes | Page content |
| slug | text | Yes | URL slug (must be unique) |
| status | select | Yes | "draft" or "published" |
| sort_order | number | No | Display order |

## Common Docker Commands

```bash
cd pocketbase

# Start Pocketbase
docker compose up -d

# View logs
docker compose logs -f

# Stop Pocketbase
docker compose down

# Restart Pocketbase
docker compose restart
```

## Next Steps

- Add more content in Pocketbase
- Customize the templates in `pocketbase/templates/`
- Set up authentication for production use
- Configure a reverse proxy for production
- Set up automatic deployments on content changes

## Production Considerations

For production use:

1. **Authentication**: Restrict API access in Pocketbase Admin UI under **Settings > API Rules**
2. **Environment Variables**: Store the admin token in environment variables, not in conf.yml
3. **Reverse Proxy**: Use nginx or Caddy in front of Pocketbase
4. **Backups**: Set up automated backups of `pocketbase/pb_data/`
5. **HTTPS**: Enable HTTPS for your Pocketbase instance
