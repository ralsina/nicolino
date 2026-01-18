require "./markdown"

# Create automatic image galleries
#
# A gallery is a folder in galleries/ that:
# * Has an index.md file
# * Has one or more images and/or sub-galleries
#
# Then:
# * The images are assumed copied and thumbnailed
# * The index.md will be used to build a page
#   with its contents and a nice display of the
#   images and sub-galleries below it.
module Gallery
  # Register output folder to exclude from folder_indexes
  FolderIndexes.register_exclude("galleries/")

  # Enable galleries feature
  def self.enable(is_enabled : Bool, galleries_path : Path)
    return unless is_enabled

    # Render galleries
    galleries = read_all(galleries_path)
    render(galleries, Config.options.galleries)
  end

  # An image gallery
  class Gallery < Markdown::File
    property sub_galleries : Array(Gallery)
    property parent_gallery : Gallery?
    property base : Path

    def initialize(sources, base, @image_list : Array(String), @sub_galleries : Array(Gallery) = [] of Gallery)
      @base = base
      super(sources, base)
      @parent_gallery = nil
      Markdown::File.posts[base.to_s] = self

      # Patch title if it's missing, special case for galleries
      Config.languages.keys.each do |lang|
        if @title[lang].empty?
          # Use folder name
          @title[lang] = base.parts[-2].capitalize
        end
      end

      # Set parent relationships for sub-galleries
      @sub_galleries.each(&.parent_gallery=(self))
    end

    def load(lang = nil)
      lang ||= Locale.language
      super(lang)
      @metadata[lang]["template"] = "templates/gallery.tmpl"
    end

    # Generate hierarchical breadcrumbs showing full gallery path
    def breadcrumbs(lang = nil)
      lang ||= Locale.language
      breadcrumbs = [] of NamedTuple(name: String, link: String)

      # Add "Home" first
      breadcrumbs << {name: "Home", link: "/"}

      # Add "Galleries" root
      gal_path = "/galleries/"
      breadcrumbs << {name: "Galleries", link: gal_path}

      # Build path hierarchy
      path_parts = [] of String
      current = @parent_gallery

      # Collect parent galleries
      while current
        path_parts.unshift(current.title(lang))
        current = current.parent_gallery
      end

      # Add parent gallery breadcrumbs
      current = @parent_gallery

      while current
        gallery_dir = current.output(lang).sub(/\/index\.html$/, "")
        gallery_link = Utils.path_to_link(Path[gallery_dir])
        breadcrumbs << {name: current.title(lang), link: gallery_link}
        current = current.parent_gallery
      end

      # Add current gallery
      breadcrumbs << {name: title(lang), link: ""}

      breadcrumbs
    end

    def value(lang = nil)
      lang ||= Locale.language
      {
        "breadcrumbs"       => breadcrumbs(lang),
        "date"              => date.try &.as(Time).to_s(Config.options(lang).date_output_format),
        "html"              => html(lang),
        "link"              => link(lang),
        "source"            => source(lang),
        "summary"           => summary(lang),
        "taxonomies"        => taxonomies,
        "title"             => title(lang),
        "toc"               => toc(lang),
        "metadata"          => metadata(lang),
        "image_list"        => @image_list,
        "has_sub_galleries" => has_sub_galleries?.to_s,
        "has_images"        => has_images?.to_s,
        "language_links"    => language_links(lang),
      }
    end

    # Helper methods for template rendering
    def has_sub_galleries?
      !@sub_galleries.empty?
    end

    def has_images?
      !@image_list.empty?
    end

    def language_links(lang : String? = nil)
      lang ||= Locale.language
      result = [] of Hash(String, String)

      # For galleries, language links point to the parent gallery's alternate language index pages
      if @parent_gallery
        # Get the parent gallery's language links
        result.concat(@parent_gallery.language_links(lang))
      else
        # This is a root-level gallery, so we don't have language alternates
        # Just return empty array
      end

      result
    end

    def depth
      current = @parent_gallery
      depth = 0
      while current
        depth += 1
        current = current.parent_gallery
      end
      depth
    end
  end

  # Recursively scan directory and build gallery tree structure
  private def self.scan_gallery_directory(dir_path : Path, parent_gallery : Gallery? = nil) : Array(Gallery)
    galleries = [] of Gallery

    # Look for index.md files (gallery definitions)
    Dir.glob("#{dir_path}/*/index.md").each do |index_file|
      gallery_dir = Path[index_file].parent
      gallery_base = Path[index_file]

      # Find images in this gallery directory (not subdirectories)
      image_list = Dir.glob("#{gallery_dir}/*.{jpg,png,webp,gif}").map do |img_path|
        Path[img_path].basename.to_s
      end

      # Create gallery with empty sub-galleries for now
      gallery = Gallery.new([index_file], gallery_base, image_list)
      galleries << gallery
    end

    # Now scan for sub-galleries recursively and build parent-child relationships
    galleries.each do |gallery|
      gallery_dir = Path[gallery.base].parent

      # Find sub-galleries (directories with index.md)
      sub_galleries = scan_gallery_directory(gallery_dir, gallery)
      gallery.sub_galleries = sub_galleries
    end

    galleries
  end

  def self.read_all(path)
    Log.debug { "Reading galleries from #{path}" }

    # First pass: scan the entire directory tree and collect all galleries
    all_galleries = [] of Gallery

    # Use Utils.find_all to properly find and group gallery files
    gallery_sources = Utils.find_all(path, "md")

    # Filter to only include index.md files (galleries)
    gallery_sources.each do |base, sources|
      if base.basename == "index"
        gallery_dir = base.parent

        # Find images in this gallery directory (not subdirectories)
        image_list = Dir.glob("#{gallery_dir}/*.{jpg,png,webp,gif}").map do |img_path|
          Path[img_path].basename.to_s
        end

        gallery = Gallery.new(sources, base, image_list)
        all_galleries << gallery
      end
    end

    # Build parent-child relationships using hash map for O(n) lookup
    gallery_by_dir = all_galleries.to_h { |gallery| {Path[gallery.base].parent, gallery} }

    all_galleries.each do |gallery|
      gallery_dir = Path[gallery.base].parent
      parent_dir = gallery_dir.parent

      if potential_parent = gallery_by_dir[parent_dir]?
        gallery.parent_gallery = potential_parent
        potential_parent.sub_galleries << gallery unless potential_parent.sub_galleries.includes?(gallery)
      end
    end

    # Return only root-level galleries (those without parents)
    all_galleries.select { |gallery| gallery.parent_gallery.nil? }
  end

  # Recursively collect all galleries in the tree
  private def self.collect_all_galleries(galleries : Array(Gallery)) : Array(Gallery)
    all_galleries = [] of Gallery

    galleries.each do |gallery|
      all_galleries << gallery
      all_galleries.concat(collect_all_galleries(gallery.sub_galleries))
    end

    all_galleries
  end

  def self.render(galleries : Array(Gallery), prefix = "")
    # Collect all galleries in the tree to render them all
    all_galleries = collect_all_galleries(galleries)

    # First, render the main galleries index page
    render_galleries_index(galleries, prefix)

    # Then render all individual gallery pages
    Config.languages.keys.each do |lang|
      all_galleries.each do |post|
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
          template_context = {
            "content"        => post.rendered(lang),
            "title"          => post.title(lang),
            "breadcrumbs"    => post.breadcrumbs(lang),
            "language_links" => post.language_links(lang),
          }
          html = Render.apply_template("templates/page.tmpl", template_context)
          doc = Lexbor::Parser.new(html)
          doc = HtmlFilters.make_links_relative(doc, post.output(lang))
          doc.to_html
        end
      end
    end
  end

  # Render the main galleries index page
  private def self.render_galleries_index(galleries : Array(Gallery), prefix = "")
    Config.languages.keys.each do |lang|
      # Make output path language-specific to avoid conflicts
      lang_suffix = lang == "en" ? "" : ".#{lang}"
      galleries_dir = prefix.empty? ? "galleries" : "#{prefix}/galleries"
      output_path = Path[Config.options(lang).output] / "#{galleries_dir}#{lang_suffix}" / "index.html"

      Croupier::Task.new(
        id: "galleries_index",
        output: output_path.to_s,
        inputs: ["conf.yml", "kv://templates/page.tmpl", "kv://templates/title.tmpl"],
        mergeable: false
      ) do
        Log.info { "👉 #{output_path}" }

        # Create breadcrumbs for galleries index
        galleries_link = "/galleries#{lang_suffix}/"
        breadcrumbs = [{name: "Home", link: "/"}, {name: "Galleries", link: galleries_link}] of NamedTuple(name: String, link: String)

        # Include title.tmpl which handles breadcrumbs
        title_html = Templates.environment.get_template("templates/title.tmpl").render({
          "title"       => "Galleries",
          "link"        => galleries_link,
          "breadcrumbs" => breadcrumbs,
          "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
        })

        # Build items list for the template
        items = galleries.map do |gallery|
          gallery_output = gallery.output(lang)
          gallery_dir = File.dirname(gallery_output)
          gallery_link = gallery_dir.gsub(/^output\//, "/")
          {link: gallery_link, title: gallery.title(lang)}
        end

        # Render the item list template
        content = Templates.environment.get_template("templates/item_list.tmpl").render({
          "title"       => "Galleries",
          "description" => "A collection of image galleries.",
          "items"       => items,
        })

        html = Render.apply_template("templates/page.tmpl", {
          "content"     => title_html + content,
          "title"       => "Galleries",
          "breadcrumbs" => breadcrumbs,
        })
        doc = Lexbor::Parser.new(html)
        doc = HtmlFilters.make_links_relative(doc, output_path.to_s)
        doc.to_html
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
