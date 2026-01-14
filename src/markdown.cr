require "./html_filters"
require "./sc"
require "./similarity"
require "./taxonomies"
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
        # FIXME: posts/ is configurable
        # Remove the leading "posts/"
        p = Path[p.parts].relative_to Config.options.content
        p = Path[Config.options(lang).output] / p
        @output[lang] = "#{p}.html"
      }
      @@posts[base.to_s] = self
      Config.languages.keys.each do |lang|
        load lang
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
      @link[lang] = (Path.new ["/", output.split("/")[1..]]).to_s
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
      @html[lang] = doc.to_html
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
      @metadata[lang].fetch("template", "templates/post.tmpl").to_s
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
      # For blog posts, detect the actual section from the path
      if date
        # Get the section from the output path (e.g., "blog" or "posts")
        output_path = Path[output(lang)]
        # The path is usually output/section/file.html or output/section/subsection/file.html
        parts = output_path.parts
        section = if parts.size >= 2 && parts[0] == "output"
                    parts[1] # Get "blog", "posts", etc.
                  else
                    "posts" # Fallback
                  end

        [{name: "Home",
          link: "/"},
         {name: section.capitalize,
          link: Utils.path_to_link(Path[Config.options(lang).output] / "#{section}/index.html")},
         {name: title(lang),
          link: link(lang)}]
      else
        # For pages without dates, just show the title
        [{name: title(lang),
          link: link(lang)}] of {name: String, link: String}
      end
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
        "breadcrumbs"   => breadcrumbs(lang),
        "date"          => date.try &.as(Time).to_s(Config.options(lang).date_output_format),
        "html"          => html(lang),
        "link"          => link(lang),
        "source"        => source(lang),
        "summary"       => summary(lang),
        "taxonomies"    => taxonomies,
        "title"         => title(lang),
        "toc"           => toc(lang),
        "metadata"      => metadata(lang),
        "show_updated"  => show_updated?(lang),
        "related_posts" => related_posts(lang),
      }
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
      result = ["conf.yml", "kv://templates/page.tmpl"]
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
            html = Render.apply_template("templates/page.tmpl",
              {"content" => post.rendered(lang), "title" => post.title(lang)})
            doc = Lexbor::Parser.new(html)
            doc = HtmlFilters.make_links_relative(doc, post.link(lang))
            doc.to_html
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
  def self.render_index(posts, output, title = nil, extra_inputs = [] of String, extra_feed = nil)
    inputs = [
      "conf.yml",
      "kv://templates/index.tmpl",
      "kv://templates/page.tmpl",
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
      sorted_posts = posts.sort_by { |p| p.date || Time.utc(1970, 1, 1) }.reverse
      content = Templates.environment.get_template("templates/index.tmpl").render(
        {
          "posts" => sorted_posts.map(&.value),
        })
      html = Render.apply_template("templates/page.tmpl",
        {
          "content"    => content,
          "title"      => title,
          "noindex"    => true,
          "extra_feed" => extra_feed,
        })
      doc = Lexbor::Parser.new(html)
      doc = HtmlFilters.make_links_relative(doc, Utils.path_to_link(output))
      doc.to_html
    end
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
      io << Crinja.render(::File.read(Path["models", "page.tmpl"]), {date: "#{Time.local}"})
    end
  end

  # Create a new "post" file
  def self.new_post(path)
    path = path / "index.md" unless path.to_s.ends_with? ".md"
    Log.info { "Creating new post #{path}" }
    raise "#{path} already exists" if ::File.exists? path
    Dir.mkdir_p(path.dirname)
    ::File.open(path, "w") do |io|
      io << Crinja.render(::File.read(Path["models", "post.tmpl"]), {date: "#{Time.local}"})
    end
  end
end
