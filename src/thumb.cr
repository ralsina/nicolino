# VIPS is not available as a static library so for
# easy-to-install release purposes we offer an alternative
# imgkit based thumbnailer.

{% if flag?(:novips) %}
  require "imgkit"
{% else %}
  require "vips"
{% end %}

module Images
  extend self

  def thumb(input : String, output : String, size : Int32)
    {% if flag?(:novips) %}
      img = ImgKit::Image.new(input)
      if img.width > img.height
        img.resize(width: size)
      else
        img.resize(height: size)
      end
      img.save(output)
    {% else %}
      Vips::Image.thumbnail(
        input,
        width: size,
        height: size,
      ).write_to_file(output)
    {% end %}
  end
end
