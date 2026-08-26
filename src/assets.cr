require "./theme"

module Assets
  # Enable assets feature if enabled
  def self.enable(is_enabled : Bool)
    return unless is_enabled

    Log.info { "📦 Copying assets..." }
    render
    Log.info { "✓ Assets queued" }
  end

  # Copy assets from user assets/ to output/
  def self.render
    Dir.glob("assets/**/*").each do |src|
      next if File.directory?(src)
      # Skip files the theme already provides — theme assets
      # take priority, otherwise Croupier sees two tasks writing
      # to the same output path and refuses to merge them.
      rel = Path[Path[src].parts[1..]]
      next if File.exists?(Path[Theme.assets_dir] / rel)
      dest = Path[Config.options.output] / rel
      FeatureTask.new(
        feature_name: "assets",
        id: "assets",
        output: dest.to_s,
        inputs: [src],
        mergeable: false,
        no_save: true) do
        Log.info { "👉 #{dest}" }
        Dir.mkdir_p(dest.parent)
        File.copy(src, dest)
      end
    end
  end
end
