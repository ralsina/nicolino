# VIPS is not available as a static library so for
# easy-to-install release purposes we offer an alternative
# imgkit based thumbnailer.

{% if flag?(:novips) %}
  require "pluto"
  require "pluto/format/jpeg"
  require "pluto/format/stumpy"
  require "stumpy_png"
{% else %}
  require "vips"
{% end %}

module Images
  extend self

  # Optimize VIPS cache for image processing workloads
  def self.init_vips_cache
    return unless @@vips_cache_initialized == false
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

  @@vips_cache_initialized = false

  def thumb(input : String, output : String, size : Int32)
    {% if flag?(:novips) %}
      if File.extname(input).downcase == "png"
        canvas = StumpyPNG.read(input)
        image = Pluto::ImageRGBA.from_stumpy(canvas)
      else
        image = File.open(input) do |file|
          Pluto::ImageRGBA.from_jpeg(file)
        end
      end

      image.bilinear_resize!(size, size)

      io = IO::Memory.new
      if File.extname(input).downcase == "png"
        StumpyPNG.write(image.to_stumpy, io)
      else
        image.to_jpeg(io)
      end
      io.rewind
      File.write(output, io)
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
