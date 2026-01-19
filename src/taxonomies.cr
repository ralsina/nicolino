require "./utils"

# FIXME: Get rid of the named tuples

module Taxonomies
  include Utils

  # Enable taxonomies feature if posts are available
  def self.enable(is_enabled : Bool, posts : Array(Markdown::File))
    return unless is_enabled

    Config.taxonomies.map do |k, v|
      Log.debug { "Scanning taxonomy: #{k}" }
      Taxonomy.new(
        k,
        v.title,
        v.term_title,
        v.location,
        posts
      ).render
    end
  end

  # Register output folder to exclude from folder_indexes
  # Default is "tags/" but can be configured
  begin
    tax_config = Config.get("taxonomies")
    if tax_config.as_h?
      tax_config.as_h.each do |name, config|
        location = config.as_h?.try(&.["location"]?.try(&.as_s)) || "#{name}/"
        FolderIndexes.register_exclude(location)
      end
    end
  rescue
    # No taxonomies configured, skip registration
  end

  # A Taxonomy Term, which is one of the classifications
  # within a taxonomy
  class Term
    @name : String
    @posts : Array(Markdown::File) = Array(Markdown::File).new
    @taxonomy : Taxonomy

    def initialize(@name, @taxonomy)
    end

    def value
      {
        "name"  => @name,
        "posts" => @posts.map(&.value),
      }
    end

    def link(lang = nil)
      lang ||= Locale.language
      {
        name: @name,
        link: Utils.path_to_link Path[Config.options(lang).output] / "#{@taxonomy.@path[lang]}/#{Utils.slugify(@name)}/index.html",
      }
    end
  end

  # A Taxonomy, which means "a way to classify posts"
  class Taxonomy
    # Initialize the taxonomy out of descriptive data
    # and a list of posts to be classified

    @terms = Hash(String, Term).new
    @posts = Array(Markdown::File).new
    @title = Hash(String, String).new
    @term_title = Hash(String, String).new
    @path = Hash(String, String).new
    @name : String

    def initialize(
      @name,
      @title,
      @term_title,
      @path,
      @posts : Array(Markdown::File),
    )
      @posts.each do |post|
        # Get metadata for the current locale language
        post_metadata = post.metadata
        post_terms = post_metadata.fetch(@name, nil)
        next if post_terms.nil?
        begin
          post_terms = YAML.parse(post_terms).as_a.map(&.to_s).reject(&.empty?)
        rescue ex
          # Alternative form tags: foo, bar
          post_terms = post_metadata[@name] \
            .split(",").map(&.to_s.strip).reject(&.empty?)
        end
        post_terms.as(Array(String)).each do |term|
          term = term.strip
          if !@terms.has_key?(term)
            @terms[term] = Term.new(term, self)
          end
          @terms[term].@posts << post
        end
      end
      All << self
    end

    def value(lang)
      {
        "name"  => @name,
        "terms" => @terms.values.map(&.value),
      }
    end

    def link(lang = nil)
      lang ||= Locale.language
      # FIXME localize link
      {name: @title[lang], link: Utils.path_to_link Path[Config.options(lang).output] / "#{@path[lang]}/index.html"}
    end

    def render
      # Render taxonomy index
      Config.languages.keys.each do |lang|
        # Make output path language-specific to avoid conflicts
        # For example: tags/ for en and es/ for other languages
        # Only add language suffix if not the default language
        lang_suffix = lang == "en" ? "" : ".#{lang}"
        base_path = Path[Config.options(lang).output] / Path["#{@path[lang].chomp('/')}#{lang_suffix}"]
        output = (base_path / "index.html").to_s

        # Create breadcrumbs for taxonomy index
        taxonomy_link = Utils.path_to_link(
          Path[Config.options(lang).output] / "#{@path[lang].chomp('/')}#{lang_suffix}/"
        )
        breadcrumbs = [
          {name: "Home", link: "/"},
          {name: @title[lang], link: taxonomy_link},
        ] of NamedTuple(name: String, link: String)

        # Include title.tmpl which handles breadcrumbs
        title_html = Templates.environment.get_template("templates/title.tmpl").render({
          "title"       => @title[lang],
          "link"        => Utils.path_to_link(Path[Config.options(lang).output] / "#{@path[lang]}/"),
          "breadcrumbs" => breadcrumbs,
          "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
        })

        rendered = Templates.environment.get_template("templates/taxonomy.tmpl").render({"taxonomy" => value(lang)})

        Croupier::Task.new(
          id: "taxonomy",
          output: output,
          inputs: @posts.flat_map(&.dependencies) + ["kv://templates/taxonomy.tmpl", "kv://templates/title.tmpl"],
          mergeable: false
        ) do
          Log.info { "👉 #{output}" }
          html = Render.apply_template("templates/page.tmpl",
            {
              "content"     => title_html + rendered,
              "title"       => @title[lang],
              "breadcrumbs" => breadcrumbs,
            })
          doc = Lexbor::Parser.new(html)
          doc = HtmlFilters.make_links_relative(doc, Utils.path_to_link(output))
          HtmlFilters.fix_code_classes(doc).to_html
        end

        @terms.values.each do |term|
          term.@posts.sort!
          feed_path = (base_path / "#{Utils.slugify(term.@name)}/index.rss").normalize.to_s
          title = Crinja.render(@term_title[lang], {
            "term" => term.value,
          })
          # Render term RSS for each term
          Markdown.render_rss(
            term.@posts[..10],
            feed_path,
            title,
          )

          # Render term index for each term
          Markdown.render_index(
            term.@posts[..10],
            (base_path / "#{Utils.slugify(term.@name)}/index.html").normalize.to_s,
            title,
            extra_feed: {link: Utils.path_to_link(feed_path), title: "#{title} RSS"},
            lang: lang,
          )
        end
      end
    end
  end

  All = Array(Taxonomy).new
end
