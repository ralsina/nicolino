require "totem"

module Config
  @@config = Totem.new

  # Taxonomy description in config
  struct Taxonomy
    include JSON::Serializable

    property title : Hash(String, String)
    property term_title : Hash(String, String)
    property location : Hash(String, String)
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
    property output = "output/"
    property content = "content/"
    property posts = "posts/"
    property galleries = "galleries/"
    property locale = "en_US.UTF-8"
    property language = "en"
    property verbosity = 3
  end

  @@options = Hash(String, Options).new
  @@taxonomies = Taxonomies.new

  def self.get(key)
    self.config.get(key)
  end

  def self.config
    if @@config.@config_paths.empty?
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
          "location"   => "tags/",
        },
      })
      @@config.set_default("languages", {"en" => Hash(String, String).new})
    end
    @@config
  end

  def self.taxonomies : Taxonomies
    if @@taxonomies.empty?
      @@taxonomies = Taxonomies.new

      Config.languages.keys.each do |lang|
        @@config.set_default("languages.#{lang}.taxonomies", @@config.get("taxonomies"))
      end

      # This is the master taxonomy list
      config.get("taxonomies").as_h.keys.each do |k|
        # For each, collect the taxonomy in all languages
        # This is a pain to do but keeps the config file nicer
        title = Config.languages.keys.map do |lang|
          [lang, config.get("languages.#{lang}.taxonomies.#{k}.title").as_s]
        end.to_h
        term_title = Config.languages.keys.map do |lang|
          [lang, config.get("languages.#{lang}.taxonomies.#{k}.term_title").as_s]
        end.to_h
        location = Config.languages.keys.map do |lang|
          [lang, config.get("languages.#{lang}.taxonomies.#{k}.location").as_s]
        end.to_h

        @@config.set("_taxonomies.#{k}", {
          "title"      => title,
          "term_title" => term_title,
          "location"   => location,
        })
        @@taxonomies[k] = @@config.mapping(Taxonomy, "_taxonomies.#{k}")
      end
    end
    @@taxonomies
  end

  # Return options per language
  def self.options(lang = nil) : Options
    lang ||= Locale.language
    if @@options.fetch(lang, nil).nil?
      config.set_default("languages.#{lang}.options", config.get("options"))
      @@options[lang] = config.mapping(Options, "languages.#{lang}.options")
    end

    @@options[lang].as(Options)
  end

  def self.languages
    config.get("languages").as_h
  end
end
