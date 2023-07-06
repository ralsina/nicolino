require "crinja"

module Templates
  extend self

  Env = Crinja.new
  Env.loader = Crinja::Loader::FileSystemLoader.new("./")

  # Wrapper class for a Crinja template
  struct Template
    # Per-path hash of all templates
    @@templates = {} of String => Crinja::Template

    def self.templates
      @@templates
    end

    # Get a template by path
    def self.get(path)
      if !Template.templates.has_key?(path)
        Template.templates[path] = Env.get_template(path)
      end
      Template.templates[path]
    end
  end
end
