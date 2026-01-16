# Images

The Images feature processes individual images with automatic optimization and responsive size generation.

## How It Works

Place images in your content directory, and Nicolino will:

1. Optimize images for web
2. Generate multiple sizes for responsive design
3. Create appropriate HTML `<img>` tags with `srcset` attributes

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

Images are processed to generate multiple sizes:

- **Thumbnail** - Small version for previews
- **Medium** - Standard display size
- **Large** - Full/high-resolution version

## Usage in Markdown

Reference images in your markdown content:

```markdown
![Alt text](/images/photo.jpg)
```

The rendered HTML includes responsive `srcset`:

```html
<img src="/images/photo.jpg"
     srcset="/images/photo.thumb.jpg 640w,
             /images/photo.medium.jpg 1280w,
             /images/photo.large.jpg 1920w"
     alt="Alt text">
```

## Configuration

Enable the Images feature in `conf.yml`:

```yaml
features:
  - images
```

**Image size options:**
```yaml
image_large: 1920   # Max dimension for large images
image_thumb: 640    # Max dimension for thumbnails
```

## Supported Formats

- JPEG (`.jpg`, `.jpeg`)
- PNG (`.png`)
- WebP (`.webp`)
- GIF (`.gif` - not optimized, copied as-is)
- SVG (`.svg` - copied as-is, not processed)

## Image Paths

Images maintain their directory structure:

```
content/
  images/
    logo.png
```

Becomes:

```
output/
  images/
    logo.png
    logo.thumb.png
    logo.medium.png
    logo.large.png
```

## Optimization

Images are automatically optimized using libvips:

- Reduced file size while maintaining quality
- Proper metadata stripping
- Efficient compression

## Caching

Images are only reprocessed when the source file changes, thanks to Croupier's incremental build system.
