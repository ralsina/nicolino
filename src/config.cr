require "yaml"

module Config
  @@config_file_path : String = "conf.yml"
  @@default_lang : String = "en"

  # Font description in config
  struct Font
    include YAML::Serializable

    property family : String
    property source : String
    property weights : Array(Int32)
    property role : String
  end

  alias Fonts = Array(Font)

  # Taxonomy description in config - per language
  struct Taxonomy
    include YAML::Serializable

    property title : String
    property term_title : String
    property location : String
  end

  alias Taxonomies = Hash(String, Taxonomy)

  # Full configuration from conf.yml
  struct ConfigFile
    include YAML::Serializable

    property site : SiteConfig
    property taxonomies : Taxonomies = Taxonomies.new
    property features : Array(String) = [] of String
  end

  # Site configuration section from conf.yml
  struct SiteConfig
    include YAML::Serializable

    # Site metadata
    property title : String = "Nicolino"
    property description : String = "A Nicolino Site"
    property url : String = "https://example.com"
    property footer : String = "Powered by Nicolino"

    # Paths
    property output : String = "output/"
    property content : String = "content/"
    property posts : String = "posts/"
    property galleries : String = "galleries/"

    # Theme
    property theme : String = "default"
    property color_scheme : String = "default"
    property fonts : Fonts = Fonts.new

    # Image settings
    property image_large : Int32 = 1920
    property image_thumb : Int32 = 640

    # Formats
    property formats : Hash(String, String) = {} of String => String

    # Locale
    property language : String = "en"
    property locale : String = "en_US.UTF-8"
    property date_output_format : String = "%Y-%m-%d %H:%M"

    # Other
    property verbosity : Int32 = 3
    property continuous_import_templates : String = "user_templates"
  end

  # Per-language configuration
  class LangConfig
    property title : String
    property description : String
    property url : String
    property footer : String
    property output : String
    property content : String
    property posts : String
    property galleries : String
    property theme : String
    property color_scheme : String
    property fonts : Fonts
    property image_large : Int32
    property image_thumb : Int32
    property formats : Hash(String, String)
    property locale : String
    property date_output_format : String
    property verbosity : Int32
    property continuous_import_templates : String
    property taxonomies : Taxonomies

    def initialize(
      @title = "Nicolino",
      @description = "A Nicolino Site",
      @url = "https://example.com",
      @footer = "Powered by Nicolino",
      @output = "output/",
      @content = "content/",
      @posts = "posts/",
      @galleries = "galleries/",
      @theme = "default",
      @color_scheme = "default",
      @fonts = Fonts.new,
      @image_large = 1920,
      @image_thumb = 640,
      @formats = {} of String => String,
      @locale = "en_US.UTF-8",
      @date_output_format = "%Y-%m-%d %H:%M",
      @verbosity = 3,
      @continuous_import_templates = "user_templates",
      @taxonomies = Taxonomies.new
    )
    end
  end

  # Store all loaded language configs
  @@lang_configs = Hash(String, LangConfig).new
  @@features : Array(String) = [] of String
  @@loaded : Bool = false

  # Ensure config is loaded before accessing
  private def self.ensure_loaded
    return if @@loaded
    config
  end

  # Get the raw config for legacy access
  def self.get(key)
    # For now, return nil - we'll remove this API
    nil
  end

  # Load config from conf.yml
  def self.config(path = "conf.yml")
    @@config_file_path = path

    # Read and parse conf.yml
    config_data = ConfigFile.from_yaml(File.read(path))

    # Store default language
    @@default_lang = config_data.site.language

    # Build LangConfig for default language from SiteConfig + Taxonomies
    site = config_data.site
    lang_config = LangConfig.new(
      title: site.title,
      description: site.description,
      url: site.url,
      footer: site.footer,
      output: site.output,
      content: site.content,
      posts: site.posts,
      galleries: site.galleries,
      theme: site.theme,
      color_scheme: site.color_scheme,
      fonts: site.fonts,
      image_large: site.image_large,
      image_thumb: site.image_thumb,
      formats: site.formats,
      locale: site.locale,
      date_output_format: site.date_output_format,
      verbosity: site.verbosity,
      continuous_import_templates: site.continuous_import_templates,
      taxonomies: config_data.taxonomies
    )

    @@lang_configs[@@default_lang] = lang_config
    @@features = config_data.features

    # Set default features if empty
    if @@features.empty?
      @@features = ["assets", "posts", "pages", "pandoc", "taxonomies",
                    "images", "galleries", "sitemap", "search", "base16"]
    end

    # Set default taxonomies if empty
    if @@lang_configs[@@default_lang].taxonomies.empty?
      default_taxonomy_yaml = %(
title: "🏷Tags"
term_title: "Posts tagged {{term.name}}"
location: "tags/"
)
      @@lang_configs[@@default_lang].taxonomies = {
        "tags" => Taxonomy.from_yaml(default_taxonomy_yaml)
      }
    end
  end

  # Load or get cached LangConfig for a specific language
  def self.[](lang : String) : LangConfig
    ensure_loaded
    unless @@lang_configs.has_key?(lang)
      if lang == @@default_lang
        # Should have been loaded already
        raise "Default language config not loaded. Call Config.config() first."
      else
        # TODO: Load from conf.LANG.yml for overrides
        # For now, just use default config
        @@lang_configs[lang] = @@lang_configs[@@default_lang]
      end
    end
    @@lang_configs[lang]
  end

  # Alias for default language - forward commonly used properties
  def self.title : String
    self[@@default_lang].title
  end

  def self.description : String
    self[@@default_lang].description
  end

  def self.url : String
    self[@@default_lang].url
  end

  def self.footer : String
    self[@@default_lang].footer
  end

  def self.output : String
    self[@@default_lang].output
  end

  def self.content : String
    self[@@default_lang].content
  end

  def self.posts : String
    self[@@default_lang].posts
  end

  def self.galleries : String
    self[@@default_lang].galleries
  end

  def self.theme : String
    self[@@default_lang].theme
  end

  def self.color_scheme : String
    self[@@default_lang].color_scheme
  end

  def self.fonts : Fonts
    self[@@default_lang].fonts
  end

  def self.image_large : Int32
    self[@@default_lang].image_large
  end

  def self.image_thumb : Int32
    self[@@default_lang].image_thumb
  end

  def self.formats : Hash(String, String)
    self[@@default_lang].formats
  end

  def self.locale : String
    self[@@default_lang].locale
  end

  def self.date_output_format : String
    self[@@default_lang].date_output_format
  end

  def self.verbosity : Int32
    self[@@default_lang].verbosity
  end

  def self.continuous_import_templates : String
    self[@@default_lang].continuous_import_templates
  end

  def self.taxonomies : Taxonomies
    ensure_loaded
    self[@@default_lang].taxonomies
  end

  # Get features list
  def self.features : Array(String)
    ensure_loaded
    @@features
  end

  # Get features as a Set of Totem::Any for legacy compatibility
  def self.features_set : Set(Totem::Any)
    ensure_loaded
    @@features.map { |f| Totem::Any.new(f) }.to_set
  end

  # Legacy: Config.options(lang) - map to Config[lang]
  def self.options(lang = nil)
    lang ||= @@default_lang
    self[lang]
  end

  # Legacy: Config.languages - return hash with default language only
  def self.languages
    {@@default_lang => Hash(String, String).new}
  end

  # Get the default language
  def self.language : String
    @@default_lang
  end

  # Get the actual config file path being used
  def self.config_path : String
    @@config_file_path
  end

  # Reload the config file from disk
  def self.reload
    path = config_path
    Log.info { "Reloading config from #{path}" }
    # Clear cached configs
    @@lang_configs.clear
    @@features.clear
    # Load again
    Config.config(path)
  end
end
