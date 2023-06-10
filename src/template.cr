require "crustache"
require "./util"

module Templates
  extend self

  # Wrapper class for a Crustache template
  class Template
    @@templates = {} of String => Template
    @text : String
    @compiled : Crustache::Syntax::Template

    # Load from a file and compile template
    def initialize(path)
      @text = File.read(path)
      @compiled = Crustache.parse(@text)
    end

    # Per-path hash of all templates
    def self.templates
      @@templates
    end
  end

  # Load all the templates into the system
  def self.init(path)
    Util.log "Loading templates"
    # Load templates
    Dir.glob("templates/*.tmpl").each do |path|
        Util.log "    #{path}"
      Template.templates[path] = Template.new(path)
    end
  end
end
