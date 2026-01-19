require "./html_filters"
require "./sc"
require "./similarity"
require "./taxonomies"
require "./theme"
require "cr-discount"
require "cronic"
require "RSS"
require "shortcodes"

include Cronic

module Markdown
  # A class representing a Markdown file
  class File
    @date : Time | Nil
    @html = Hash(String, String).new
    @link = Hash(String, String).new
    @base = Path.new
    @metadata = Hash(String, Hash(String, String)).new
    @rendered = Hash(String, String).new
    @shortcodes = Hash(String, Array(Shortcodes::Shortcode)).new
    @sources = Hash(String, String).new
    @text = Hash(String, String).new
    @title = Hash(String, String).new
    @toc = Hash(String, String).new
    @output = Hash(String, String).new

    # Register all Files by @source
    @@posts = Hash(String, File).new

    def self.posts
      @@posts
    end

    # Initialize the post with proper data
    def initialize(sources, base)
      @sources = sources
      @base = base
      @sources.map { |lang, _|
        p = Path[base]
        # Remove the leading "posts/"
        p = Path[p.parts].relative_to Config.options.content
        # Add language code to output path to avoid conflicts
        # Rules:
        # 1. Language-specific files (e.g., 958.es.md):
        #    - Default language (en) files -> no suffix
        #    - Non-default language files -> add suffix (e.g., 958.es.html)
        #    This prevents conflicts when both foo.md and foo.es.md exist
        # 2. Shared files (e.g., 958.md used by multiple languages):
        #    - Default language (en) -> no suffix
        #    - Non-default languages -> add suffix (e.g., 958.es.html)
        p = Path[Config.options(lang).output] / p

        # Add suffix for non-default languages (both language-specific and shared files)
        if lang != "en"
          p = Path[p.dirname] / "#{p.stem}.#{lang}#{p.extension}"
        end

        @output[lang] = "#{p}.html"
      }
      @@posts[base.to_s] = self

      # Load each unique source file once, then share data across languages
      # This enables bidirectional fallback: any language can use any available file
      loaded_files = Set(String).new
      @sources.each do |lang, source_file|
        unless loaded_files.includes?(source_file)
          Log.debug { "Loading #{source_file} for language #{lang}" }
          load lang
          loaded_files << source_file

          # Share this data with all other languages that use the same file
          @sources.each do |other_lang, other_source|
            if other_source == source_file && other_lang != lang
              Log.debug { "Language #{other_lang} shares content with #{lang} from #{source_file}" }
              @text[other_lang] = @text[lang]
              @metadata[other_lang] = @metadata[lang]
              @title[other_lang] = @title[lang]
              @html[other_lang] = @html[lang] if @html.has_key?(lang)
              @toc[other_lang] = @toc[lang] if @toc.has_key?(lang)
              # Set @link for the other language based on its @output path
              @link[other_lang] = (Path.new ["/", @output[other_lang].split("/")[1..]]).to_s
              @shortcodes[other_lang] = @shortcodes[lang] if @shortcodes.has_key?(lang)
            end
          end
        end
      end
    end

    def taxonomies
      result = Hash({name: String, link: String}, Array({name: String, link: String})).new
      Taxonomies::All.each do |taxo|
        next unless taxo.@posts.includes? self
        result[taxo.link] = taxo.@terms.values.select \
           { |term| term.@posts.includes? self }.map(&.link)
      end
      result
    end

    def source(lang = nil)
      @sources[lang || Locale.language]
    end

    def text(lang = nil)
      @text[lang || Locale.language]
    end

    def metadata(lang = nil)
      @metadata[lang || Locale.language]
    end

    def link(lang = nil)
      @link[lang || Locale.language]
    end

    def toc(lang = nil)
      @toc[lang || Locale.language]
    end

    def title(lang = nil)
      @title[lang || Locale.language]
    end

    def output(lang = nil)
      @output[lang || Locale.language]
    end

    def shortcodes(lang = nil)
      @shortcodes[lang || Locale.language]
    end

    def <=>(other : File)
      # The natural sort order is date descending
      if self.@date.nil? || other.@date.nil?
        self.title <=> other.title
      else
        # Both dates are non-nil here based on the check above
        my_date = @date.as(Time)
        other_date = other.@date.as(Time)
        -1 * (my_date <=> other_date)
      end
    end

    def to_s(io)
      io << "Post(#{@base})"
    end

    # Load the post from disk (for current language only)
    def load(lang = nil) : Nil
      lang ||= Locale.language
      Log.debug { "👉 #{source(lang)}" }
      contents = ::File.read(source(lang))
      begin
        fragments = contents.split("---\n", 3)
        # Metadata is required - must have --- separators
        raise "Missing metadata separators. All posts must have metadata between '---' delimiters." unless fragments.size >= 3

        _, raw_metadata, @text[lang] = fragments
      rescue ex
        Log.error { "Error reading metadata in #{source(lang)}: #{ex}" }
        raise ex
      end
      if raw_metadata.nil?
        @metadata[lang] = {} of String => String
        @title[lang] = ""
      else
        @metadata[lang] = YAML.parse(raw_metadata).as_h.map { |k, v| [k.as_s.downcase.strip, v.to_s] }.to_h
        @title[lang] = metadata(lang)["title"].to_s
      end
      @link[lang] = (Path.new ["/", @output[lang].split("/")[1..]]).to_s
      # Performance Note: usually parse takes ~.1 seconds to
      # parse 1000 short posts that have no shortcodes.
      @shortcodes[lang] = full_shortcodes_list(@text[lang])
    rescue ex
      Log.error { "Error parsing metadata in #{source(lang)}: #{ex}" }
      raise ex
    end

    # Parse shortcodes in the text recursively
    def full_shortcodes_list(text)
      # Fast path: if no shortcode delimiters, skip parsing entirely
      return [] of Shortcodes::Shortcode unless text.includes?("{{")

      sc_list = Shortcodes.parse(text)
      return [] of Shortcodes::Shortcode if sc_list.shortcodes.empty?

      final_list = sc_list.shortcodes
      sc_list.shortcodes.each do |scode|
        if scode.markdown? # Recurse for nested shortcodes
          # If there are nested shortcodes, handle them
          final_list += full_shortcodes_list(scode.data)
        end
      end
      Set.new(final_list).to_a
    end

    def html(lang = nil)
      lang ||= Locale.language
      @html[lang], @toc[lang] = Discount.compile(
        replace_shortcodes(lang),
        metadata(lang).fetch("toc", nil) != nil,
        flags: LibDiscount::MKD_FENCEDCODE |
               LibDiscount::MKD_TOC |
               LibDiscount::MKD_AUTOLINK |
               LibDiscount::MKD_SAFELINK |
               LibDiscount::MKD_NOPANTS |
               LibDiscount::MKD_GITHUBTAGS
      )
      # Performance Note: parsing the HTML takes ~.7 seconds for
      # 4000 short posts. Calling each filter is much faster.
      doc = Lexbor::Parser.new(@html[lang])
      doc = HtmlFilters.downgrade_headers(doc)
      @html[lang] = HtmlFilters.fix_code_classes(doc).to_html
    end

    def date : Time | Nil
      return @date if !@date.nil?
      t = metadata.fetch("date", nil)
      if t != nil
        begin
          @date = Cronic.parse(t.to_s)
        rescue ex
          # Try RFC 2822 format (common in RSS feeds and email)
          begin
            @date = Time::Format::RFC_2822.parse(t.to_s)
          rescue ex
            # Try YY/MM/DD HH:MM:SS TZ format (e.g., "16/05/14 18:14:24 UTC")
            begin
              @date = Time::Format.new("%y/%m/%d %H:%M:%S %z").parse(t.to_s)
            rescue ex
              # Try YYYY-MM-DD HH:MM:SS TZ format (e.g., "2024-08-02 13:21:11 UTC")
              # Convert named timezones to UTC offset
              begin
                date_str = t.to_s
                # Handle common timezone names by replacing them with +0000
                # This is a simple approach; for production you might want a proper timezone lib
                normalized = date_str.gsub(/ (UTC|GMT|Z)$/, " +0000")
                @date = Time::Format.new("%Y-%m-%d %H:%M:%S %z").parse(normalized)
              rescue ex
                Log.error { "Error parsing date for #{source}, #{t}" }
                Log.error { "Tried Cronic, RFC_2822, YY/MM/DD, and YYYY-MM-DD formats" }
                raise "Failed to parse date '#{t}' for #{source}"
              end
            end
          end
        end
      end
      @date
    end

    # Path for the `Templates::Template` this post should be rendered with
    def template(lang = nil)
      lang ||= Locale.language
      @metadata[lang].fetch("template", Theme.template_path("post.tmpl")).to_s
    end

    # Render the markdown HTML into the right template for the fragment
    def rendered(lang = nil)
      lang ||= Locale.language
      Templates.environment.get_template(template(lang)).render(value(lang))
    end

    def _replace_shortcodes(text : String) : String
      # Fast path: if no shortcode delimiters, skip parsing entirely
      return text unless text.includes?("{{")

      sc_list = Shortcodes.parse(text)
      return text if sc_list.shortcodes.empty?
      sc_list.errors.each do |e|
        # TODO: show actual error
        Log.error { Shortcodes.nice_error(e, text) }
      end

      # FIXME: context needs stuff
      context = Crinja::Context.new

      # Build output efficiently using IO::Memory instead of string concatenation
      output = IO::Memory.new
      last_pos = 0

      sc_list.shortcodes.each do |scode|
        if scode.markdown? # Recurse for nested shortcodes
          # If there are nested shortcodes, handle them
          scode.data = _replace_shortcodes(scode.data)
        end

        # Append text before this shortcode
        if scode.position > last_pos
          output << text[last_pos...scode.position]
        end

        # Append the rendered shortcode
        middle = Sc.render_sc(scode, context)
        output << middle

        last_pos = scode.position + scode.whole.size
      end

      # Append remaining text after last shortcode
      if last_pos < text.size
        output << text[last_pos..]
      end

      output.to_s
    end

    def replace_shortcodes(lang)
      lang ||= Locale.language
      _replace_shortcodes(text(lang))
    end

    def summary(lang = nil)
      lang ||= Locale.language
      return metadata(lang)["summary"] if metadata(lang).has_key?("summary")
      # Split HTML in the comment
      if html(lang).includes?("<!--more-->")
        html(lang).split("<!--more-->")[0]
      else
        html(lang)
      end
    end

    # What to show as breadcrumbs for this post
    def breadcrumbs(lang = nil)
      lang ||= Locale.language
      result = [] of NamedTuple(name: String, link: String)

      output_path = Path[output(lang)]
      parts = output_path.parts

      # Skip "output" directory and build breadcrumbs from remaining path parts
      # For example: output/docs/continuous_import.html -> docs -> continuous_import
      if parts.size >= 2 && parts[0] == "output"
        # Check if this is the home page (index.html at root)
        if parts.size == 2 && parts[1] == "index.html"
          # This IS the home page, no breadcrumbs needed
          return [{name: title(lang), link: link(lang)}]
        end

        # Not the home page, add "Home" as first breadcrumb
        result << {name: "Home", link: "/"}

        # Build breadcrumb path incrementally
        current_path = ""
        parts[1..-2].each do |part|
          current_path = Path[current_path] / part
          result << {
            name: part,
            link: Utils.path_to_link(Path[Config.options(lang).output] / Path[current_path] / "index.html"),
          }
        end
      end

      # Add the current page title
      result << {name: title(lang), link: link(lang)}
      result
    end

    # Check if the updated date should be shown (at least 1 minute different from post date)
    def show_updated?(lang = nil)
      lang ||= Locale.language
      return false if @date.nil?

      updated_str = metadata(lang).fetch("updated", nil)
      return false if updated_str.nil?

      # Try to parse the updated date
      begin
        updated_time = Cronic.parse(updated_str)
        return false if updated_time.nil?
        # Show if updated is at least 1 minute (60 seconds) after the original date
        (updated_time - @date.as(Time)) >= Time::Span.new(seconds: 60)
      rescue
        false
      end
    end

    # Return a value Crinja can use in templates
    def value(lang = nil)
      lang = lang || Locale.language
      {
        "breadcrumbs"    => breadcrumbs(lang),
        "date"           => date.try &.as(Time).to_s(Config.options(lang).date_output_format),
        "html"           => html(lang),
        "link"           => link(lang),
        "source"         => source(lang),
        "summary"        => summary(lang),
        "taxonomies"     => taxonomies,
        "title"          => title(lang),
        "toc"            => toc(lang),
        "metadata"       => metadata(lang),
        "show_updated"   => show_updated?(lang),
        "related_posts"  => related_posts(lang),
        "language_links" => language_links(lang),
      }
    end

    # Get language alternate links for this post
    # Returns an array of Hash for Crinja compatibility
    def language_links(lang : String? = nil)
      lang ||= Locale.language
      result = [] of Hash(String, String)

      # For each configured language, check if we have this post
      Config.languages.keys.each do |other_lang|
        # Skip the current language
        next if other_lang == lang

        # Check if this post has content in the other language
        # (it will if the languages share a source file or have language-specific files)
        if @sources.has_key?(other_lang)
          result << {
            "lang"  => other_lang,
            "link"  => link(other_lang),
            "title" => title(other_lang),
          }
        end
      end

      result
    end

    # Get related posts based on similarity
    def related_posts(lang = nil)
      lang ||= Locale.language
      features = Config.get("features").as_a.map(&.as_s)
      return [] of Hash(String, String | Float64) unless features.includes?("similarity")

      # Only try to find related posts if signatures exist
      # This avoids errors during initial build or when signatures aren't ready
      begin
        Similarity.find_related(self, lang, 5)
      rescue
        [] of Hash(String, String | Float64)
      end
    end

    # List of all files and kv store items this post uses
    def dependencies : Array(String)
      page_template = Theme.template_path("page.tmpl")
      result = ["conf.yml", "kv://#{page_template}"]
      result << source
      result << "kv://#{template}"

      # Validate that all referenced shortcodes exist
      available = Sc.available_shortcodes
      shortcodes.reject(&.is_inline?).each do |scode|
        unless available.includes?(scode.name)
          raise "Unknown shortcode '#{scode.name}' in #{source}\n" +
                "Available shortcodes: #{available.join(", ")}"
        end
      end

      result += shortcodes.reject(&.is_inline?).map { |scode| "kv://shortcodes/#{scode.name}.tmpl" }

      # Add similarity index as dependency if feature is enabled
      features = Config.get("features").as_a.map(&.as_s)
      if features.includes?("similarity")
        result << "kv://similarity/index/en"
      end

      result
    end
  end

  # Render given posts using given template
  #
  # posts is an Array of `Markdown::File`
  # if require_date is true, posts *must* have a date
  def self.render(posts, require_date = true)
    Config.languages.keys.each do |lang|
      posts.each do |post|
        if require_date && post.date == nil
          Log.error { "Error: #{post.source lang} has no date" }
          next
        end
        Croupier::Task.new(
          id: "markdown",
          output: post.output(lang),
          inputs: post.dependencies,
          mergeable: false
        ) do
          begin
            # Need to refresh post contents
            post.load lang if Croupier::TaskManager.auto_mode?
            Log.info { "👉 #{post.output lang}" }
            template_vars = {
              "content"        => post.rendered(lang),
              "title"          => post.title(lang),
              "breadcrumbs"    => post.breadcrumbs(lang),
              "language_links" => post.language_links(lang),
            }
            html = Render.apply_template(Theme.template_path("page.tmpl"), template_vars)
            doc = Lexbor::Parser.new(html)
            doc = HtmlFilters.make_links_relative(doc, post.link(lang))
            HtmlFilters.fix_code_classes(doc).to_html
          rescue ex
            Log.error { "Error rendering post: #{post.source(lang)}" }
            Log.error { "#{ex.class}: #{ex.message}" }
            ex.backtrace.each { |line| Log.error { "  #{line}" } }
            raise ex
          end
        end
      end
    end
  end

  # Similar to self.render but it only validates correctness of posts
  # without actually generating output
  def self.validate(posts, require_date = true)
    error_count = 0
    Config.languages.keys.each do |lang|
      posts.each do |post|
        if require_date && post.date == nil
          error_count += 1
          Log.error { "Error: #{post.source lang} has no date" }
          next
        end
      end
    end
    error_count
  end

  # Create an index page out of a list of posts, save in output
  def self.render_index(posts, output, title = nil, extra_inputs = [] of String, extra_feed = nil, lang = nil)
    lang ||= Locale.language
    index_template = Theme.template_path("index.tmpl")
    page_template = Theme.template_path("page.tmpl")
    inputs = [
      "conf.yml",
      "kv://#{index_template}",
      "kv://#{page_template}",
    ] + posts.map(&.source) + posts.map(&.template) + extra_inputs
    inputs = inputs.uniq
    Croupier::Task.new(
      id: "index",
      output: output.to_s,
      inputs: inputs,
      mergeable: false
    ) do
      Log.info { "👉 #{output}" }
      # Sort posts by date descending (newest first), posts without dates go last
      sorted_posts = posts.sort_by { |post| post.date || Time.utc(1970, 1, 1) }.reverse!

      # Limit to 100 posts for index pages
      has_more = sorted_posts.size > 100
      display_posts = sorted_posts.first(100)

      content = Templates.environment.get_template(index_template).render(
        {
          "posts"    => display_posts.map(&.value(lang)),
          "has_more" => has_more,
        })

      # Calculate language links for this index
      # Get alternate language versions of this index page
      language_links = calculate_index_language_links(output, lang)

      html = Render.apply_template(page_template,
        {
          "content"        => content,
          "title"          => title,
          "noindex"        => true,
          "extra_feed"     => extra_feed,
          "language_links" => language_links,
        })
      doc = Lexbor::Parser.new(html)
      doc = HtmlFilters.make_links_relative(doc, Utils.path_to_link(output))
      HtmlFilters.fix_code_classes(doc).to_html
    end
  end

  # Calculate language alternate links for index pages
  # Returns an array of Hash for Crinja compatibility
  private def self.calculate_index_language_links(output_path : String | Path, lang : String)
    result = [] of Hash(String, String)
    output_str = output_path.to_s

    # For each configured language, check if an alternate index exists
    Config.languages.keys.each do |other_lang|
      next if other_lang == lang

      # Determine the alternate index path
      # If current is output/posts/index.html, alternate should be output/posts/index.es.html
      # If current is output/posts/index.es.html, alternate should be output/posts/index.html
      if lang == "en"
        # Current is English, look for .es.html (or other language suffixes)
        lang_suffix = ".#{other_lang}"
        alt_path = output_str.sub(/\.html$/, "#{lang_suffix}.html")
      else
        # Current is non-English (e.g., index.es.html)
        # Look for English version (no suffix)
        alt_path = output_str.sub(/\.#{lang}\.html$/, ".html")
      end

      # Check if the alternate file would exist (by checking if it's in a known location)
      # For now, we'll assume it exists if the path pattern matches
      site_title = begin
        Config.languages[other_lang].as_h["site"].as_h["title"].as_s
      rescue
        other_lang.upcase
      end
      result << {
        "lang"  => other_lang,
        "link"  => Utils.path_to_link(Path[alt_path]),
        "title" => site_title,
      }
    end

    result
  end

  # Create a RSS file out of posts with title, save in output
  def self.render_rss(posts, output, title)
    inputs = ["conf.yml"] + posts.map(&.source)

    Croupier::Task.new(
      id: "rss",
      output: output.to_s,
      inputs: inputs,
      mergeable: false
    ) do
      Log.info { "👉 #{output}" }
      feed = RSS.new title: title
      posts.each do |post|
        feed.item(
          title: post.title,
          description: post.summary,
          link: post.link,
          pubDate: post.date.to_s,
        )
      end
      feed.xml indent: true
    end
  end

  # Parse all markdown posts in a path and build Markdown::File
  # objects out of them
  def self.read_all(path)
    Log.debug { "Reading Markdown from #{path}" }
    posts = [] of File
    all_sources = Utils.find_all(path, "md")
    all_sources.map do |base, sources|
      next if File.posts.keys.includes? base.to_s
      next if Utils.should_skip_file?(base)

      posts << File.new(sources, base)
    end
    posts
  end

  # Create a new "page" file
  def self.new_page(path)
    path = path / "index.md" unless path.to_s.ends_with? ".md"
    Log.info { "Creating new page #{path}" }
    raise "#{path} already exists" if ::File.exists? path
    Dir.mkdir_p(path.dirname)
    ::File.open(path, "w") do |io|
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

  # Create a new "post" file
  def self.new_post(path)
    path = path / "index.md" unless path.to_s.ends_with? ".md"
    Log.info { "Creating new post #{path}" }
    raise "#{path} already exists" if ::File.exists? path
    Dir.mkdir_p(path.dirname)
    ::File.open(path, "w") do |io|
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
end
