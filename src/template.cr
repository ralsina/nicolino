require "crustache"
require "./util"

module Templates
  extend self

  class Template
    @@templates = {} of String => Template
    @text : String
    @compiled : Crustache::Syntax::Template

    def initialize(path)
      @text = File.read(path)
      @compiled = Crustache.parse(@text)
    end

    def self.templates
      @@templates
    end
  end

  def self.init(path)
    Util.log "Loading templates"
    # Load templates
    Dir.glob("templates/*.tmpl").each do |path|
      Template.templates[path] = Template.new(path)
    end
  end
end
