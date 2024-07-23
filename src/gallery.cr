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
      Markdown::File.posts[base.to_s] = self
      # Patch title if it's missing, special case for galleries
      Config.languages.keys.each do |lang|
        if @title[lang].empty?
          # Use folder name
          @title[lang] = base.parts[-2].capitalize
        end
      end
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
    Log.debug { "Reading galleries from #{path}" }
    galleries = [] of Gallery
    Utils.find_all(path, "md").map do |base, sources|
      image_list = Dir.glob(
        Path[base].parent.to_s + "/*.{jpg,png}").map(&.split("/")[-1])
      galleries << Gallery.new(sources, base, image_list)
    end
    galleries
  end

  def self.render(galleries : Array(Gallery), prefix = "")
    Config.languages.keys.each do |lang|
      galleries.each do |post|
        basedir = File.dirname(post.source)
        Croupier::Task.new(
          id: "gallery",
          output: post.output(lang),
          inputs: [
            "conf.yml",
            post.source(lang),
            "kv://#{post.template(lang)}",
            "kv://templates/page.tmpl",
          ] + post.@image_list.map { |i| "#{basedir}/#{i}" },
          mergeable: false) do
          # Need to refresh post contents in auto mode
          post.load(lang) if Croupier::TaskManager.auto_mode?
          Log.info { "👉 #{post.output(lang)}" }
          html = Render.apply_template("templates/page.tmpl",
            {"content" => post.rendered(lang), "title" => post.title(lang)})
          doc = Lexbor::Parser.new(html)
          doc = HtmlFilters.make_links_relative(doc, post.output(lang))
          doc.to_html
        end
      end
    end
  end

  # Create a new gallery
  def self.new_gallery(path)
    raise "Galleries are folders, not documents" if path.to_s.ends_with? ".md"
    path = path / "index.md"
    Log.info { "Creating new gallery #{path}" }
    raise "#{path} already exists" if ::File.exists? path
    Dir.mkdir_p(path.dirname)
    ::File.open(path, "w") do |io|
      io << Crinja.render(::File.read(Path["models", "page.tmpl"]), {date: "#{Time.local}"})
    end
  end
end
