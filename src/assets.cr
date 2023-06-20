module Assets
  # Copy assets from assets/ to output/
  def self.render
    Dir.glob("assets/**/*").each do |src|
      dest = Path.new(["output"] + Path[src].parts[1..])
      Croupier::Task.new(
        name: "render:assets:#{dest}",
        output: dest.to_s,
        inputs: [src],
        proc: Croupier::TaskProc.new {
          Util.log("    #{dest}")
          File.copy(src, dest)
        },
        no_save: true,
      )
    end
  end
end
