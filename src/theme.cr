module Theme
  # Get the current theme name from config
  def self.name
    Config.options.theme
  end

  # Get the path to the theme directory
  def self.path
    "themes/#{name}"
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
end
