require "./theme"

module Assets
  # Enable assets feature if enabled
  def self.enable(is_enabled : Bool)
    return unless is_enabled
    render
  end

  # Copy assets from theme assets/ and user assets/ to output/
  def self.render
    # First copy theme assets
    Dir.glob("#{Theme.assets_dir}/**/*").each do |src|
      next if File.directory?(src)
      dest = Path[Config.options.output] / Path[Path[src].parts[2..]]
      Croupier::Task.new(
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

    # Then copy user assets (these can override theme assets)
    Dir.glob("assets/**/*").each do |src|
      next if File.directory?(src)
      dest = Path[Config.options.output] / Path[Path[src].parts[1..]]
      Croupier::Task.new(
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
