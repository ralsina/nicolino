require "./markdown"

module FolderIndexes
  # Registry for feature modules to register their output folders
  # that should be excluded from automatic index generation
  @@excluded_folders = [] of String

  def self.register_exclude(folder : String)
    @@excluded_folders << folder unless @@excluded_folders.includes?(folder)
  end

  def self.excluded_folders
    @@excluded_folders
  end

  # Generates indexes for folders that have no index file
  struct FolderIndex
    @path : Path
    @output : Path

    def initialize(path : Path)
      @path = path
      # Get the relative path from content directory
      content_path = Path.new(Config.options.content).expand
      @output = (path / "index.html").relative_to(content_path)
    end

    # Check if this is the posts folder or a subfolder
    def posts_folder?
      content_path = Path.new(Config.options.content).expand
      posts_path = Config.options.posts.rchop('/')
      @path.relative_to(content_path).to_s.starts_with?(posts_path)
    end

    # Get all posts whose output starts with this folder's path (prefix-matching)
    def posts_by_prefix
      content_path = Path.new(Config.options.content).expand
      output_prefix = Config.options.output.rchop('/')
      output_folder = "#{output_prefix}/#{@path.relative_to(content_path)}"

      # Find all posts whose output path starts with this folder
      Markdown::File.posts.values.select do |post|
        post.output.starts_with?(output_folder)
      end.sort_by! { |post_data| post_data.date || Time.utc(1970, 1, 1) }.reverse!
    end

    # Get immediate files (non-recursive) and subdirectories for non-posts folders
    def immediate_contents
      subdirs = [] of NamedTuple(link: String, name: String)
      files = [] of NamedTuple(link: String, title: String)

      output_prefix = Config.options.output.rchop('/')
      # Get the relative path from output directory for this folder index
      content_path = Path.new(Config.options.content).expand
      folder_relative = @path.relative_to(content_path)

      # Get immediate items in this directory
      Dir.glob("#{@path}/*").each do |item|
        basename = File.basename(item)

        if File.directory?(item)
          # Check if this subdirectory has an index.md
          has_index = File.file?("#{item}/index.md")
          if has_index
            subdirs << {link: "#{basename}/index.html", name: basename}
          end
        elsif File.file?(item) && basename.ends_with?(".md") && !basename.starts_with?("index.")
          # This is a markdown file that's not an index
          # Find the corresponding post in the registry
          post = Markdown::File.posts.values.find do |md_file|
            md_file.source.includes?(basename)
          end

          if post
            # Get the link relative to output directory, then make it relative to this folder
            relative_link = post.output.sub(/^#{output_prefix}\//, "")
            # Remove the folder path prefix to make it relative to current folder
            relative_link = relative_link.sub(/^#{Regex.escape(folder_relative.to_s)}\//, "")
            files << {link: relative_link, title: post.title}
          end
        end
      end

      {subdirs: subdirs.sort_by { |dir| dir[:name] }, files: files.sort_by { |file| file[:link] }}
    end

    def rendered
      if posts_folder?
        # Use Markdown.render_index for posts folders (with prefix-matching)
        folder_posts = posts_by_prefix
        return "" if folder_posts.empty?

        Templates.environment.get_template("templates/index.tmpl").render({
          "posts" => folder_posts.map(&.value),
        })
      else
        # Use simple listing for other folders (immediate files only + subdirs)
        contents = immediate_contents

        # Include title.tmpl which handles breadcrumbs
        title_html = Templates.environment.get_template("templates/title.tmpl").render({
          "title"       => folder_title,
          "link"        => "/#{@output.to_s.sub(/\.html$/, "")}",
          "breadcrumbs" => breadcrumbs,
          "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
        })

        # Build content manually
        content_html = String.build do |io|
          io << "<div class=\"folder-contents\">\n"

          unless contents[:subdirs].empty?
            io << "  <h3>Subdirectories</h3>\n"
            io << "  <ul class=\"file-list subdir-list\">\n"
            contents[:subdirs].each do |subdir|
              io << "    <li><a href=\"#{subdir[:link]}\">#{subdir[:name]}</a></li>\n"
            end
            io << "  </ul>\n"
          end

          unless contents[:files].empty?
            io << "  <h3>Pages</h3>\n"
            io << "  <ul class=\"file-list pages-list\">\n"
            contents[:files].each do |file|
              io << "    <li><a href=\"#{file[:link]}\">#{file[:title]}</a></li>\n"
            end
            io << "  </ul>\n"
          end

          if contents[:subdirs].empty? && contents[:files].empty?
            io << "  <p>This folder is empty.</p>\n"
          end

          io << "</div>\n"
          io << "<style>\n"
          io << ".file-list { list-style-type: disc; padding-left: 1.5rem; margin: 1rem 0; }\n"
          io << ".subdir-list { margin-bottom: 2rem; }\n"
          io << ".file-list li { margin: 0.5rem 0; }\n"
          io << ".file-list a { text-decoration: none; color: var(--b16-base0D); font-size: 1.1em; }\n"
          io << ".file-list a:hover { text-decoration: underline; }\n"
          io << ".folder-contents h3 { margin-top: 1.5rem; font-size: 1.2em; color: var(--b16-base03); }\n"
          io << "</style>\n"
        end

        title_html + content_html
      end
    end

    # Get breadcrumbs for this folder index
    def breadcrumbs
      content_path = Path.new(Config.options.content).expand
      folder_relative = @path.relative_to(content_path)

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
        link: Utils.path_to_link(Path[Config.options.output] / @output),
      }

      result
    end

    # Get the title for this folder index
    def folder_title
      @path.basename.to_s.capitalize
    end
  end

  def self.read_all(path : Path, exclude_patterns = [] of String) : Array(FolderIndex)
    indexes = [] of FolderIndex
    candidates = [path] + Dir.glob("#{path}/**/*/")
    candidates.map do |folder|
      # Skip if folder matches any exclude pattern
      next if exclude_patterns.any? { |pattern| folder.to_s.includes?(pattern) }

      # Check if there's an index.md file that would generate this folder's index.html
      has_index_md = File.file?("#{folder}/index.md")

      # Only generate folder index if no index.md exists
      if has_index_md
        Log.debug { "Skipping #{folder}: index.md exists" }
      else
        Log.debug { "👈 #{folder}" }
        indexes << FolderIndex.new(Path.new(folder))
      end
    end
    indexes
  end

  def self.render(indexes : Array(FolderIndex))
    Config.languages.keys.each do |lang|
      out_path = Path.new(Config.options(lang).output)

      # First, render posts folders using Markdown.render_index
      indexes.select(&.posts_folder?).each do |index|
        folder_posts = index.posts_by_prefix
        next if folder_posts.empty?

        output = (out_path / index.@output).to_s
        title = index.@path.basename.to_s.capitalize

        Markdown.render_index(folder_posts, output, title)
      end

      # Then, render other folders using simple template
      indexes.reject(&.posts_folder?).each do |index|
        # All markdown posts are dependencies since we use the global registry
        all_posts = Markdown::File.posts.map(&.last.source)

        inputs = ["kv://templates/folder_index.tmpl", "conf.yml"] + all_posts
        output = (out_path / index.@output).to_s
        # Use unique task ID based on output path
        task_id = "folder_index::#{output}"
        Croupier::Task.new(
          id: task_id,
          output: output,
          inputs: inputs,
          mergeable: false
        ) do
          Log.info { "👉 #{output}" }
          html = Render.apply_template("templates/page.tmpl",
            {"content" => index.rendered, "title" => index.folder_title, "breadcrumbs" => index.breadcrumbs})
          doc = Lexbor::Parser.new(html)
          doc = HtmlFilters.make_links_relative(doc, Utils.path_to_link(output))
          doc.to_html
        end
      end
    end
  end
end
