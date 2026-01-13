# VIPS is not available as a static library so for
# easy-to-install release purposes we offer an alternative
# pure-Crystal thumbnailer using crimage.

{% if flag?(:novips) %}
  require "crimage"
{% else %}
  require "vips"
{% end %}

module Images
  extend self

  @@vips_cache_mutex = Mutex.new
  @@vips_cache_initialized = false

  # Optimize VIPS cache for image processing workloads
  def self.init_vips_cache
    return if @@vips_cache_initialized
    @@vips_cache_mutex.synchronize do
      return if @@vips_cache_initialized
      {% unless flag?(:novips) %}
        # Use all available CPU cores for parallel image processing
        Vips.concurrency = System.cpu_count

        # Optimize cache for thumbnail workloads
        Vips::Cache.max = 1000                              # More operations cached
        Vips::Cache.max_mem = 512_u64 * 1024_u64 * 1024_u64 # 512MB cache (good for thumbnails)
        Vips::Cache.max_files = 1000                        # More files cached
        @@vips_cache_initialized = true
      {% end %}
    end
  end

  def thumb(input : String, output : String, size : Int32)
    {% if flag?(:novips) %}
      img = CrImage.read(input)
      thumb = img.thumb(size)
      CrImage::JPEG.write(output, thumb)
    {% else %}
      init_vips_cache

      Vips::Image.thumbnail(
        input,
        width: size,
        height: size,
        size: Vips::Enums::Size::Down, # Only downsize images (faster)
        no_rotate: true,               # Skip auto-rotation for performance
      ).write_to_file(output,
        Q: 85,      # Good quality with better performance
        strip: true # Remove metadata for faster processing
      )
    {% end %}
  end
end
