# VIPS is not available as a static library so for
# easy-to-install release purposes we offer an alternative
# imgkit based thumbnailer.

{% if flag?(:novips) %}
  require "pluto"
  require "pluto/format/jpeg"
  require "pluto/format/png"
{% else %}
  require "vips"
{% end %}

module Images
  extend self

  def thumb(input : String, output : String, size : Int32)
    {% if flag?(:novips) %}
      image = File.open(input) do |file|
        if File.extname(input).downcase == "png"
          Pluto::ImageRGBA.from_png(file)
        else
          Pluto::ImageRGBA.from_jpeg(file)
        end
      end
      image.bilinear_resize!(size, size)

      io = IO::Memory.new
      if File.extname(input).downcase == "png"
        image.to_png(io)
      else
        image.to_jpeg(io)
      end
      io.rewind
      File.write(output, io)
    {% else %}
      Vips::Image.thumbnail(
        input,
        width: size,
        height: size,
      ).write_to_file(output)
    {% end %}
  end
end
