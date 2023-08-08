module Assets
  # Copy assets from assets/ to output/
  def self.render
    Dir.glob("assets/**/*").each do |src|
      next if File.directory?(src)
      dest = Path[Config.options.output] / Path[Path[src].parts[1..]]
      Croupier::Task.new(
        id: "assets",
        output: dest.to_s,
        inputs: [src],
        mergeable: false,
        no_save: true,
        proc: Croupier::TaskProc.new {
          Log.info { "👉 #{dest}" }
          Dir.mkdir_p(dest.parent)
          File.copy(src, dest)
        },
        no_save: true,
      )
    end
  end
end
