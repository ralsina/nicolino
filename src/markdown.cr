require "./html_filters"
require "./sc"
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
        -1 * (self.@date.as(Time) <=> other.@date.as(Time))
      end
    end

    def to_s(io)
      io << "Post(#{@base})"
    end

    # Load the post from disk (for current language only)
    def load(lang = nil) : Nil
      lang ||= Locale.language
      Log.debug { "👈 #{source(lang)}" }
      contents = ::File.read(source(lang))
      begin
        fragments = contents.split("---\n", 3)
        if fragments.size >= 3
          _, raw_metadata, @text[lang] = fragments
        else
          # No metadata
          raw_metadata = nil
          @text[lang] = contents
        end
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
      sc_list = Shortcodes.parse(text)
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
          Log.error { "Error parsing date for #{source}, #{t}" }
          @date = nil
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
      Templates::Env.get_template(template(lang)).render(value(lang))
    end

    def _replace_shortcodes(text : String) : String
      sc_list = Shortcodes.parse(text)
      return text if sc_list.shortcodes.empty?
      sc_list.errors.each do |e|
        # TODO: show actual error
        Log.error { Shortcodes.nice_error(e, text) }
      end
      # Starting at the end of text, go backwards
      # replacing each shortcode with its output

      # FIXME: context needs stuff
      context = Crinja::Context.new
      sc_list.shortcodes.reverse_each do |scode|
        if scode.markdown? # Recurse for nested shortcodes
          # If there are nested shortcodes, handle them
          scode.data = _replace_shortcodes(scode.data)
        end
        middle = Sc.render_sc(scode, context)
        if scode.position > 0
          text = text[...scode.position] +
                 middle +
                 text[(scode.position + scode.whole.size)..]
        else
          text = middle +
                 text[(scode.position + scode.whole.size)..]
        end
      end
      text
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
      # For blog posts, breadcrumb goes to the index
      return [{name: "Posts",
               link: Utils.path_to_link(Path[Config.options(lang).output] /
                                        "posts/index.html")},
              {name: title(lang)}] if date
      # FIXME this should be the path to the page
      [] of String
    end

    # Return a value Crinja can use in templates
    def value(lang = nil)
      lang = lang || Locale.language
      {
        "breadcrumbs" => breadcrumbs(lang),
        "date"        => date.try &.as(Time).to_s(Config.options(lang).date_output_format),
        "html"        => html(lang),
        "link"        => link(lang),
        "source"      => source(lang),
        "summary"     => summary(lang),
        "taxonomies"  => taxonomies,
        "title"       => title(lang),
        "toc"         => toc(lang),
        "metadata"    => metadata(lang),
      }
    end

    # List of all files and kv store items this post uses
    def dependencies : Array(String)
      result = ["conf.yml", "kv://templates/page.tmpl"]
      result << source
      result << "kv://#{template}"
      result += shortcodes.reject(&.is_inline?).map { |scode| "kv://shortcodes/#{scode.name}.tmpl" }
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
          mergeable: false,
          mutex: "crinja",
          proc: Croupier::TaskProc.new {
            # Need to refresh post contents
            post.load lang if Croupier::TaskManager.auto_mode?
            Log.info { "👉 #{post.output lang}" }
            html = Render.apply_template("templates/page.tmpl",
              {"content" => post.rendered(lang), "title" => post.title(lang)})
            doc = Lexbor::Parser.new(html)
            doc = HtmlFilters.make_links_relative(doc, post.link(lang))
            doc.to_html
          }
        )
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
      mergeable: false,
      mutex: "crinja",
      proc: Croupier::TaskProc.new {
        Log.info { "👉 #{output}" }
        content = Templates::Env.get_template("templates/index.tmpl").render(
          {
            "posts" => posts.map(&.value),
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
      }
    )
  end

  # Create a RSS file out of posts with title, save in output
  def self.render_rss(posts, output, title)
    inputs = ["conf.yml"] + posts.map(&.source)

    Croupier::Task.new(
      id: "rss",
      output: output.to_s,
      inputs: inputs,
      mergeable: false,
      proc: Croupier::TaskProc.new {
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
      }
    )
  end

  # Parse all markdown posts in a path and build Markdown::File
  # objects out of them
  def self.read_all(path)
    Log.debug { "Reading Markdown from #{path}" }
    posts = [] of File
    all_sources = Utils.find_all(path, "md")
    all_sources.map do |base, sources|
      next if File.posts.keys.includes? base.to_s
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
