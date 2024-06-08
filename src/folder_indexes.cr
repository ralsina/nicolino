module FolderIndexes
  # Generates indexes for folders that have no index file
  struct FolderIndex
    @contents : Array(String)
    @output : Path

    def initialize(path : Path)
      @path = path
      @output = (@path / "index.html").relative_to Config.options.content
      @contents = Dir.glob("#{@path}/*").select! { |p| File.file? p }
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
        Log.info { "👈 #{folder}" }
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
        Croupier::Task.new(
          id: "folder_index",
          output: (out_path / index.@output).to_s,
          # FIXME: find correct way to use contents of folder as dependencies
          inputs: inputs,
          mergeable: false,
          proc: Croupier::TaskProc.new {
            Log.info { "👉 #{index.@output}" }
            Render.apply_template("templates/page.tmpl",
              {"content" => index.rendered, "title" => index.@path.basename})
          }
        )
      end
    end
  end
end
