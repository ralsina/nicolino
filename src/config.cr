require "totem"

module Config
  @@config = Totem.new

  # Taxonomy description in config
  struct Taxonomy
    include JSON::Serializable

    property title : String
    property term_title : String
    property output : String
  end

  alias Taxonomies = Hash(String, Taxonomy)

  # Options for Nicolino output
  struct Options
    include JSON::Serializable
    property? pretty_html = false
    property image_large = 4096
    property image_thumb = 1024
    property formats = {} of String => String
    property date_output_format = "%Y-%m-%d %H:%M"
    property output = "output"
    property locale = "en_US.UTF-8"
    property language = "en"
  end

  @@options = Hash(String, Options).new
  @@taxonomies = Taxonomies.new

  def self.get(key)
    self.config.get(key)
  end

  def self.config
    if @@config.@config_paths.empty?
      Log.info { "Loading configuration" }
      @@config = Totem.from_file "conf.yml"
      @@config.set_default("features",
        ["assets",
         "posts",
         "pages",
         "pandoc",
         "taxonomies",
         "images",
         "galleries",
         "sitemap",
         "search"])
      @@config.set_default("taxonomies", {
        "tags" => {
          "title"      => "🏷Tags",
          "term_title" => "Posts tagged {{term.name}}",
          "output"     => "tags/",
        },
      })
      @@config.set_default("languages", {"en" => Hash(String, String).new})
    end
    @@config
  end

  def self.taxonomies : Taxonomies
    if @@taxonomies.empty?
      @@taxonomies = Taxonomies.new
      config.get("taxonomies").as_h.keys.each do |k|
        @@taxonomies[k] = @@config.mapping(Taxonomy, "taxonomies.#{k}")
      end
    end
    @@taxonomies
  end

  # Return options per language
  def self.options(language = nil) : Options
    lang = language || Locale.language
    if @@options.fetch(lang, nil).nil?
      @@config.set_default("languages.#{lang}.options", @@config.get("options"))
      @@options[lang] = @@config.mapping(Options, "languages.#{lang}.options")
    end

    @@options[lang].as(Options)
  end

  def self.languages
    config.get("languages").as_h
  end
end
