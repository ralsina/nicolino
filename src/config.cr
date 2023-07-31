require "totem"

module Config
  @@config = Totem.new

  struct Taxonomy
    include JSON::Serializable

    property title : String
    property term_title : String
    property output : String
  end

  alias Taxonomies = Hash(String, Taxonomy)

  struct Options
    include JSON::Serializable
    property? pretty_html = false
    property image_large = 4096
    property image_thumb = 1024
    property formats = {} of String => String
    property date_output_format = "%Y-%m-%d %H:%M"
  end

  @@options : Options | Nil = nil
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

  def self.options : Options
    if @@options.nil?
      @@options = @@config.mapping(Options, "options")
    end
    @@options.as(Options)
  end
end
