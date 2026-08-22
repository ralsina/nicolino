require "./markdown"
require "./theme"
require "./render"
require "json"
require "crinja"

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
  FolderIndexes.register_exclude { Config.galleries }

  # Return glob patterns for gallery content
  # Galleries are index.md files inside galleries/
  def self.content_globs : Array(String)
    galleries_path = Path[Config.options.content] / Config.options.galleries
    ["#{galleries_path}/**/*.md"]
  end

  # For gallery folders that contain images but no index.md, generate a
  # minimal index.md so they render as galleries too (issue #49). A folder
  # is treated as a gallery if it directly contains images. Idempotent:
  # existing index.md files are left untouched, and a generated file is
  # only written once so auto-mode rebuilds settle.
  def self.ensure_index_files
    root = (Path[Config.options.content] / Config.options.galleries).normalize
    return unless ::Dir.exists?(root)

    Dir.glob("#{root}/**/").each do |dir_str|
      dir = Path[dir_str].normalize
      next if dir == root
      index_md = dir / "index.md"
      next if ::File.exists?(index_md)
      next if Dir.glob("#{dir}/*.{jpg,png,webp,gif}").empty?
      ::File.write(index_md, "---\ntitle: #{dir.basename.capitalize}\n---\n\n")
      Log.info { "🖼️  Generated #{index_md} for image-only gallery" }
    end
  end

  # Create a Gallery object from source files
  def self.create_file(sources : Hash(String, String), base : Path) : Markdown::File?
    # Only index.md files are galleries
    return unless base.basename == "index"

    gallery_dir = base.parent
    image_list = Dir.glob("#{gallery_dir}/*.{jpg,png,webp,gif}").map do |img_path|
      Path[img_path].basename.to_s
    end
    result = ::Gallery::Gallery.new(sources, base, image_list)
    result.as(Markdown::File)
  rescue ex
    Log.error { "Error creating gallery #{base}: #{ex.message}" }
    Log.debug { ex }
    nil
  end

  # Create a new gallery folder with an index.md
  def self.create(path : Path)
    raise "Galleries are folders, not documents" if path.to_s.ends_with?(".md")
    gallery_path = path / "index.md"
    Log.info { "Creating new gallery #{gallery_path}" }
    raise "#{gallery_path} already exists" if ::File.exists?(gallery_path)
    Dir.mkdir_p(gallery_path.dirname)
    ::File.open(gallery_path, "w") do |io|
      template = <<-TEMPLATE
        ---
        title: Add title here
        date: {{date}}
        ---

        Add content here
        TEMPLATE
      io << Crinja.render(template, {date: Time.local.to_s})
    end
  end

  # Enable galleries feature using pre-scanned files
  def self.enable_from_scan(scan_result : Array(Markdown::File)?, feature_set : Set(String))
    return unless scan_result
    return if scan_result.empty?

    Log.info { "🖼️  Scanning for galleries..." }

    # Cast to Gallery objects
    galleries = scan_result.select(::Gallery::Gallery).map(&.as(::Gallery::Gallery))

    # Build parent-child relationships
    gallery_by_dir = galleries.to_h { |gallery| {Path[gallery.base].parent, gallery} }
    galleries.each do |gallery|
      parent_dir = gallery.base.parent.parent
      if potential_parent = gallery_by_dir[parent_dir]?
        gallery.parent_gallery = potential_parent
        potential_parent.sub_galleries << gallery unless potential_parent.sub_galleries.includes?(gallery)
      end
    end

    # Only root-level galleries
    root_galleries = galleries.select { |gallery| gallery.parent_gallery.nil? }

    Log.info { "✓ Found #{root_galleries.size} galler#{root_galleries.size == 1 ? "y" : "ies"}" }
    render(root_galleries, Config.options.galleries)
  end

  # An image gallery
  class Gallery < Markdown::File
    property sub_galleries : Array(Gallery)
    property parent_gallery : Gallery?
    property base : Path
    property image_list : Array(String)

    def initialize(sources, base, @image_list : Array(String), @sub_galleries : Array(Gallery) = [] of Gallery)
      @base = base
      super(sources, base)
      @parent_gallery = nil
      Markdown.posts[base.to_s] = self

      # Patch title if it's missing, special case for galleries
      Config.languages.each do |lang|
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
      @metadata[lang]["template"] = Theme.template_path("gallery.tmpl")
    end

    # Generate hierarchical breadcrumbs showing full gallery path
    def breadcrumbs(lang = nil)
      lang ||= Locale.language
      breadcrumbs = [] of NamedTuple(name: String, link: String)

      # Add "Home" first
      breadcrumbs << {name: "Home", link: "/"}

      # Add "Galleries" root
      gal_path = "/#{Config.galleries}"
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
      if parent = @parent_gallery
        # Get the parent gallery's language links
        result.concat(parent.language_links(lang))
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
    Config.languages.each do |lang|
      all_galleries.each do |post|
        basedir = File.dirname(post.source)
        page_template = Theme.template_path("page.tmpl")

        # Create unique task ID for this gallery and language
        gallery_dir = Path[post.base].parent
        gallery_rel_path = gallery_dir.relative_to(Config.options.content).to_s
        task_id = "gallery_#{lang}_#{gallery_rel_path.gsub("/", "_")}"

        FeatureTask.new(
          feature_name: "galleries",
          id: task_id,
          output: post.output(lang),
          inputs: [
            "conf.yml",
            post.source(lang),
            "kv://#{post.template(lang)}",
            "kv://#{page_template}",
          ] + post.shortcode_dependencies(lang) +
                  post.@image_list.map { |i| "#{basedir}/#{i}" } +
                  LuaFilters.dependency_paths,
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
          page_template = Theme.template_path("page.tmpl")
          html = Render.apply_template(page_template, template_context, lang)
          doc = Lexbor::Parser.new(html)
          doc = HtmlFilters.make_links_relative(doc, post.output(lang))
          doc.to_html
        end

        # Create gallery.json for this gallery (only once, not per language)
        # gallery.json is just file data, no translatable content
        # Get the gallery directory from the output path
        gallery_output_dir = Path[post.output(lang)].parent
        gallery_json_path = gallery_output_dir / "gallery.json"

        # Get the gallery URL path for use in shortcodes
        # post.base is something like "content/galleries/fancy-turning/index.md"
        # We need to convert to "/galleries/fancy-turning/"
        gallery_dir = Path[post.base].parent
        gallery_rel_path = "/" + gallery_dir.relative_to(Config.options.content).to_s

        # Only create gallery.json once (use first language or skip if already created)
        # We use a Set to track which galleries we've already created JSON for
        gallery_json_task_id = "gallery_json_#{gallery_rel_path.gsub("/", "_")}"

        # Check if we've already scheduled this task by looking at output path
        # Since we're inside the language loop, we need to ensure we only create it once
        # The trick: use mergeable: true so Croupier can handle duplicates
        FeatureTask.new(
          feature_name: "galleries",
          id: gallery_json_task_id,
          output: gallery_json_path.to_s,
          inputs: ["conf.yml", post.source(lang)] + post.@image_list.map { |i| "#{basedir}/#{i}" },
          mergeable: true
        ) do
          # Build gallery JSON data (no language-specific content)
          gallery_data = {
            "name"   => Path[post.base].basename.to_s,
            "images" => post.@image_list.map do |img|
              # Generate thumbnail filename: image.jpg -> image.thumb.jpg
              ext = File.extname(img)
              base_name = img.sub(ext, "")
              thumb_name = "#{base_name}.thumb#{ext}"

              {
                "filename" => img,
                "url"      => "#{gallery_rel_path}/#{img}",
                "thumb"    => "#{gallery_rel_path}/#{thumb_name}",
              }
            end,
            "sub_galleries" => post.sub_galleries.map do |sub|
              {
                "name" => Path[sub.base].basename.to_s,
                "url"  => "/" + Path[sub.base].parent.relative_to(Config.options.content).to_s,
              }
            end,
          }
          gallery_data.to_json
        end
      end
    end
  end

  # Render the main galleries index page
  private def self.render_galleries_index(galleries : Array(Gallery), prefix = "")
    Config.languages.each do |lang|
      # Make output path language-specific to avoid conflicts
      lang_suffix = Utils.lang_suffix(lang)
      galleries_dir = prefix.empty? ? "galleries" : prefix
      output_path = Path[Config.options(lang).output] / "#{galleries_dir}#{lang_suffix}" / "index.html"

      page_template = Theme.template_path("page.tmpl")
      title_template = Theme.template_path("title.tmpl")

      FeatureTask.new(
        feature_name: "galleries",
        id: "galleries_index",
        output: output_path.to_s,
        inputs: ["conf.yml", "kv://#{page_template}", "kv://#{title_template}"] + LuaFilters.dependency_paths,
        mergeable: false
      ) do
        Log.info { "👉 #{output_path}" }

        # Create breadcrumbs for galleries index
        galleries_link = "/galleries#{lang_suffix}/"
        breadcrumbs = Render.section_breadcrumbs("Galleries", galleries_link)

        # Include title.tmpl which handles breadcrumbs
        title_html = Render.title_html("Galleries", galleries_link, breadcrumbs)

        # Build items list for the template with first image for each gallery
        items = galleries.map do |gallery|
          gallery_output = gallery.output(lang)
          gallery_dir = File.dirname(gallery_output)
          gallery_link = Utils.path_to_link(gallery_dir)
          # Get first image if available and construct full path
          # image_list contains just basenames, so we need to add the gallery directory
          first_image = gallery.image_list.first?
          thumb_link = nil
          if first_image
            # Construct the full path: /galleries/fancy-turning/lathe-patterns-00030.jpg
            # The gallery_dir is like "output/galleries/fancy-turning"
            # We need to convert to link path and add the image basename
            thumb_link = "#{gallery_link}/#{File.basename(first_image)}"
          end
          {
            link:       gallery_link,
            title:      gallery.title(lang),
            thumb_link: thumb_link,
          }
        end

        # Render the gallery cards template
        gallery_cards_template = Theme.template_path("gallery_cards.tmpl")
        content = Templates.environment.get_template(gallery_cards_template).render({
          "title"       => "Galleries",
          "description" => "A collection of image galleries.",
          "items"       => items,
        })

        Render.page_html(output_path.to_s, title_html + content, "Galleries", breadcrumbs, lang)
      end
    end
  end
end
