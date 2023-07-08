require "pixie"

module Image
  struct Image
    property path : Path

    def initialize(path)
      @path = Path[path]
    end

    # Calculates the new size of an image, given the original size and the
    # desired new size. The new size is calculated so that the aspect ratio
    # is preserved.
    # If the image is smaller than new_size, then it's kept in the same size.
    def new_size(w, h, new_size)
      return [w, h] if w <= new_size && h <= new_size
      if w > h
        h = (h * new_size) / w
        w = new_size
      else
        w = (w * new_size) / h
        h = new_size
      end
      return w.to_i, h.to_i
    end

    # Images are copied 2x:
    # image.jpg => image.jpg       (size is options.image_large)
    # image.jpg => image.thumb.jpg (size is options.image_thumb)
    def render
      src = @path.to_s
      dest = Path.new(["output/"] + @path.parts[1..])
      Croupier::Task.new(
        output: dest.to_s,
        inputs: ["conf", src],
        no_save: true,
        proc: Croupier::TaskProc.new {
          Log.info { ">> #{dest}" }
          Dir.mkdir_p(dest.parent)
          img = Pixie::Image.new(src)
          w, h = new_size(img.width, img.height, Config.options.image_large)
          Log.debug { "Resizing #{src} to #{w}x#{h}" }
          if w != img.width || h != img.height
            img.resize(w, h)
          end
          img.write(dest.to_s)
          nil
        }
      )

      Croupier::Task.new(
        output: dest.to_s,
        inputs: ["conf", src],
        no_save: true,
        proc: Croupier::TaskProc.new {
          ext = dest.extension
          thumb_name = dest.stem + ".thumb" + ext
          dest = Path[dest.parent, thumb_name]
          Log.info { ">> #{dest}" }
          Dir.mkdir_p(dest.parent)
          img = Pixie::Image.new(src)
          w, h = new_size(img.width, img.height, Config.options.image_thumb)
          Log.debug { "Resizing #{src} to #{w}x#{h}" }
          if w != img.width || h != img.height
            img.resize(w, h)
          end
          img.write(dest.to_s)
          nil
        }
      )
    end
  end

  # Finds all images in a path and build Image objects out of them
  def self.read_all(path)
    Log.info { "Reading Images from #{path}" }
    images = [] of Image
    Dir.glob("#{path}/**/*.{jpg,jpeg,png}").each do |p|
      Log.debug { "<< #{p}" }
      images << Image.new(p)
    end
    images
  end

  def self.render(images)
    images.each(&.render)
  end
end
