module Config
  @@config = {} of YAML::Any => YAML::Any

  struct Options
    property? pretty_html = false
    property image_large = 4096
    property image_thumb = 1024

    def initialize(options = Hash(YAML::Any, YAML::Any).new)
      @pretty_html = options["pretty_html"].as_bool if options.has_key? "pretty_html"
      @image_large = options["image_large"].as_i if options.has_key? "image_large"
      @image_thumb = options["image_thumb"].as_i if options.has_key? "image_thumb"
    end
  end

  @@options : Options | Nil = nil

  def self.config
    if @@config.empty?
      Log.info { "Loading configuration" }
      @@config = File.open("conf") do |file|
        YAML.parse(file).as_h
      end
    end
    @@config
  end

  def self.options : Options
    if @@options.nil?
      raw_options = @@config.fetch("options", nil)
      if raw_options
        @@options = Options.new raw_options.as_h
      else
        @@options = Options.new
      end
    end
    @@options.as(Options)
  end
end
