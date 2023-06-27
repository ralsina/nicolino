module Assets
  # Copy assets from assets/ to output/
  def self.render
    Dir.glob("assets/**/*").each do |src|
      dest = Path.new(["output"] + Path[src].parts[1..])
      Croupier::Task.new(
        output: dest.to_s,
        inputs: [src],
        proc: Croupier::TaskProc.new {
          Log.info { "    #{dest}" }
          File.copy(src, dest)
        },
        no_save: true,
      )
    end
  end
end
