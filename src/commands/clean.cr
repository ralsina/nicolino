def clean(options, arguments)
  load_config(options)
  create_tasks
  existing = Set.new(Dir.glob(Path[Config.options.output] / "**/*"))
  targets = Set.new(Croupier::TaskManager.tasks.keys)
  targets = targets.map { |p| Path[p].normalize.to_s }
  to_clean = existing - targets
  # Only delete files
  to_clean.each do |p|
    next if File.info(p).directory?
    Log.warn { "❌ #{p}" }
    File.delete(p)
  end
end
