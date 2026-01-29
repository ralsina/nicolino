TinaCMS provides a visual content management interface for Nicolino sites, allowing you to create, edit, and manage your content through a web-based admin panel instead of editing files directly.

## What is TinaCMS?

TinaCMS is a Git-based headless content management system that integrates with your static site generator. It provides:

- **Visual Content Editor** - Create and edit posts and pages through a web interface
- **Real-time Preview** - See changes as you make them
- **Git-based Workflow** - All content changes are committed to your Git repository
- **Media Management** - Upload and manage images and other media files
- **No Database Required** - Content is stored as Markdown files in your repository

## Installation

To use TinaCMS with Nicolino, first initialize it in your site:

```bash
nicolino tinacms init
```

This command will:

1. Create the `tina/` configuration directory
2. Set up `package.json` with necessary dependencies
3. Install npm packages automatically
4. Create default TinaCMS configuration files

## Starting the Development Server

After initialization, start the TinaCMS development server along with Nicolino's auto-rebuild mode:

```bash
nicolino tinacms serve
```

This starts two servers:

1. **TinaCMS Admin** at `http://localhost:8080/admin/` - The visual content editor
2. **Nicolino Auto** - Auto-rebuilds your site when content changes

Press `Ctrl+C` to stop both servers.

## Accessing the Admin Interface

Once the server is running, open `http://localhost:8080/admin/` in your browser. You'll see the TinaCMS interface with:

- **Posts** - Manage blog posts
- **Pages** - Manage static pages

## Creating Content

### Creating a Post

1. Click "Posts" in the sidebar
2. Click "New Post"
3. Fill in the fields:
   - **Title** - Post title (required)
   - **Date** - Publication date (required)
   - **Tags** - Comma-separated tags (optional)
   - **Body** - Post content using the rich text editor
4. Click "Save"

The post will be created as a Markdown file in `content/posts/`.

### Editing Content

1. Navigate to Posts or Pages
2. Click on the content you want to edit
3. Make your changes
4. Click "Save"

Changes are saved as Markdown files and trigger an automatic site rebuild.

### Deleting Content

1. Navigate to the content you want to delete
2. Click the delete button
3. Confirm the deletion

## Media Management

TinaCMS includes a media manager for uploading and organizing images:

- Upload images through the TinaCMS interface
- Images are stored in `content/media/`
- Insert images into your content using the media picker

## Configuration

TinaCMS configuration is stored in `tina/config.ts`. The default configuration includes:

- **Collections** - Defines content types (Posts, Pages)
- **Fields** - Defines available fields for each collection
- **Build Settings** - Output directories for the admin interface
- **Media Settings** - Media upload location

You can customize the schema by editing `tina/config.ts` to add:

- New content collections
- Additional fields
- Custom validation rules
- Different content paths

## Git Workflow

All content changes made through TinaCMS are:

1. Saved as Markdown files in your content directory
2. Automatically committed to Git (if configured)
3. Trigger a site rebuild

This means you can:

- Use Git to track all content changes
- Review content changes through pull requests
- Roll back to previous versions if needed
- Deploy content changes through your existing Git workflow

## Production Deployment

For production use, you'll need to:

1. **Set up Tina Cloud** - Go to https://app.tina.io/ and create a project
2. **Configure Authentication** - Add environment variables:
   ```bash
   export TINA_TOKEN=your_token_here
   export NEXT_PUBLIC_TINA_CLIENT_ID=your_client_id_here
   ```
3. **Build for Production** - Run the TinaCMS build command:
   ```bash
   npx @tinacms/cli@latest build
   ```

The build generates the admin interface files in the `tina/__generated__/` directory.

## Files Created

When you run `nicolino tinacms init`, the following files are created:

- `package.json` - npm dependencies
- `tina/config.ts` - TinaCMS configuration
- `tina/tina-lock.json` - Schema lock file (commit this to Git)
- `tina/.gitignore` - Ignores auto-generated files
- `.gitignore` - Updated to exclude `node_modules/`

## Troubleshooting

### "node_modules not found"

Run `npm install` to install dependencies:

```bash
npm install
```

### "TinaCMS not initialized"

Make sure you've run `nicolino tinacms init` first.

### Admin interface not loading

1. Ensure both servers are running (check the terminal output)
2. Clear your browser cache
3. Make sure port 8080 is not in use by another application

### Changes not appearing

- Check that `nicolino auto` is running and rebuilding
- Look for error messages in the terminal output
- Verify the content files were created in `content/`

### Port conflicts

If port 8080 is already in use, you can change the port in your TinaCMS configuration or stop the conflicting service.

## Additional Resources

- [TinaCMS Documentation](https://tina.io/docs/)
- [TinaCMS GitHub](https://github.com/tinacms/tinacms)
- [Nicolino Documentation](index.md)

## Next Steps

- [Learn about the Posts feature](posts.md)
- [Learn about Pages](pages.md)
- [Configure Themes](themes.md)
