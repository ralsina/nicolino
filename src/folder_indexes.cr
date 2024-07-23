module FolderIndexes
  # Generates indexes for folders that have no index file
  struct FolderIndex
    @contents : Array(String)
    @output : Path

    def initialize(path : Path)
      @path = path
      @output = (@path / "index.html").relative_to Config.options.content
      @contents = Dir.glob("#{@path}/*").select! { |item| File.file? item }
    end

    def rendered
      Render.apply_template("templates/folder_index.tmpl", {
        "title"    => @path.basename,
        "path"     => @path.to_s,
        "contents" => @contents.map(&.to_s), # FIXME: find a reasonable way to do this
        # "posts" => Markdown.read_all(@path),
      })
    end
  end

  def self.read_all(path : Path) : Array(FolderIndex)
    indexes = [] of FolderIndex
    candidates = [path] + Dir.glob("#{path}/**/*/")
    candidates.map do |folder|
      if Dir.glob("#{folder}/index.*").empty?
        Log.debug { "👈 #{folder}" }
        indexes << FolderIndex.new(Path.new(folder))
      end
    end
    indexes
  end

  def self.render(indexes : Array(FolderIndex))
    Config.languages.keys.each do |lang|
      out_path = Path.new(Config.options(lang).output)
      indexes.each do |index|
        inputs = ["kv://templates/folder_index.tmpl"] + index.@contents
        output = (out_path / index.@output).to_s
        Croupier::Task.new(
          id: "folder_index",
          output: output,
          # FIXME: find correct way to use contents of folder as dependencies
          inputs: inputs,
          mergeable: false,
          proc: Croupier::TaskProc.new {
            Log.info { "👉 #{index.@output}" }
            html = Render.apply_template("templates/page.tmpl",
              {"content" => index.rendered, "title" => index.@path.basename})
            doc = Lexbor::Parser.new(html)
            doc = HtmlFilters.make_links_relative(doc, Utils.path_to_link(output))
            doc.to_html
          }
        )
      end
    end
  end
end
