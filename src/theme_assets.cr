require "./theme"
require "croupier"
require "log"

module ThemeAssets
  # Copy theme assets to output/ (always enabled for themes to work)
  def self.enable
    render
  end

  # Copy assets from theme assets/ to output/
  def self.render
    Dir.glob("#{Theme.assets_dir}/**/*").each do |src|
      next if File.directory?(src)
      # Skip "themes/default/assets" parts to get relative path
      dest = Path[Config.options.output] / Path[Path[src].parts[3..]]
      FeatureTask.new(
        feature_name: "theme_assets",
        id: "theme_assets",
        output: dest.to_s,
        inputs: [src],
        mergeable: false,
        no_save: true) do
        Log.info { "🎨 #{dest}" }
        Dir.mkdir_p(dest.parent)
        File.copy(src, dest)
      end
    end
  end
end
