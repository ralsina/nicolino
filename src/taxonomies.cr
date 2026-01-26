require "./utils"
require "./rss"
require "./theme"

# FIXME: Get rid of the named tuples

module Taxonomies
  include Utils

  # Enable taxonomies feature if posts are available
  def self.enable(is_enabled : Bool, posts : Array(Markdown::File))
    return unless is_enabled

    Log.info { "🏷️  Processing taxonomies..." }

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

    Log.info { "✓ Taxonomies queued" }
  end

  # Register output folder to exclude from folder_indexes
  # Default is "tags/" but can be configured
  Config.taxonomies.each do |name, taxonomy|
    FolderIndexes.register_exclude(taxonomy.location)
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

    # Lightweight value for taxonomy templates (doesn't render posts)
    def lightweight_value
      {
        "name" => @name,
      }
    end

    def link(lang = nil)
      lang ||= Locale.language
      {
        name: @name,
        link: Utils.path_to_link Path[Config.options(lang).output] / "#{@taxonomy.@path}/#{Utils.slugify(@name)}/index.html",
      }
    end
  end

  # A Taxonomy, which means "a way to classify posts"
  class Taxonomy
    # Initialize the taxonomy out of descriptive data
    # and a list of posts to be classified

    @terms = Hash(String, Term).new
    @posts = Array(Markdown::File).new
    @name : String

    property title : String
    property term_title : String
    property path : String

    def initialize(
      @name,
      @title,
      @term_title,
      @path,
      @posts : Array(Markdown::File),
    )
      @posts.each do |post|
        # Get pre-parsed taxonomy terms for this post
        post_taxonomies = post.taxonomy_terms
        post_terms = post_taxonomies.fetch(@name, nil)
        next if post_terms.nil?

        post_terms.each do |term|
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

    # Lightweight value for taxonomy templates (doesn't render posts)
    def lightweight_value(lang)
      {
        "name"  => @name,
        "terms" => @terms.values.map(&.lightweight_value),
      }
    end

    def link(lang = nil)
      lang ||= Locale.language
      # FIXME localize link
      {name: @title, link: Utils.path_to_link Path[Config.options(lang).output] / "#{@path}/index.html"}
    end

    def render
      # Render taxonomy index
      Config.languages.keys.each do |lang|
        # Make output path language-specific to avoid conflicts
        # For example: tags/ for en and es/ for other languages
        # Only add language suffix if not the default language
        lang_suffix = lang == "en" ? "" : ".#{lang}"
        base_path = Path[Config.options(lang).output] / Path["#{@path.chomp('/')}#{lang_suffix}"]
        output = (base_path / "index.html").to_s
        page_template = Theme.template_path("page.tmpl")
        title_template = Theme.template_path("title.tmpl")
        taxonomy_template = Theme.template_path("taxonomy.tmpl")

        # Create breadcrumbs for taxonomy index
        taxonomy_link = Utils.path_to_link(
          Path[Config.options(lang).output] / "#{@path.chomp('/')}#{lang_suffix}/"
        )
        breadcrumbs = [
          {name: "Home", link: "/"},
          {name: @title, link: taxonomy_link},
        ] of NamedTuple(name: String, link: String)

        # Include title.tmpl which handles breadcrumbs
        title_html = Templates.environment.get_template(title_template).render({
          "title"       => @title,
          "link"        => Utils.path_to_link(Path[Config.options(lang).output] / "#{@path}/"),
          "breadcrumbs" => breadcrumbs,
          "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
        })

        rendered = Templates.environment.get_template(taxonomy_template).render({"taxonomy" => lightweight_value(lang)})

        FeatureTask.new(
          feature_name: "taxonomies",
          id: "taxonomy",
          output: output,
          inputs: @posts.flat_map(&.dependencies) + ["kv://#{taxonomy_template}", "kv://#{title_template}"],
          mergeable: false
        ) do
          Log.info { "👉 #{output}" }
          html = Render.apply_template(page_template,
            {
              "content"     => title_html + rendered,
              "title"       => @title,
              "breadcrumbs" => breadcrumbs,
            })
          doc = Lexbor::Parser.new(html)
          doc = HtmlFilters.make_links_relative(doc, Utils.path_to_link(output))
          HtmlFilters.fix_code_classes(doc).to_html
        end

        @terms.values.each do |term|
          feed_path = (base_path / "#{Utils.slugify(term.@name)}/index.rss").normalize.to_s
          title = Crinja.render(@term_title, {
            "term" => term.lightweight_value,
          })
          # Render term RSS for each term with language context
          RSSFeed.render(
            term.@posts,
            feed_path,
            title,
            lang: lang,
          )

          # Render term index for each term
          Markdown.render_index(
            term.@posts[..10],
            (base_path / "#{Utils.slugify(term.@name)}/index.html").normalize.to_s,
            title,
            extra_feed: {link: Utils.path_to_link(feed_path), title: "#{title} RSS"},
            main_feed: nil, # Taxonomy term pages don't get main feed
            lang: lang,
          )
        end
      end
    end
  end

  All = Array(Taxonomy).new
end
