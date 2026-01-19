require "./books/summary_parser"
require "./folder_indexes"
require "./sc"
require "./theme"
require "json"
require "shortcodes"
require "toml"

module Books
  # Configuration from book.toml (mdbook compatibility)
  #
  # Supported sections from mdbook spec:
  # - [book]: title, description, authors, language
  # - [build]: create-missing (auto-create missing chapter files)
  # - [output.html]: git-repository-url, edit-url-template (shown in sidebar/footer)
  #
  # Not supported (noted for future reference):
  # - [build]: extra-watch-dirs, build-dir
  # - [output.html.*]: mdbook-specific output settings (except the above)
  # - [output.html.playground]: Rust playground integration
  # - [output.html.search]: Search config (we have our own search feature)
  # - [output.html.redirect]: Redirects
  # - [preprocessor.*]: mdbook preprocessor system
  struct BookConfig
    property title : String?
    property authors : Array(String)?
    property description : String?
    property language : String?
    # ameba:disable Naming/QueryBoolMethods
    property create_missing : Bool = false
    property git_repository_url : String?
    property edit_url_template : String?

    def initialize(
      @title : String? = nil,
      @authors : Array(String)? = nil,
      @description : String? = nil,
      @language : String? = nil,
      @create_missing : Bool = false,
      @git_repository_url : String? = nil,
      @edit_url_template : String? = nil,
    )
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def self.from_file(book_toml_path : String) : BookConfig?
      return nil unless File.exists?(book_toml_path)

      toml_content = File.read(book_toml_path)
      parsed = TOML.parse(toml_content)

      title = nil
      authors = nil
      description = nil
      language = nil
      create_missing = false
      git_repository_url = nil
      edit_url_template = nil

      # Extract from [book] section
      if book_section = parsed["book"]?
        if title_val = book_section.as_h["title"]?
          title = title_val.as_s
        end
        if desc_val = book_section.as_h["description"]?
          description = desc_val.as_s
        end
        if authors_val = book_section.as_h["authors"]?
          authors = authors_val.as_a.map(&.as_s)
        end
        if lang_val = book_section.as_h["language"]?
          language = lang_val.as_s
        end
      end

      # Extract from [build] section
      if build_section = parsed["build"]?
        if create_missing_val = build_section.as_h["create-missing"]? || build_section.as_h["create_missing"]?
          create_missing = create_missing_val.as_bool
        end
      end

      # Extract from [output.html] section
      if html_section = parsed["output.html"]?
        if git_url_val = html_section.as_h["git-repository-url"]? || html_section.as_h["git_repository_url"]?
          git_repository_url = git_url_val.as_s
        end
        if edit_url_val = html_section.as_h["edit-url-template"]? || html_section.as_h["edit_url_template"]?
          edit_url_template = edit_url_val.as_s
        end
      end

      new(
        title: title,
        authors: authors,
        description: description,
        language: language,
        create_missing: create_missing,
        git_repository_url: git_repository_url,
        edit_url_template: edit_url_template,
      )
    rescue ex
      Log.warn { "Failed to parse book.toml: #{ex.message}" }
      nil
    end
  end

  # Book chapter file that reuses Markdown::File but handles optional metadata
  class BookChapter < Markdown::File
    def initialize(sources, base, title_override : String? = nil)
      @sources = sources
      @base = base
      @title_override = title_override

      # Set output path similar to parent
      @sources.map { |lang, _|
        p = Path[base]
        p = Path[p.parts].relative_to Config.options.content
        p = Path[Config.options(lang).output] / p
        @output[lang] = "#{p}.html"
      }

      # Register in posts hash
      @@posts[base.to_s] = self

      # Load for each language
      Config.languages.keys.each do |lang|
        load lang
      end
    end

    # Override load to handle files WITHOUT metadata (book chapters have no metadata)
    def load(lang = nil) : Nil
      lang ||= Locale.language
      Log.debug { "👉 #{source(lang)}" }
      @text[lang] = ::File.read(source(lang))
      @metadata[lang] = {} of String => String
      @title[lang] = @title_override || ""

      @link[lang] = (Path.new ["/", output.split("/")[1..]]).to_s
      @shortcodes[lang] = full_shortcodes_list(@text[lang])
    rescue ex
      Log.error { "Error reading book chapter #{source(lang)}: #{ex}" }
      raise ex
    end

    property title_override : String?
  end

  # Book class representing a complete documentation book
  class Book
    property name : String
    property title : String
    property description : String?
    property chapters : Array(ChapterEntry)
    property config : BookConfig?

    def initialize(@name, @title, @chapters, @description = nil, @config : BookConfig? = nil)
    end

    # Convert to hash for template rendering
    def to_context : Hash(String, String | Nil)
      ctx = {
        "name"               => @name,
        "title"              => @title,
        "description"        => @description || "",
        "git_repository_url" => @config.try(&.git_repository_url),
        "edit_url_template"  => @config.try(&.edit_url_template),
        "authors"            => @config.try(&.authors).try(&.join(", ")) || nil,
      }
      ctx
    end
  end

  # Chapter entry from SUMMARY.md (parsed structure)
  class ChapterEntry
    property title : String
    property path : String?
    property children : Array(ChapterEntry)
    property number : Array(Int32)
    property level : Int32
    # ameba:disable Naming/QueryBoolMethods
    property is_part : Bool

    def initialize(@title, @path = nil, @number = [] of Int32, @level = 0)
      @children = [] of ChapterEntry
      @is_part = false
    end

    def part?
      @is_part
    end

    def part=(value : Bool)
      @is_part = value
    end

    def formatted_number : String
      return "" if @number.empty?
      @number.join(".")
    end

    def has_content? : Bool
      !@path.nil?
    end

    # Get the slug from path (preserves directory structure)
    def slug : String
      return "" unless path = @path
      # Keep the full relative path without the .md extension
      # e.g., "cli/build.md" -> "cli/build"
      path.rchop(".md")
    end

    # Get the link for this chapter (preserves directory structure)
    def link(book_name : String) : String
      if slug.empty?
        "/books/#{book_name}/"
      else
        "/books/#{book_name}/#{slug}.html"
      end
    end

    # Find the next chapter
    def find_next(flat : Array(ChapterEntry)) : ChapterEntry?
      idx = flat.index(self)
      flat[idx + 1]? if idx
    end

    # Find the previous chapter
    def find_prev(flat : String) : ChapterEntry?
      idx = flat.index(self)
      flat[idx - 1]? if idx && idx > 0
    end
  end

  # Enable books feature
  def self.enable(is_enabled : Bool)
    return unless is_enabled

    # Register books output folder for exclusion from folder_indexes
    FolderIndexes.register_exclude("books/")

    books_path = Path[Config.options.content] / "books"
    return unless Dir.exists?(books_path)

    create_tasks(books_path.to_s)
  end

  # Discover all books and create Croupier tasks
  def self.create_tasks(books_path : String)
    books = [] of Book

    # Find all directories containing SUMMARY.md
    glob_pattern = "#{books_path}/*/SUMMARY.md"
    Dir.glob(glob_pattern).each do |summary_file|
      book_dir = File.dirname(summary_file)
      book_name = File.basename(book_dir)

      # Check for book.toml (mdbook compatibility)
      book_toml_path = File.join(book_dir, "book.toml")
      book_config = BookConfig.from_file(book_toml_path)

      # Read and parse SUMMARY.md
      summary_content = File.read(summary_file)
      entries = SummaryParser.parse(summary_content)

      # Get book title and description - prefer book.toml, fall back to SUMMARY.md
      title = if (toml_title = book_config.try(&.title)) && !toml_title.empty?
                toml_title
              else
                extract_title(summary_content, book_name)
              end

      description = if (toml_desc = book_config.try(&.description)) && !toml_desc.empty?
                      toml_desc
                    else
                      SummaryParser.extract_description(summary_content)
                    end

      # Build flat list of all chapters for navigation
      flat_chapters = flatten_entries(entries).select(&.has_content?)

      # Check for orphaned .md files (files in book dir not referenced in SUMMARY.md
      check_orphaned_files(book_dir, flat_chapters)

      # Create missing files if requested
      if book_config && book_config.create_missing
        create_missing_chapters(entries, book_dir)
      end

      book = Book.new(book_name, title, entries, description, book_config)
      books << book

      # Create tasks for this book
      create_book_tasks(book, book_dir, flat_chapters)
    end

    # Create books index page
    create_books_index(books) unless books.empty?
  end

  # Flatten chapter entries for navigation
  private def self.flatten_entries(entries : Array(ChapterEntry)) : Array(ChapterEntry)
    entries.flat_map { |e| [e] + flatten_entries(e.children) }
  end

  # Create Croupier tasks for a single book
  private def self.create_book_tasks(book : Book, book_dir : String, flat_chapters : Array(ChapterEntry))
    summary_path = File.join(book_dir, "SUMMARY.md")

    # Create tasks for each chapter that has content
    create_chapter_tasks(book.chapters, book, book_dir, summary_path, flat_chapters)

    # Create book index page
    create_book_index_task(book, book_dir)
  end

  # Recursively create tasks for chapters
  private def self.create_chapter_tasks(
    entries : Array(ChapterEntry),
    book : Book,
    book_dir : String,
    summary_path : String,
    flat_chapters : Array(ChapterEntry),
  )
    entries.each do |entry|
      if entry.has_content?
        if path = entry.path
          source_file = resolve_source_path(path, book_dir)
          Log.debug { "📚 Chapter: #{entry.title} -> source: #{source_file}" }
          if source_file && File.exists?(source_file)
            Log.debug { "📚 Creating task for chapter: #{entry.title}" }
            create_chapter_task(entry, book, source_file, summary_path, flat_chapters)
          else
            Log.warn { "📚 Source file not found for chapter: #{entry.title} (#{source_file})" }
          end
        end
      end
      create_chapter_tasks(entry.children, book, book_dir, summary_path, flat_chapters)
    end
  end

  # Create task for a single chapter
  private def self.create_chapter_task(
    entry : ChapterEntry,
    book : Book,
    source_file : String,
    summary_path : String,
    flat_chapters : Array(ChapterEntry),
  )
    output_path = Path[Config.options.output] / "books" / book.name / "#{entry.slug}.html"

    page_template = Theme.template_path("page.tmpl")
    title_template = Theme.template_path("title.tmpl")
    book_chapter_template = Theme.template_path("book_chapter.tmpl")

    inputs = [
      source_file,
      summary_path,
      "conf.yml",
      "kv://#{page_template}",
      "kv://#{title_template}",
    ] + Templates.get_deps(book_chapter_template)

    Croupier::Task.new(
      id: "book/#{book.name}/#{entry.slug}",
      output: output_path.to_s,
      inputs: inputs,
      mergeable: false
    ) do
      # Create a BookChapter instance to reuse Markdown::File functionality
      chapter_file = BookChapter.new({Locale.language => source_file}, Path[source_file].relative_to(Config.options.content), entry.title)

      # Get the rendered HTML (includes shortcode processing, markdown rendering, header downgrading)
      html_content = chapter_file.html

      # Build navigation data
      nav = build_navigation(entry, flat_chapters, book, book.name)

      # Build breadcrumbs
      breadcrumbs = [
        {name: "Home", link: "/"},
        {name: "Books", link: "/books/"},
        {name: book.title, link: "/books/#{book.name}/"},
        {name: entry.title, link: entry.link(book.name)},
      ] of NamedTuple(name: String, link: String)

      # Render chapter with book template
      book_chapter_template = Theme.template_path("book_chapter.tmpl")
      template = Templates.environment.get_template(book_chapter_template)

      toc_html = render_toc_html(book.chapters, entry, book.name)

      ctx = {
        "chapter" => {
          "title"            => entry.title,
          "formatted_number" => entry.formatted_number,
          "content"          => html_content,
          "link"             => entry.link(book.name),
        },
        "book"       => book.to_context,
        "navigation" => nav,
        "toc_html"   => toc_html,
      }

      html = template.render(ctx)

      # Apply page template wrapper with title.tmpl for breadcrumbs
      page_title = entry.formatted_number.empty? ? entry.title : "#{entry.formatted_number} #{entry.title}"

      # Include title.tmpl which handles breadcrumbs
      title_template = Theme.template_path("title.tmpl")
      title_html = Templates.environment.get_template(title_template).render({
        "title"       => page_title,
        "link"        => entry.link(book.name),
        "breadcrumbs" => breadcrumbs,
        "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
      })

      # Combine title HTML with content
      content_html = title_html + html

      page_template = Theme.template_path("page.tmpl")
      html = Render.apply_template(page_template, {
        "content"         => content_html,
        "title"           => page_title,
        "breadcrumbs"     => breadcrumbs,
        "sidebar_content" => toc_html,
      })

      # Process HTML filters
      doc = Lexbor::Parser.new(html)
      doc = HtmlFilters.make_links_relative(doc, Utils.path_to_link(output_path.to_s))
      result = HtmlFilters.fix_code_classes(doc).to_html
      Log.info { "👉 #{output_path}" }
      result
    end
  end

  # Build navigation hash for a chapter
  private def self.build_navigation(
    entry : ChapterEntry,
    flat_chapters : Array(ChapterEntry),
    book : Book,
    book_name : String,
  ) : Hash(String, Hash(String, String)?)
    idx = flat_chapters.index(entry)

    prev_entry = flat_chapters[idx - 1]? if idx && idx > 0
    next_entry = flat_chapters[idx + 1]? if idx

    # For the first chapter, use the book index as the previous link
    if idx == 0
      prev_nav = {
        "title" => book.title,
        "link"  => "/books/#{book_name}/",
      }
    else
      prev_nav = prev_entry ? nav_hash_for_entry(prev_entry, book_name) : nil
    end

    {
      "prev" => prev_nav,
      "next" => next_entry ? nav_hash_for_entry(next_entry, book_name) : nil,
    }
  end

  # Find parent chapter in hierarchy (searches the full chapter tree, not just flat list)
  private def self.find_parent(entry : ChapterEntry, book : Book) : ChapterEntry?
    return nil if entry.level == 0

    # Search in the book's full chapter hierarchy
    find_parent_in_tree(entry, book.chapters)
  end

  # Recursively search for parent in the chapter tree
  private def self.find_parent_in_tree(entry : ChapterEntry, entries : Array(ChapterEntry)) : ChapterEntry?
    entries.each do |candidate|
      # Check if this entry is the parent (level is one less)
      if candidate.level == entry.level - 1
        # Check if entry is in this candidate's children
        if candidate.children.includes?(entry)
          return candidate
        end
        # Search recursively
        if result = find_parent_in_tree(entry, candidate.children)
          return result
        end
      elsif candidate.level < entry.level
        # Search in children if level is lower
        if result = find_parent_in_tree(entry, candidate.children)
          return result
        end
      end
    end
    nil
  end

  # Create navigation hash for a chapter entry
  private def self.nav_hash_for_entry(entry : ChapterEntry, book_name : String) : Hash(String, String)
    entry_title = entry.title
    entry_link = entry.link(book_name)

    # If entry has no path and is not the root index, link to first child instead
    # The root index (level 0) should always link to itself
    if !entry.has_content? && !entry.children.empty? && entry.level > 0
      first_child = find_first_chapter(entry.children)
      if first_child
        entry_title = first_child.title
        entry_link = first_child.link(book_name)
      end
    end

    {
      "title" => entry_title,
      "link"  => entry_link,
    }
  end

  # Render TOC as HTML string - avoids recursive template includes
  private def self.render_toc_html(entries : Array(ChapterEntry), current : ChapterEntry?, book_name : String) : String
    entries.map do |entry|
      render_toc_item_html(entry, current, book_name)
    end.join("\n")
  end

  # Render a single TOC item as HTML
  private def self.render_toc_item_html(entry : ChapterEntry, current : ChapterEntry?, book_name : String) : String
    # Skip part titles in TOC
    return "" if entry.part?

    active_class = entry == current ? "active" : ""
    has_children = !entry.children.empty?
    number_prefix = entry.formatted_number.empty? ? "" : "#{entry.formatted_number} "

    if has_children
      children_html = entry.children.map do |child|
        render_toc_item_html(child, current, book_name)
      end.join("\n")

      # Open if this is the current entry OR if current is a descendant
      should_open = entry == current || ancestor?(entry, current)
      open_attr = should_open ? "open" : ""

      if entry.has_content?
        link_html = "<a href=\"#{entry.link(book_name)}\" class=\"toc-link #{active_class}\">#{number_prefix}#{entry.title}</a>"
      else
        link_html = "<span class=\"toc-title\">#{number_prefix}#{entry.title}</span>"
      end

      "<div class=\"toc-item toc-level-#{entry.level}\">\n" \
      "<details class=\"toc-group\" #{open_attr}>\n" \
      "  <summary class=\"toc-summary\">\n" \
      "    #{link_html}\n" \
      "  </summary>\n" \
      "  <div class=\"toc-children\">\n" \
      "    #{children_html}\n" \
      "  </div>\n" \
      "</details>\n" \
      "</div>"
    else
      if entry.has_content?
        "<div class=\"toc-item toc-level-#{entry.level}\">\n" \
        "<a href=\"#{entry.link(book_name)}\" class=\"toc-link #{active_class}\">#{number_prefix}#{entry.title}</a>\n" \
        "</div>"
      else
        "<div class=\"toc-item toc-level-#{entry.level}\">\n" \
        "<span class=\"toc-title disabled\">#{entry.title}</span>\n" \
        "</div>"
      end
    end
  end

  # Check if target is a descendant of ancestor
  private def self.ancestor?(ancestor : ChapterEntry, target : ChapterEntry?) : Bool
    return false unless target
    return true if ancestor == target

    ancestor.children.any? do |child|
      ancestor?(child, target)
    end
  end

  # Create task for book index page
  private def self.create_book_index_task(book : Book, book_dir : String)
    output_path = Path[Config.options.output] / "books" / book.name / "index.html"

    page_template = Theme.template_path("page.tmpl")
    title_template = Theme.template_path("title.tmpl")
    book_index_template = Theme.template_path("book_index.tmpl")

    inputs = [
      File.join(book_dir, "SUMMARY.md"),
      "conf.yml",
      "kv://#{page_template}",
      "kv://#{title_template}",
    ] + Templates.get_deps(book_index_template)

    Croupier::Task.new(
      id: "book/#{book.name}/index",
      output: output_path.to_s,
      inputs: inputs,
      mergeable: false
    ) do
      Log.info { "👉 #{output_path}" }

      # Create breadcrumbs
      breadcrumbs = [
        {name: "Home", link: "/"},
        {name: "Books", link: "/books/"},
        {name: book.title, link: "/books/#{book.name}/"},
      ] of NamedTuple(name: String, link: String)

      # Include title.tmpl which handles breadcrumbs
      title_template = Theme.template_path("title.tmpl")
      title_html = Templates.environment.get_template(title_template).render({
        "title"       => book.title,
        "link"        => "/books/#{book.name}/",
        "breadcrumbs" => breadcrumbs,
        "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
      })

      book_index_template = Theme.template_path("book_index.tmpl")
      template = Templates.environment.get_template(book_index_template)

      # Find first chapter with content for the "Next" button
      first_chapter_entry = find_first_chapter(book.chapters)
      first_chapter = first_chapter_entry ? {
        "title" => first_chapter_entry.title,
        "link"  => first_chapter_entry.link(book.name),
      } : nil

      ctx = {
        "book"          => book.to_context,
        "toc_html"      => render_toc_html(book.chapters, nil, book.name),
        "first_chapter" => first_chapter,
      }

      content = title_html + template.render(ctx)

      page_template = Theme.template_path("page.tmpl")
      html = Render.apply_template(page_template, {
        "content"     => content,
        "title"       => book.title,
        "breadcrumbs" => breadcrumbs,
      })

      doc = Lexbor::Parser.new(html)
      doc = HtmlFilters.make_links_relative(doc, Utils.path_to_link(output_path.to_s))
      HtmlFilters.fix_code_classes(doc).to_html
    end
  end

  # Create books listing page (all books)
  private def self.create_books_index(books : Array(Book))
    return if books.empty?

    output_path = Path[Config.options.output] / "books" / "index.html"

    page_template = Theme.template_path("page.tmpl")
    title_template = Theme.template_path("title.tmpl")
    item_list_template = Theme.template_path("item_list.tmpl")

    Croupier::Task.new(
      id: "books/index",
      output: output_path.to_s,
      inputs: ["conf.yml", "kv://#{page_template}", "kv://#{title_template}"] + Templates.get_deps(item_list_template),
      mergeable: false
    ) do
      Log.info { "👉 #{output_path}" }

      # Create breadcrumbs
      breadcrumbs = [{name: "Home", link: "/"}, {name: "Books", link: "/books/"}] of NamedTuple(name: String, link: String)

      # Include title.tmpl which handles breadcrumbs
      title_template = Theme.template_path("title.tmpl")
      title_html = Templates.environment.get_template(title_template).render({
        "title"       => "Books",
        "link"        => "/books/",
        "breadcrumbs" => breadcrumbs,
        "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
      })

      item_list_template = Theme.template_path("item_list.tmpl")
      template = Templates.environment.get_template(item_list_template)

      items = books.map do |book|
        {
          "title"       => book.title,
          "description" => book.description || "",
          "link"        => "/books/#{book.name}/",
          "date"        => nil,
        }
      end

      content = template.render({
        "title"       => "Books",
        "description" => "Documentation books.",
        "items"       => items,
      })

      page_template = Theme.template_path("page.tmpl")
      html = Render.apply_template(page_template, {
        "content"     => title_html + content,
        "title"       => "Books",
        "breadcrumbs" => breadcrumbs,
      })

      doc = Lexbor::Parser.new(html)
      doc = HtmlFilters.make_links_relative(doc, "/books/")
      HtmlFilters.fix_code_classes(doc).to_html
    end
  end

  # Resolve source path (supports both "chapter.md" and "src/chapter.md")
  private def self.resolve_source_path(path : String, book_dir : String) : String?
    # Try direct path first
    direct = File.join(book_dir, path)
    return direct if File.exists?(direct)

    # Try with src/ prefix
    with_src = File.join(book_dir, "src", path)
    return with_src if File.exists?(with_src)

    nil
  end

  # Extract title from SUMMARY.md (first # heading or use book name)
  private def self.extract_title(summary_content : String, book_name : String) : String
    summary_content.each_line do |line|
      if line =~ /^#\s+(.+)$/
        return $1
      end
    end
    book_name.split(/[-_]/).map(&.capitalize).join(" ")
  end

  # Find the first chapter with actual content (not a part title or draft)
  private def self.find_first_chapter(entries : Array(ChapterEntry)) : ChapterEntry?
    entries.each do |entry|
      # Skip part titles
      next if entry.part?

      # If this entry has content, return it
      return entry if entry.has_content?

      # Otherwise, search recursively in children
      if result = find_first_chapter(entry.children)
        return result
      end
    end
    nil
  end

  # Check for orphaned .md files in book directory that aren't in SUMMARY.md
  private def self.check_orphaned_files(book_dir : String, flat_chapters : Array(ChapterEntry))
    # Get all .md files in book directory (excluding SUMMARY.md)
    all_md_files = Dir.glob(File.join(book_dir, "*.md")).reject do |file|
      File.basename(file) == "SUMMARY.md"
    end

    # Get all files referenced in SUMMARY.md
    referenced_files = flat_chapters.compact_map do |entry|
      if path = entry.path
        File.join(book_dir, path)
      else
        nil
      end
    end.to_set

    # Find orphaned files
    orphaned = all_md_files.reject { |file| referenced_files.includes?(file) }

    return if orphaned.empty?
    Log.warn { "📚 Book '#{File.basename(book_dir)}' has #{orphaned.size} unreferenced .md file(s):" }
    orphaned.each do |file|
      Log.warn { "  - #{File.basename(file)}" }
    end
  end

  # Create missing chapter files if create-missing is enabled
  private def self.create_missing_chapters(entries : Array(ChapterEntry), book_dir : String)
    entries.each do |entry|
      create_missing_chapters(entry.children, book_dir)
      if path = entry.path
        source_path = resolve_source_path(path, book_dir)
        if source_path && !File.exists?(source_path)
          Log.info { "📚 Creating missing chapter: #{source_path}" }
          # Create directory if needed
          dir = File.dirname(source_path)
          Dir.mkdir_p(dir) unless Dir.exists?(dir)

          # Create file with placeholder content
          File.write(source_path, "# #{entry.title}\n\nTODO: Write content for #{entry.title}.\n")
        end
      end
    end
  end
end
