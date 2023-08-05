require "./utils"

module Taxonomies
  include Utils

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

    def link
      {
        name: @name,
        link: Utils.path_to_link "#{@taxonomy.@path}/#{Utils.slugify(@name)}/index.html",
      }
    end
  end

  # A Taxonomy, which means "a way to classify posts"
  class Taxonomy
    # Initialize the taxonomy out of descriptive data
    # and a list of posts to be classified

    @terms = Hash(String, Term).new
    @posts : Array(Markdown::File) = Array(Markdown::File).new

    def initialize(
      @name : String,
      @title : String,
      @term_title : String,
      @path : String,
      @posts : Array(Markdown::File)
    )
      @posts.each do |post|
        post_terms = post.@metadata.fetch(@name, nil)
        next if post_terms.nil?
        begin
          post_terms = YAML.parse(post_terms).as_a.map(&.to_s).reject(&.empty?)
        rescue ex
          # Alternative form tags: foo, bar
          post_terms = post.@metadata[@name] \
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

    def value
      {
        "name"  => @name,
        "terms" => @terms.values.map(&.value),
      }
    end

    def link
      {name: @title, link: Utils.path_to_link "#{@path}/index.html"}
    end

    def render
      # Render taxonomy index
      output = Path["#{@path}/index.html"].normalize.to_s
      rendered = Templates::Env.get_template("templates/taxonomy.tmpl").render({"taxonomy" => value})

      Croupier::Task.new(
        id: "taxonomy",
        output: output,
        inputs: @posts.flat_map(&.dependencies) + ["kv://templates/taxonomy.tmpl"],
        mergeable: false,
        proc: Croupier::TaskProc.new {
          Log.info { "👉 #{output}" }
          Render.apply_template("templates/page.tmpl",
            {"content" => rendered})
        }
      )

      @terms.values.each do |term|
        term.@posts.sort!
        feed_path = Path["#{@path}/#{Utils.slugify(term.@name)}/index.rss"].normalize.to_s
        title = Crinja.render(@term_title, {
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
          Path["#{@path}/#{Utils.slugify(term.@name)}/index.html"].normalize.to_s,
          title,
          extra_feed: {link: Utils.path_to_link(feed_path), title: "#{title} RSS"},
        )
      end
    end
  end

  All = Array(Taxonomy).new
end
