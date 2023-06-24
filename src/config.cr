module Config
  @@config = {} of String => String

  def self.config
    if @@config.empty?
      Log.info { "Loading configuration" }
      @@config = File.open("conf") do |file|
        Hash(String, String).from_yaml(file)
      end
    end
    @@config
  end
end
