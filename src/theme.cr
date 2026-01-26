require "file_utils"
require "log"
require "./commands/init"

module Theme
  # Get the current theme name from config
  def self.name
    Config.options.theme
  end

  # Get the path to the theme directory
  # Resolves theme path from local themes/ directory or extracts baked-in default
  def self.path
    theme_path = Path["themes", name]

    # If theme exists locally, use it
    if Dir.exists?(theme_path)
      return theme_path.to_s
    end

    # If it's "default" and doesn't exist, extract from baked-in
    if name == "default"
      ensure_default_theme
      return theme_path.to_s
    end

    # Otherwise, theme is not installed
    raise "Theme '#{name}' not found in themes/#{name}/. Install it with: nicolino theme install #{name}"
  end

  # Get the path to the templates directory for the current theme
  def self.templates_dir
    "#{path}/templates"
  end

  # Get the path to the assets directory for the current theme
  def self.assets_dir
    "#{path}/assets"
  end

  # Get the full path to a template file
  def self.template_path(template : String) : String
    "#{templates_dir}/#{template}"
  end

  # Ensure the default theme is extracted from baked-in files
  # This is defined in commands/init.cr as ThemeFiles
  private def self.ensure_default_theme
    # Check again if it exists now (maybe another process created it)
    theme_path = Path["themes", "default"]
    return if Dir.exists?(theme_path)

    # Extract the default theme from baked-in files
    # The ThemeFiles class is defined in commands/init.cr
    FileUtils.mkdir_p("themes")
    Nicolino::ThemeFiles.expand
  end
end
