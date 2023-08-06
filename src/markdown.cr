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
    @shortcodes = Hash(String, Shortcodes::Result).new
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
      @sources.map { |k, _|
        p = Path[base]
        p = Path[p.parts[1..]] # Remove the leading "posts/"
        p = Path[Config.options(k).output] / p
        @output[k] = p.to_s.rchop(p.extension) + ".html"
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
           { |t| t.@posts.includes? self }.map(&.link)
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
    def load(lang = nil)
      lang ||= Locale.language
      Log.info { "👈 #{source(lang)}" }
      contents = ::File.read(source(lang))
      _, raw_metadata, @text[lang] = contents.split("---\n", 3)
      @metadata[lang] = YAML.parse(raw_metadata).as_h.map { |k, v| [k.as_s.downcase.strip, v.to_s] }.to_h
      @title[lang] = metadata(lang)["title"].to_s
      @link[lang] = (Path.new ["/", output.split("/")[1..]]).to_s
      @shortcodes[lang] = Shortcodes.parse(@text[lang])
    end

    def html(lang = nil)
      lang ||= Locale.language
      @html[lang], @toc[lang] = Discount.compile(
        replace_shortcodes(lang),
        metadata(lang).fetch("toc", nil) != nil)
      @html[lang] = HtmlFilters.downgrade_headers(@html[lang])
      @html[lang] = HtmlFilters.make_links_absolute(@html[lang], link)
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
      metadata(lang).fetch("template", "templates/post.tmpl").to_s
    end

    # Render the markdown HTML into the right template for the fragment
    def rendered(lang = nil)
      lang ||= Locale.language
      Templates::Env.get_template(template(lang)).render(value(lang))
    end

    def replace_shortcodes(lang)
      lang ||= Locale.language
      shortcodes(lang).errors.each do |e|
        # TODO: show actual error
        Log.error { "In #{source(lang)}:" }
        Log.error { Shortcodes.nice_error(e, text(lang)) }
      end
      _text = text(lang)
      # Starting at the end of text, go backwards
      # replacing each shortcode with its output
      shortcodes(lang).shortcodes.reverse_each do |sc|
        # FIXME: context needs stuff
        context = Crinja::Context.new
        _text = _text[0, sc.position] +
                Sc.render_sc(sc, context) +
                _text[sc.position + sc.len, _text.size]
      end
      _text
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
      # FIXME un-hardcode the posts/ path
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
        "date"        => date.nil? ? "" : date.as(Time).to_s(Config.options(lang).date_output_format),
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
      result = ["conf", "kv://templates/page.tmpl"]
      result << source
      result << "kv://#{template}"
      result += shortcodes.shortcodes.map { |sc| "kv://shortcodes/#{sc.name}.tmpl" }
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
          Log.info { "Error: #{post.source lang} has no date" }
          next
        end

        Croupier::Task.new(
          id: "markdown",
          output: post.output(lang),
          inputs: post.dependencies,
          mergeable: false,
          proc: Croupier::TaskProc.new {
            post.load lang # Need to refresh post contents
            Log.info { "👉 #{post.output lang}" }
            Render.apply_template("templates/page.tmpl",
              {"content" => post.rendered(lang), "title" => post.title(lang)})
          }
        )
      end
    end
  end

  # Create an index page out of a list of posts, save in output
  def self.render_index(posts, output, title = nil, extra_inputs = [] of String, extra_feed = nil)
    inputs = [
      "conf",
      "kv://templates/index.tmpl",
      "kv://templates/page.tmpl",
    ] + posts.map(&.source) + posts.map(&.template) + extra_inputs
    inputs = inputs.uniq
    Croupier::Task.new(
      id: "index",
      output: output,
      inputs: inputs,
      mergeable: false,
      proc: Croupier::TaskProc.new {
        Log.info { "👉 #{output}" }
        content = Templates::Env.get_template("templates/index.tmpl").render(
          {
            "posts" => posts.map(&.value),
          })
        Render.apply_template("templates/page.tmpl",
          {
            "content"    => content,
            "title"      => title,
            "noindex"    => true,
            "extra_feed" => extra_feed,
          })
      }
    )
  end

  # Create a RSS file out of posts with title, save in output
  def self.render_rss(posts, output, title)
    inputs = ["conf"] + posts.map(&.source)

    Croupier::Task.new(
      id: "rss",
      output: output,
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
    Log.info { "Reading Markdown from #{path}" }
    posts = [] of File
    all_sources = Utils.find_all(path, "md")
    all_sources.map do |base, sources|
      posts << File.new(sources, base)
    end
    posts
  end
end
