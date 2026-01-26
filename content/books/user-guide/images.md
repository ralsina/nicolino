The Images feature processes individual images with automatic optimization and size generation.

## How It Works

Place images in your content directory, and Nicolino will:

1. Optimize images for web
2. Generate thumbnail and large versions
3. Copy processed images to the output directory

## Directory Structure

Images can be placed anywhere in your content directory:

```
content/
  images/
    photo.jpg
  posts/
    my-post/
      hero.png
  about/
    team-photo.webp
```

## Image Processing

Images are processed to generate two sizes:

- **Thumbnail** - Smaller version (default: 640px max dimension)
- **Large** - Full/high-resolution version (default: 1920px max dimension)

For example, `content/images/photo.jpg` generates:

```
output/
  images/
    photo.jpg      # Large version (1920px)
    photo.thumb.jpg # Thumbnail version (640px)
```

## Usage in Markdown

Reference images in your markdown content:

```markdown
![Alt text](/images/photo.jpg)
```

Note: You need to manually reference the thumbnail version if you want to use it:

```markdown
![Alt text](/images/photo.thumb.jpg)
```

## Configuration

Enable the Images feature in `conf.yml`:

```yaml
features:
  - images
```

**Image size options:**
```yaml
image_large: 1920   # Max dimension for large images (default)
image_thumb: 640    # Max dimension for thumbnails (default)
```

## Supported Formats

- JPEG (`.jpg`, `.jpeg`)
- PNG (`.png`)
- WebP (`.webp`)
- GIF (`.gif` - not optimized, copied as-is)
- SVG (`.svg` - copied as-is, not processed)

## Image Paths

Images maintain their directory structure from content/ to output/:

```
content/
  images/
    logo.png
    posts/
      hero.jpg
```

Becomes:

```
output/
  images/
    logo.png         # Large version
    logo.thumb.png   # Thumbnail version
    posts/
      hero.jpg       # Large version
      hero.thumb.jpg # Thumbnail version
```

## Optimization

Images are automatically optimized using libvips:

- Reduced file size while maintaining quality
- Proper metadata stripping
- Efficient compression

## Caching

Images are only reprocessed when the source file changes, thanks to Croupier's incremental build system.
