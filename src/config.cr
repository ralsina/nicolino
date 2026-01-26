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

  # Taxonomy description in config - translatable
  struct Taxonomy
    include YAML::Serializable

    property title : String
    property term_title : String
    property location : String
  end

  alias Taxonomies = Hash(String, Taxonomy)

  # Global configuration from conf.yml (NOT translatable)
  struct ConfigFile
    include YAML::Serializable

    # Translatable properties (also in SiteConfig, but read into LangConfig)
    property title : String = "Nicolino"
    property description : String = "A Nicolino Site"
    property url : String = "https://example.com"
    property footer : String = "Powered by Nicolino"

    # NOT translatable
    property output : String = "output/"
    property content : String = "content/"
    property posts : String = "posts/"
    property galleries : String = "galleries/"
    property theme : String = "default"
    property color_scheme : String = "default"
    property fonts : Fonts = Fonts.new
    property image_large : Int32 = 1920
    property image_thumb : Int32 = 640
    property formats : Hash(String, String) = {} of String => String
    property language : String = "en"
    property locale : String = "en_US.UTF-8"
    property date_output_format : String = "%Y-%m-%d %H:%M"
    property verbosity : Int32 = 3
    property continuous_import_templates : String = "user_templates"

    # Taxonomies and features
    property taxonomies : Taxonomies = Taxonomies.new
    property features : Array(String) = [] of String
  end

  # Site configuration section from conf.yml (NOT translatable)
  struct SiteConfig
    include YAML::Serializable

    # Translatable - will be in LangConfig
    property title : String = "Nicolino"
    property description : String = "A Nicolino Site"
    property footer : String = "Powered by Nicolino"
    property url : String = "https://example.com"

    # NOT translatable
    property output : String = "output/"
    property content : String = "content/"
    property posts : String = "posts/"
    property galleries : String = "galleries/"

    # NOT translatable
    property theme : String = "default"
    property color_scheme : String = "default"
    property fonts : Fonts = Fonts.new

    # NOT translatable
    property image_large : Int32 = 1920
    property image_thumb : Int32 = 640
    property formats : Hash(String, String) = {} of String => String

    # Locale/Language settings
    property language : String = "en"
    property locale : String = "en_US.UTF-8"
    property date_output_format : String = "%Y-%m-%d %H:%M"

    # NOT translatable
    property verbosity : Int32 = 3
    property continuous_import_templates : String = "user_templates"

    # Default constructor for class variable initialization
    def initialize
      @title = "Nicolino"
      @description = "A Nicolino Site"
      @footer = "Powered by Nicolino"
      @url = "https://example.com"
      @output = "output/"
      @content = "content/"
      @posts = "posts/"
      @galleries = "galleries/"
      @theme = "default"
      @color_scheme = "default"
      @fonts = Fonts.new
      @image_large = 1920
      @image_thumb = 640
      @formats = {} of String => String
      @language = "en"
      @locale = "en_US.UTF-8"
      @date_output_format = "%Y-%m-%d %H:%M"
      @verbosity = 3
      @continuous_import_templates = "user_templates"
    end
  end

  # Translatable configuration - can be overridden by conf.LANG.yml
  class LangConfig
    include YAML::Serializable

    # Translatable properties - with defaults for partial overrides
    property title : String = "Nicolino"
    property description : String = "A Nicolino Site"
    property footer : String = "Powered by Nicolino"
    property url : String = "https://example.com"
    property date_output_format : String = "%Y-%m-%d %H:%M"

    # Translatable taxonomies
    property taxonomies : Taxonomies = Taxonomies.new

    def initialize(
      @title = "Nicolino",
      @description = "A Nicolino Site",
      @footer = "Powered by Nicolino",
      @url = "https://example.com",
      @date_output_format = "%Y-%m-%d %H:%M",
      @taxonomies = Taxonomies.new
    )
    end
  end

  # Store all loaded language configs
  @@lang_configs = Hash(String, LangConfig).new
  @@global_config : SiteConfig = SiteConfig.new
  @@features : Array(String) = [] of String
  @@loaded : Bool = false

  # Get the raw config for legacy access (TODO: remove)
  def self.get(key)
    ensure_loaded
    nil
  end

  # Load config from conf.yml
  def self.config(path = "conf.yml")
    @@config_file_path = path

    # Read and parse conf.yml
    config_data = ConfigFile.from_yaml(File.read(path))

    # Store global config (convert ConfigFile to SiteConfig)
    @@global_config = SiteConfig.new
    @@global_config.title = config_data.title
    @@global_config.description = config_data.description
    @@global_config.url = config_data.url
    @@global_config.footer = config_data.footer
    @@global_config.output = config_data.output
    @@global_config.content = config_data.content
    @@global_config.posts = config_data.posts
    @@global_config.galleries = config_data.galleries
    @@global_config.theme = config_data.theme
    @@global_config.color_scheme = config_data.color_scheme
    @@global_config.fonts = config_data.fonts
    @@global_config.image_large = config_data.image_large
    @@global_config.image_thumb = config_data.image_thumb
    @@global_config.formats = config_data.formats
    @@global_config.language = config_data.language
    @@global_config.locale = config_data.locale
    @@global_config.date_output_format = config_data.date_output_format
    @@global_config.verbosity = config_data.verbosity
    @@global_config.continuous_import_templates = config_data.continuous_import_templates

    # Store default language
    @@default_lang = @@global_config.language

    # Build LangConfig for default language from translatable parts
    lang_config = LangConfig.new(
      title: @@global_config.title,
      description: @@global_config.description,
      footer: @@global_config.footer,
      url: @@global_config.url,
      date_output_format: @@global_config.date_output_format,
      taxonomies: config_data.taxonomies
    )

    @@lang_configs[@@default_lang] = lang_config
    @@features = config_data.features
    @@loaded = true

    # Set default features if empty
    if @@features.empty?
      @@features = ["assets", "posts", "pages", "pandoc", "taxonomies",
                    "images", "galleries", "sitemap", "search", "base16"]
    end

    # Set default taxonomies if empty
    return unless @@lang_configs[@@default_lang].taxonomies.empty?
    default_taxonomy_yaml = %(
title: "🏷Tags"
term_title: "Posts tagged {{term.name}}"
location: "tags/"
)
    @@lang_configs[@@default_lang].taxonomies = {
      "tags" => Taxonomy.from_yaml(default_taxonomy_yaml),
    }
  end

  # Ensure config is loaded before accessing
  private def self.ensure_loaded
    return if @@loaded
    config
  end

  # Load or get cached LangConfig for a specific language
  def self.[](lang : String) : LangConfig
    ensure_loaded
    unless @@lang_configs.has_key?(lang)
      raise "Default language config not loaded." if lang == @@default_lang
      # Load from conf.LANG.yml for overrides
      @@lang_configs[lang] = load_lang_config(lang)
    end
    @@lang_configs[lang]
  end

  # Load language-specific config from conf.LANG.yml
  private def self.load_lang_config(lang : String) : LangConfig
    lang_config_path = "conf.#{lang}.yml"

    if File.exists?(lang_config_path)
      begin
        lang_override = LangConfig.from_yaml(File.read(lang_config_path))
        # Start with default config as base
        base_config = @@lang_configs[@@default_lang]

        # Merge: use override values, falling back to base for any unset values
        LangConfig.new(
          title: lang_override.title,
          description: lang_override.description,
          footer: lang_override.footer,
          url: lang_override.url,
          date_output_format: lang_override.date_output_format,
          taxonomies: lang_override.taxonomies.empty? ? base_config.taxonomies : lang_override.taxonomies
        )
      rescue ex : Exception
        Log.warn { "Failed to load #{lang_config_path}: #{ex.message}, using default config" }
        @@lang_configs[@@default_lang]
      end
    else
      # No override file, use default config
      @@lang_configs[@@default_lang]
    end
  end

  # ===== Global (non-translatable) accessors =====

  def self.output : String
    ensure_loaded
    @@global_config.output
  end

  def self.content : String
    ensure_loaded
    @@global_config.content
  end

  def self.posts : String
    ensure_loaded
    @@global_config.posts
  end

  def self.galleries : String
    ensure_loaded
    @@global_config.galleries
  end

  def self.theme : String
    ensure_loaded
    @@global_config.theme
  end

  def self.color_scheme : String
    ensure_loaded
    @@global_config.color_scheme
  end

  def self.fonts : Fonts
    ensure_loaded
    @@global_config.fonts
  end

  def self.image_large : Int32
    ensure_loaded
    @@global_config.image_large
  end

  def self.image_thumb : Int32
    ensure_loaded
    @@global_config.image_thumb
  end

  def self.formats : Hash(String, String)
    ensure_loaded
    @@global_config.formats
  end

  def self.locale : String
    ensure_loaded
    @@global_config.locale
  end

  def self.verbosity : Int32
    ensure_loaded
    @@global_config.verbosity
  end

  def self.continuous_import_templates : String
    ensure_loaded
    @@global_config.continuous_import_templates
  end

  def self.language : String
    ensure_loaded
    @@global_config.language
  end

  def self.url : String
    # URL is translatable (could have different domain per language)
    self[@@default_lang].url rescue "https://example.com"
  end

  # ===== Translatable accessors (forward to default language) =====

  def self.title : String
    self[@@default_lang].title
  end

  def self.description : String
    self[@@default_lang].description
  end

  def self.footer : String
    self[@@default_lang].footer
  end

  def self.date_output_format : String
    self[@@default_lang].date_output_format
  end

  def self.taxonomies : Taxonomies
    self[@@default_lang].taxonomies
  end

  # ===== Features =====

  def self.features : Array(String)
    ensure_loaded
    @@features
  end

  def self.features_set : Set(Totem::Any)
    ensure_loaded
    @@features.map { |feature| Totem::Any.new(feature) }.to_set
  end

  # ===== Legacy compatibility =====

  # Legacy: Config.options(lang) - map to Config[lang] wrapped
  class OptionsWrapper
    property output : String
    property content : String
    property posts : String
    property galleries : String
    property locale : String
    property date_output_format : String
    property theme : String
    property color_scheme : String
    property fonts : Fonts
    property formats : Hash(String, String)
    property continuous_import_templates : String
    property image_large : Int32
    property image_thumb : Int32

    def initialize(@lang_config : LangConfig, @global : SiteConfig)
      @output = @global.output
      @content = @global.content
      @posts = @global.posts
      @galleries = @global.galleries
      @locale = @global.locale
      @date_output_format = @lang_config.date_output_format
      @theme = @global.theme
      @color_scheme = @global.color_scheme
      @fonts = @global.fonts
      @formats = @global.formats
      @continuous_import_templates = @global.continuous_import_templates
      @image_large = @global.image_large
      @image_thumb = @global.image_thumb
    end
  end

  def self.options(lang = nil)
    lang ||= @@default_lang
    OptionsWrapper.new(self[lang], @@global_config)
  end

  # Get all available languages by scanning for conf.LANG.yml files
  def self.languages
    ensure_loaded
    lang_hash = {@@default_lang => Hash(String, String).new}

    # Scan for conf.LANG.yml files
    Dir.glob("conf.*.yml").each do |file|
      # Extract language code from conf.LANG.yml
      if match = file.match(/^conf\.([a-z]{2})\.yml$/)
        lang = match[1]
        lang_hash[lang] = Hash(String, String).new
      end
    end

    lang_hash
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
    @@loaded = false
    # Load again
    Config.config(path)
  end
end
