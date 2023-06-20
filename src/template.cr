require "crustache"

module Templates
  extend self

  # Wrapper class for a Crustache template
  class Template
    # Per-path hash of all templates
    @@templates = {} of String => Template

    def self.templates
      @@templates
    end

    # Get a template's compiled version by path
    def self.get(path)
      if !Template.templates.has_key?(path)
        Template.templates[path] = Template.new(path)
      end
      Template.templates[path].@compiled
    end

    @text : String
    @compiled : Crustache::Syntax::Template

    # Load from a file and compile template
    def initialize(path)
      @text = File.read(path)
      @compiled = Crustache.parse(@text)
    end
  end
end
