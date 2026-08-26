require "file_utils"
require "log"
require "yaml"
require "./commands/init"

module Theme
  # Get the current theme name from config
  def self.name
    Config.options.theme
  end

  # Parameters declared in the active theme's theme.yml, overridden
  # by the site's conf.yml `theme_params:` section. A `params:` key
  # in theme.yml holds the theme's configurable parameters; other
  # top-level keys are metadata but also exposed. Exposed to every
  # template as the `theme` variable.
  @@params : Hash(String, Crinja::Value)? = nil

  def self.params : Hash(String, Crinja::Value)
    @@params ||= begin
      params = Hash(String, Crinja::Value).new
      theme_yml = Path["themes", name, "theme.yml"]
      if File.exists?(theme_yml)
        parsed = YAML.parse(File.read(theme_yml))
        if parsed.as_h?
          parsed.as_h.each do |key, value|
            if key.as_s == "params" && value.as_h?
              value.as_h.each do |param_key, param_value|
                params[param_key.as_s] = any_to_crinja(param_value)
              end
            else
              params[key.as_s] = any_to_crinja(value)
            end
          end
        end
      end
      Config.theme_params.each do |key, value|
        params[key] = any_to_crinja(value)
      end
      params
    end
  end

  # Convert a YAML::Any value into something Crinja can render
  # (scalars, arrays and hashes, recursively)
  private def self.any_to_crinja(value : YAML::Any) : Crinja::Value
    case value.raw
    when Hash
      Crinja::Value.new(value.as_h.transform_values { |item| any_to_crinja(item) })
    when Array
      Crinja::Value.new(value.as_a.map { |item| any_to_crinja(item) })
    else
      raw = value.raw
      case raw
      when Bool, Int32, Int64, Float64
        Crinja::Value.new(raw)
      else
        Crinja::Value.new(raw.to_s)
      end
    end
  end

  # Get the path to the theme directory
  # Resolves theme path from local themes/ directory or extracts baked-in default
  # (memoized: this does a directory stat per call and is called for
  # every template resolution, so caching matters on large sites)
  @@cached_path : String? = nil

  def self.path
    @@cached_path ||= resolve_path
  end

  # Clear the memoized path (called when config is reloaded)
  def self.reset
    @@cached_path = nil
    @@params = nil
  end

  private def self.resolve_path
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
