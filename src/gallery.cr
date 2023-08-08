require "./markdown"

# Create automatic image galleries
#
# A gallery is a folder in galleries/ that:
# * Has an index.md file
# * Has one or more images
#
# Then:
# * The images are assumed copied and thumbnailed
# * The index.md will be used to build a page
#   with its contents and a nice display of the
#   images below it.
module Gallery
  # An image gallery
  class Gallery < Markdown::File
    def initialize(sources, base, @image_list : Array(String))
      super(sources, base)
      @sources.map { |k, _|
        # Preserve the "galleries/" prefix
        p = Path[base]
        p = Path[Config.options(k).output] / p
        @output[k] = p.to_s.rchop(p.extension) + ".html"
      }
    end

    def load(lang = nil)
      lang ||= Locale.language
      super(lang)
      @metadata[lang]["template"] = "templates/gallery.tmpl"
    end

    # Breadcrumbs is Galleries / this gallery
    # FIXME should be the path
    def breadcrumbs(lang = nil)
      lang ||= Locale.language
      gal_path = Utils.path_to_link(Path[Config.options(lang).output]/Path[@base].parts[0])
      [{name: "Galleries", link: gal_path}, {name: title(lang)}]
    end

    def value(lang = nil)
      lang ||= Locale.language
      super(lang).merge({
        "image_list"  => @image_list,
        "breadcrumbs" => breadcrumbs(lang),
      })
    end
  end

  def self.read_all(path)
    Log.info { "Reading galleries from #{path}" }
    galleries = [] of Gallery
    Utils.find_all(path, "md").map do |base, sources|
      image_list = Dir.glob(
        Path[base].parent.to_s + "/*.{jpg,png}").map(&.split("/")[-1])
      galleries << Gallery.new(sources, base, image_list)
    end
    galleries
  end

  def self.render(galleries : Array(Gallery), prefix = "")
    galleries.each do |post|
      Config.languages.keys.each do |lang|
        Croupier::Task.new(
          id: "gallery",
          output: post.output(lang),
          inputs: [
            "conf.yml",
            post.source(lang),
            "kv://#{post.template(lang)}",
            "kv://templates/page.tmpl",
          ] + post.@image_list,
          mergeable: false,
          proc: Croupier::TaskProc.new {
            post.load(lang) # Need to refresh post contents
            Log.info { "👉 #{post.output(lang)}" }
            Render.apply_template("templates/page.tmpl",
              {"content" => post.rendered(lang), "title" => post.title(lang)})
          }
        )
      end
    end
  end
end
