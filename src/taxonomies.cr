module Taxonomies
  class Term
    @name : String
    @posts : Array(Markdown::File) = Array(Markdown::File).new

    def initialize(@name : String)
    end

    def value
      {
        "name"  => @name,
        "posts" => @posts.map(&.value),
      }
    end
  end

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
        post_terms = post.@metadata.fetch("#{@name}", nil)
        next if post_terms.nil?
        post_terms = YAML.parse(post_terms).as_a.map(&.to_s)
        post_terms.each do |term|
          term = term.strip
          if !@terms.has_key?(term)
            @terms[term] = Term.new(term)
          end
          @terms[term].@posts << post
        end
      end
    end

    def value
      {
        "name"  => @name,
        "terms" => @terms.values.map(&.value),
      }
    end

    def render
      # Render taxonomy index
      output = "#{@path}/index.html"
      rendered = Templates::Env.get_template("templates/taxonomy.tmpl").render({"taxonomy" => value})

      Croupier::Task.new(
        id: "taxonomy",
        output: output,
        inputs: @posts.flat_map(&.dependencies) + ["kv://templates/taxonomy.tmpl"],
        mergeable: false,
        proc: Croupier::TaskProc.new {
          Log.info { ">> #{output}" }
          Render.apply_template("templates/page.tmpl",
            {"content" => rendered})
        }
      )

      @terms.values.each do |term|
        # Render term index for each term
        term.@posts.sort!
        Markdown.render_index(
          term.@posts[..10],
          "#{@path}/#{term.@name}/index.html",
          Crinja.render(@term_title, {"term" => term.value}),
        )
        # Render term RSS for each term
        Markdown.render_rss(
          term.@posts[..10],
          "#{@path}/#{term.@name}/index.rss",
          Crinja.render(@term_title, {"term" => term.value}),
        )
      end
    end
  end
end
