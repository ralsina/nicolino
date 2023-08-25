require "vips"

module Image
  # An image to be processed
  struct Image
    property path : Path

    def initialize(path)
      @path = Path[path]
    end

    # Images are copied 2x:
    # image.jpg => image.jpg       (size is options.image_large)
    # image.jpg => image.thumb.jpg (size is options.image_thumb)
    #
    # prefix affects destination path:
    # foo/bar/bat.jpg => output/#{prefix}/bar/bat.jpg
    def render(prefix = "")
      src = @path.to_s
      dest = Path[Config.options.output] / prefix / Path[@path.parts[1..]]
      Croupier::Task.new(
        id: "image",
        output: dest.to_s,
        inputs: ["conf.yml", src],
        no_save: true,
        mergeable: false) do
        Log.info { "👉 #{dest}" }
        Dir.mkdir_p(dest.parent)
        img = Vips::Image.thumbnail(
          src,
          Config.options.image_large,
          height: Config.options.image_thumb)
        img.write_to_file(dest.to_s)
        nil
      end
      thumb_dest = Path[dest.parent, dest.stem + ".thumb" + dest.extension]
      Croupier::Task.new(
        id: "thumb",
        output: thumb_dest.to_s,
        inputs: ["conf.yml", src],
        no_save: true,
        mergeable: false) do
        Log.info { "👉 #{thumb_dest}" }
        Dir.mkdir_p(thumb_dest.parent)
        img = Vips::Image.thumbnail(
          src,
          Config.options.image_thumb,
          height: Config.options.image_thumb)
        img.write_to_file(thumb_dest.to_s)
        nil
      end
    end
  end

  # Finds all images in a path and build Image objects out of them
  def self.read_all(path)
    Log.info { "Reading Images from #{path}" }
    images = [] of Image
    Dir.glob("#{path}/**/*.{jpg,jpeg,png}").each do |p|
      Log.info { "👈 #{p}" }
      images << Image.new(p)
    end
    images
  end

  def self.render(images, prefix = "")
    images.each(&.render(prefix))
  end
end
