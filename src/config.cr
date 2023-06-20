module Config
  @@config = {} of YAML::Any => YAML::Any

  def self.config
    if @@config.empty?
      Log.info { "Loading configuration" }
      @@config = File.open("conf") do |file|
        YAML.parse(file).as_h
      end
    end
    @@config
  end
end
