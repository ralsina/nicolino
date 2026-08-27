require "yaml"

module Config
  @@config_file_path : String = "conf.yml"
  @@default_lang : String = "en"

  # Raised when the configuration cannot be loaded. The CLI layer converts
  # this into an exit code; library code should never call `exit`.
  class ConfigError < Exception
  end

  # Font description in config
  struct Font
    include YAML::Serializable

    property family : String
    property source : String
    property weights : Array(Int32)
    property role : String
  end

  alias Fonts = Array(Font)
  alias NavItems = Array(String)

  # Taxonomy description in config - translatable
  struct Taxonomy
    include YAML::Serializable

    property title : String
    property term_title : String
    property location : String
  end

  alias Taxonomies = Hash(String, Taxonomy)

  # Global configuration from conf.yml (NOT translatable)
  struct SiteConfig
    include YAML::Serializable

    # Translatable properties (also in LangConfig, but read into LangConfig)
    property title : String = "Nicolino"
    property description : String = "A Nicolino Site"
    property url : String = "https://example.com"
    property footer : String = "Powered by Nicolino"
    property nav_items : NavItems = NavItems.new

    # NOT translatable
    property output : String = "output/"
    property content : String = "content/"
    property posts : String = "posts/"
    property galleries : String = "galleries/"
    property listings : String = "listings/"
    property books : String = "books/"
    property archive : String = "archive/"
    property theme : String = "default"
    property color_scheme : String = "default"
    property fonts : Fonts = Fonts.new
    property image_large : Int32 = 1920
    property image_thumb : Int32 = 640
    property pandoc_formats : Hash(String, String) = {} of String => String
    property language : String = "en"
    property locale : String = "en_US.UTF-8"
    property date_output_format : String = "%Y-%m-%d %H:%M"
    property verbosity : Int32 = 4
    property import_templates : String = "user_templates"
    # Overrides for the active theme's theme.yml parameters (exposed
    # to templates as the `theme` variable)
    property theme_params : Hash(String, YAML::Any) = Hash(String, YAML::Any).new
    # When true (default), content that has no translation for the
    # current language is still rendered using the default-language
    # version, flagged with is_fallback in the template context.
    # When false, untranslated content is simply absent from that
    # language's site.
    property? content_fallback : Bool = true
    # When true (default), every page goes through a lexbor
    # parse/serialize round trip that normalizes its HTML formatting.
    # When false, pages that need no link or code-class fixing are
    # written as the raw template output (faster, same DOM).
    property? pretty_html : Bool = true
    # Server-side syntax highlighter for markdown code blocks:
    # "tartrazine" (default) or "none" (leaves language-* classes
    # for client-side highlighting)
    property syntax_highlighter : String = "tartrazine"
    # Explicit tartrazine theme name for code blocks (e.g.
    # "monokai"). When unset, dark and light syntax themes are
    # derived from the site's base16 color_scheme
    property syntax_theme : String = ""
    # URL prefix prepended to all generated links.  When the site
    # is served under a subpath (e.g. /blog/), set this to that
    # prefix so the relativizer computes correct relative paths.
    # Leave empty (default) for root-mounted sites.
    property url_prefix : String = ""

    # Taxonomies and features
    property taxonomies : Taxonomies = Taxonomies.new
    property features : Array(String) = [] of String

    # folder_indexes feature options (see conf.yml's folder_indexes
    # section)
    property folder_indexes : FolderIndexesConfig = FolderIndexesConfig.new

    # Import configuration (hash of feed name to config)
    property import : Hash(String, YAML::Any) = Hash(String, YAML::Any).new
  end

  # Options for the folder_indexes feature (conf.yml's folder_indexes
  # section)
  class FolderIndexesConfig
    include YAML::Serializable

    # Directories excluded from automatic index generation, on top of
    # the exclusions registered by features themselves
    property exclude_dirs : Array(String) = [] of String

    def initialize
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
    property nav_items : NavItems = NavItems.new
    property date_output_format : String = "%Y-%m-%d %H:%M"
    property locale : String = "en_US.UTF-8"

    # Translatable taxonomies
    property taxonomies : Taxonomies = Taxonomies.new

    def initialize(
      @title = "Nicolino",
      @description = "A Nicolino Site",
      @footer = "Powered by Nicolino",
      @url = "https://example.com",
      @nav_items = NavItems.new,
      @date_output_format = "%Y-%m-%d %H:%M",
      @locale = "en_US.UTF-8",
      @taxonomies = Taxonomies.new,
    )
    end
  end

  # Store all loaded language configs
  @@lang_configs = Hash(String, LangConfig).new
  @@global_config : SiteConfig = SiteConfig.from_yaml("{}")
  @@features : Array(String) = [] of String
  @@loaded : Bool = false
  # Memoized language list (this used to glob the config directory on
  # every call, which was called per-file during content scans)
  @@languages : Array(String)? = nil

  # Load config from conf.yml
  def self.config(path = "conf.yml")
    @@config_file_path = path
    # A new config file may mean a different set of languages
    @@languages = nil

    # Read and parse conf.yml
    unless File.exists?(path)
      raise ConfigError.new(
        "No configuration file found at '#{path}'. Are you in a Nicolino site directory?\n" \
        "Run 'nicolino init <path>' to create a new site, or specify a config file with -c."
      )
    end
    @@global_config = SiteConfig.from_yaml(File.read(path))

    # Store default language
    @@default_lang = @@global_config.language

    # Build LangConfig for default language from translatable parts
    @@lang_configs[@@default_lang] = LangConfig.new(
      title: @@global_config.title,
      description: @@global_config.description,
      footer: @@global_config.footer,
      url: @@global_config.url,
      nav_items: @@global_config.nav_items,
      date_output_format: @@global_config.date_output_format,
      locale: @@global_config.locale,
      taxonomies: @@global_config.taxonomies
    )

    @@features = @@global_config.features
    @@loaded = true

    # Set default features if empty
    if @@features.empty?
      @@features = ["assets", "posts", "pages", "pandoc", "taxonomies",
                    "images", "galleries", "sitemap", "search", "base16"]
    end

    # Set default taxonomies if empty
    return unless @@lang_configs[@@default_lang].taxonomies.empty?
    default_taxonomy_yaml = %( # ameba:disable Style/MultilineStringLiteral
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

  # Custom folder_indexes exclusions from conf.yml
  def self.folder_indexes_excludes : Array(String)
    ensure_loaded
    @@global_config.folder_indexes.exclude_dirs
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
          nav_items: lang_override.nav_items,
          date_output_format: lang_override.date_output_format,
          locale: lang_override.locale,
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

  def self.listings : String
    ensure_loaded
    @@global_config.listings
  end

  def self.books : String
    ensure_loaded
    @@global_config.books
  end

  def self.archive : String
    ensure_loaded
    @@global_config.archive
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
    @@global_config.pandoc_formats
  end

  def self.locale : String
    self[@@default_lang].locale
  end

  def self.verbosity : Int32
    ensure_loaded
    @@global_config.verbosity
  end

  def self.import_templates : String
    ensure_loaded
    @@global_config.import_templates
  end

  def self.content_fallback? : Bool
    ensure_loaded
    @@global_config.content_fallback?
  end

  def self.theme_params : Hash(String, YAML::Any)
    ensure_loaded
    @@global_config.theme_params
  end

  def self.syntax_highlighter : String
    ensure_loaded
    @@global_config.syntax_highlighter
  end

  def self.syntax_theme : String
    ensure_loaded
    @@global_config.syntax_theme
  end

  def self.language : String
    ensure_loaded
    @@global_config.language
  end

  # The default/primary language code
  def self.default_lang : String
    ensure_loaded
    @@default_lang
  end

  def self.url : String
    # URL is translatable (could have different domain per language)
    self[@@default_lang].url
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

  def self.features_set : Set(String)
    ensure_loaded
    @@features.to_set
  end

  # ===== Legacy compatibility =====

  # Legacy: Config.options(lang) - map to Config[lang] wrapped
  class OptionsWrapper
    property output : String
    property content : String
    property posts : String
    property galleries : String
    property listings : String
    property books : String
    property archive : String
    property locale : String
    property date_output_format : String
    property theme : String
    property color_scheme : String
    property fonts : Fonts
    property pandoc_formats : Hash(String, String)
    property import_templates : String
    property import : Hash(String, YAML::Any)
    property image_large : Int32
    property image_thumb : Int32
    property? pretty_html : Bool
    property url_prefix : String

    def initialize(@lang_config : LangConfig, @global : SiteConfig)
      @output = @global.output
      @content = @global.content
      @posts = @global.posts
      @galleries = @global.galleries
      @listings = @global.listings
      @books = @global.books
      @archive = @global.archive
      @locale = @lang_config.locale
      @date_output_format = @lang_config.date_output_format
      @theme = @global.theme
      @color_scheme = @global.color_scheme
      @fonts = @global.fonts
      @pandoc_formats = @global.pandoc_formats
      @import_templates = @global.import_templates
      @import = @global.import
      @image_large = @global.image_large
      @image_thumb = @global.image_thumb
      @pretty_html = @global.pretty_html?
      @url_prefix = @global.url_prefix
    end
  end

  # Memoized per-language OptionsWrapper: building one copies ~17
  # fields, and hot paths (per-page value()/breadcrumbs) call this
  # several times per page
  @@options_cache = Hash(String, OptionsWrapper).new
  @@options_mutex = Mutex.new

  def self.options(lang = nil)
    lang ||= @@default_lang
    ensure_loaded
    cached = @@options_cache[lang]?
    return cached if cached

    @@options_mutex.synchronize do
      @@options_cache[lang] ||= OptionsWrapper.new(self[lang], @@global_config)
    end
  end

  # Get all available languages by scanning for conf.LANG.yml files
  # (memoized; invalidated by reload)
  def self.languages : Array(String)
    @@languages ||= begin
      ensure_loaded
      langs = [@@default_lang]

      # Scan for conf.LANG.yml files
      Dir.glob("conf.*.yml").each do |file|
        # Extract language code from conf.LANG.yml
        if match = file.match(/^conf\.([a-z]{2})\.yml$/)
          lang = match[1]
          langs << lang unless langs.includes?(lang)
        end
      end

      langs
    end
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
    @@languages = nil
    @@options_cache.clear
    # Load again
    Config.config(path)
  end
end
