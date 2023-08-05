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
    end

    def load
      super
      # FIXME: do conditionally
      Config.languages.keys.each do |lang|
        @metadata[lang]["template"] = "templates/gallery.tmpl"
      end
    end

    # Breadcrumbs is Galleries / this gallery
    # FIXME should be the path
    def breadcrumbs
      [{name: "Galleries", link: "/galleries"}, {name: @title}]
    end

    def value
      {
        "image_list"  => @image_list,
        "breadcrumbs" => breadcrumbs,
      }.merge(super)
    end
  end

  def self.read_all(path)
    Log.info { "Reading galleries from #{path}" }
    galleries = [] of Gallery
    Dir.glob("#{path}/**/index.md").each do |p|
      image_list = Dir.glob(
        Path[p].parent.to_s + "/*.{jpg,png}").map(&.split("/")[-1])
      # FIXME: do properly
      galleries << Gallery.new({"en" => p}, Path[p], image_list)
    end
    galleries
  end

  def self.render(galleries : Array(Gallery), prefix = "")
    galleries.each do |post|
      output = "output/#{prefix}#{post.@link}" # FIXME paths will be wrong
      Croupier::Task.new(
        id: "gallery",
        output: output,
        inputs: [
          "conf",
          post.source,
          "kv://#{post.template}",
          "kv://templates/page.tmpl",
        ] + post.@image_list,
        mergeable: false,
        proc: Croupier::TaskProc.new {
          post.load # Need to refresh post contents
          Log.info { "👉 #{output}" }
          Render.apply_template("templates/page.tmpl",
            {"content" => post.rendered, "title" => post.@title})
        }
      )
    end
  end
end
