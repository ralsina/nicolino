# Pages helper module for enabling pages feature
# This module reads and renders static pages from multiple sources

require "./markdown"
require "./html"
require "./pandoc"
require "./creatable"
require "./render"
require "./html_filters"
require "./theme"

module Pages
  # Directories that generate their own indexes (excluded from page folder indexes)
  EXCLUDED_DIRECTORIES = ["posts", "galleries", "listings", "books"]

  # Enable pages feature
  # Render pages last because it's a catchall and will find gallery
  # posts, blog posts, etc.
  def self.enable(is_enabled : Bool, content_path : Path, feature_set : Set(Totem::Any))
    return unless is_enabled

    # Note: Pages are already registered by nicolino new command,
    # but features can register additional types here if needed

    # Convert Totem::Any set to string set for easier use
    features = feature_set.map(&.as_s).to_set

    # Read pages from multiple sources
    pages = Markdown.read_all(content_path)
    pages += HTML.read_all(content_path)
    pages += Pandoc.read_all(content_path) if features.includes?("pandoc")

    # Render pages without requiring dates
    Markdown.render(pages, require_date: false)

    # Generate folder indexes for page directories
    generate_folder_indexes(content_path) if features.includes?("folder_indexes")
  end

  # Generate folder indexes for page directories (non-posts, non-feature folders)
  def self.generate_folder_indexes(content_path : Path)
    Log.info { "📁 Scanning for page folder indexes..." }

    content_path = content_path.expand
    indexes = scan_page_directories(content_path)

    Log.info { "✓ Found #{indexes.size} page folder index#{indexes.size == 1 ? "" : "es"}" }
    render_indexes(indexes, content_path)
  end

  # Scan for page directories that need indexes
  def self.scan_page_directories(content_path : Path) : Array(PageFolderIndex)
    indexes = [] of PageFolderIndex
    candidates = [content_path] + Dir.glob("#{content_path}/**/*/")

    candidates.each do |folder|
      folder_path = Path.new(folder)

      # Skip hidden directories
      next if folder_path.basename.to_s.starts_with?(".")

      # Get the relative path from content directory
      begin
        relative_path = folder_path.relative_to(content_path)
      rescue
        # Can't make relative - probably outside content path
        next
      end

      # Skip excluded directories (they generate their own indexes)
      first_part = relative_path.parts.first?
      next if first_part && EXCLUDED_DIRECTORIES.includes?(first_part)

      # Check if any task already produces this folder's index.html
      temp_index = PageFolderIndex.new(folder_path, content_path)
      expected_output = Path[Config.options.output] / temp_index.output

      has_task_for_output = Croupier::TaskManager.tasks.values.any? do |task|
        task.outputs.includes?(expected_output.to_s)
      end

      # Check if there's a .noindex file to exclude this folder
      has_noindex = File.file?("#{folder}/.noindex")

      if has_task_for_output
        Log.debug { "Skipping #{folder}: index.html already produced by another task" }
      elsif has_noindex
        Log.debug { "Skipping #{folder}: .noindex found" }
      else
        Log.debug { "👈 #{folder}" }
        indexes << temp_index
      end
    end

    indexes
  end

  # Render all page folder indexes
  def self.render_indexes(indexes : Array(PageFolderIndex), content_path : Path)
    Config.languages.keys.each do |lang|
      out_path = Path.new(Config.options(lang).output)
      lang_suffix = lang == "en" ? "" : ".#{lang}"

      indexes.each do |index|
        # Add language suffix to output path
        output_path = index.output.to_s.sub(/\.html$/, "#{lang_suffix}.html")
        output = (out_path / output_path).to_s

        # All markdown posts are dependencies since we use the global registry
        all_posts = Markdown::File.posts.map(&.last.source)

        folder_index_template = Theme.template_path("folder_index.tmpl")
        inputs = ["kv://#{folder_index_template}", "conf.yml"] + all_posts

        # Use unique task ID based on output path and language
        task_id = "page_folder_index::#{lang}::#{index.output}"
        Croupier::Task.new(
          id: task_id,
          output: output,
          inputs: inputs,
          mergeable: false
        ) do
          Log.info { "👉 #{output}" }
          page_template = Theme.template_path("page.tmpl")
          html = Render.apply_template(page_template,
            {"content" => index.rendered, "title" => index.title, "breadcrumbs" => index.breadcrumbs})
          doc = Lexbor::Parser.new(html)
          doc = HtmlFilters.make_links_relative(doc, Utils.path_to_link(output))
          doc.to_html
        end
      end
    end
  end

  # Represents a folder index for pages (not posts)
  struct PageFolderIndex
    @path : Path
    @content_path : Path

    def initialize(@path : Path, @content_path : Path)
    end

    # Get the output path for this index
    def output : Path
      @path.relative_to(@content_path) / "index.html"
    end

    # Get the title for this folder index
    def title : String
      @path.basename.to_s.capitalize
    end

    # Get immediate contents (non-recursive) for this folder
    def immediate_contents : NamedTuple(
      subdirs: Array(NamedTuple(link: String, name: String)),
      files: Array(NamedTuple(link: String, title: String)),
    )
      subdirs = [] of NamedTuple(link: String, name: String)
      files = [] of NamedTuple(link: String, title: String)

      output_prefix = Config.options.output.rchop('/')
      folder_relative = @path.relative_to(@content_path)

      # Get immediate items in this directory
      Dir.glob("#{@path}/*").each do |item|
        basename = File.basename(item)

        if File.directory?(item)
          # List subdirectory if it has ANY content (markdown files or subdirectories)
          # An index will be generated for it anyway by folder_indexes
          has_content = !Dir.glob("#{item}/**/*.md").empty? || !Dir.glob("#{item}/*/").empty?
          if has_content
            subdirs << {link: "#{basename}/index.html", name: basename}
          end
        elsif File.file?(item) && basename.ends_with?(".md") && !basename.starts_with?("index.")
          # This is a markdown file that's not an index
          # Find the corresponding File in the registry
          # Check all language sources since file may have multiple source files
          item_path = item.to_s
          # The registry stores paths relative to content/ or as full paths
          # Try relative path first (content/pages/10.md)
          item_relative = item_path.sub(/^.*\/content\//, "content/")
          # Try direct match with relative path
          file = Markdown::File.posts[item_relative]?
          # If not found, try matching against all sources
          unless file
            file = Markdown::File.posts.values.find do |md_file|
              md_file.@sources.values.includes?(item_path) ||
                md_file.@sources.values.includes?(item_relative)
            end
          end

          if file
            # Get the output for the default language
            output_path = file.output
            # Get the link relative to output directory, then make it relative to this folder
            relative_link = output_path.sub(/^#{output_prefix}\//, "")
            # Remove the folder path prefix to make it relative to current folder
            relative_link = relative_link.sub(/^#{Regex.escape(folder_relative.to_s)}\//, "")
            files << {link: relative_link, title: file.title}
          end
        end
      end

      {
        subdirs: subdirs.sort_by { |dir| dir[:name] },
        files:   files.sort_by { |file| file[:link] },
      }
    end

    # Render the folder index HTML
    def rendered : String
      contents = immediate_contents

      # Include title.tmpl which handles breadcrumbs
      title_template = Theme.template_path("title.tmpl")
      title_html = Templates.environment.get_template(title_template).render({
        "title"       => title,
        "link"        => "/#{output.to_s.sub(/\.html$/, "")}",
        "breadcrumbs" => breadcrumbs,
        "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
      })

      # Build content using common template style
      content_html = String.build do |io|
        io << "<section class=\"item-list-index\">\n"

        unless contents[:subdirs].empty?
          io << "  <h3>Subdirectories</h3>\n"
          io << "  <ul class=\"item-list subdir-list\">\n"
          contents[:subdirs].each do |subdir|
            io << "    <li><a href=\"#{subdir[:link]}\">#{subdir[:name]}</a></li>\n"
          end
          io << "  </ul>\n"
        end

        unless contents[:files].empty?
          io << "  <ul class=\"item-list pages-list\">\n"
          contents[:files].each do |file|
            file_title = file[:title].empty? ? "Unknown Title" : file[:title]
            io << "    <li><a href=\"#{file[:link]}\">#{file_title}</a></li>\n"
          end
          io << "  </ul>\n"
        end

        if contents[:subdirs].empty? && contents[:files].empty?
          io << "  <p>This folder is empty.</p>\n"
        end

        io << "</section>\n"
        io << "<style>\n"
        io << ".item-list-index { margin: 2rem 0; }\n"
        io << ".item-list-index h3 { margin-top: 1.5rem; margin-bottom: 0.75rem; font-size: 1.2em; color: var(--b16-base03); }\n"
        io << ".subdir-list { margin-bottom: 2rem; }\n"
        io << ".item-list { list-style-type: disc; padding-left: 1.5rem; margin: 1rem 0; }\n"
        io << ".item-list li { margin: 0.5rem 0; }\n"
        io << ".item-list a { text-decoration: none; color: var(--b16-base0D); font-size: 1.1em; }\n"
        io << ".item-list a:hover { text-decoration: underline; }\n"
        io << "</style>\n"
      end

      title_html + content_html
    end

    # Get breadcrumbs for this folder index
    def breadcrumbs : Array(NamedTuple(name: String, link: String))
      folder_relative = @path.relative_to(@content_path)

      result = [{name: "Home", link: "/"}] of NamedTuple(name: String, link: String)

      # Build breadcrumbs for intermediate folders (if any)
      current_path = Path.new(".")
      folder_relative.parts[0..-2].each do |part|
        current_path = current_path / part
        # Build the full output path for this breadcrumb
        full_path = Path[Config.options.output] / current_path / "index.html"
        result << {
          name: part,
          link: Utils.path_to_link(full_path),
        }
      end

      # Add current folder as the last breadcrumb (with link to itself)
      result << {
        name: @path.basename.to_s.capitalize,
        link: Utils.path_to_link(Path[Config.options.output] / output),
      }

      result
    end
  end
end
