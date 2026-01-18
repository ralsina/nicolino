# Galleries

The Galleries feature creates image gallery pages with automatic thumbnail generation and lightbox functionality.

## How It Works

Place images in a directory, and Nicolino will:

1. Copy full-size images to the output
2. Generate thumbnails for each image
3. Create a gallery page with thumbnails
4. Enable lightbox viewing for full-size images

## Directory Structure

Create gallery directories in `content/galleries/`:

```
content/galleries/
  my-gallery/
    image1.jpg
    image2.png
    image3.webp
  vacation/
    photo1.jpg
    photo2.jpg
```

## Output

Each gallery generates:

```
output/galleries/
  my-gallery/
    index.html          # Gallery page
    image1.jpg          # Full-size images
    image1.thumb.jpg    # Thumbnails
    image2.jpg
    image2.thumb.jpg
  vacation/
    index.html
    ...
```

## Gallery Content

Add a `description.md` file to provide gallery introduction:

<pre><code class="language-yaml">---
title: My Photo Gallery
---

# My Gallery

A collection of my favorite photos.
</code></pre>

Place this in the gallery directory:

```
content/galleries/my-gallery/
  description.md
  image1.jpg
  image2.jpg
```

## Image Sizes

Configure image sizes in `conf.yml`:

```yaml
image_large: 1920  # Full-size max dimension
image_thumb: 640   # Thumbnail max dimension
```

## Lightbox

Galleries include [VenoBox](https://veno.es/venobox/) lightbox functionality:

- Click any thumbnail to view full-size
- Navigate between images with arrows
- Keyboard support (arrow keys, ESC)

## Configuration

Enable the Galleries feature in `conf.yml`:

```yaml
features:
  - galleries
```

**Gallery-specific options:**
```yaml
galleries: "galleries/"  # Directory name within content/
```

## Supported Image Formats

- JPEG (`.jpg`, `.jpeg`)
- PNG (`.png`)
- WebP (`.webp`)
- GIF (`.gif` - thumbnails use first frame)

## Gallery Index

A gallery index page is automatically generated at `/galleries/` listing all available galleries.
