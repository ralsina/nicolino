require "crinja"

module Templates
  extend self

  def self.get_deps(template)
    source = File.read(template)
    if Croupier::TaskManager.get(template) == source
      Log.debug { "Template #{template} unchanged" }
    else
      Croupier::TaskManager.set(template, source)
    end
    deps = [] of String
    # FIXME should really traverse the node tree
    Crinja::Template.new(source).nodes.@children \
      .select(Crinja::AST::TagNode) \
        .select { |node| node.@name == "include" }.each { |node|
      deps << "kv://#{node.@arguments[0].value}"
    }
    deps
  end

  # A Crinja Loader that is aware of the k/v store
  class StoreLoader < Crinja::Loader
    @cache_sources = {} of String => String

    def get_source(env : Crinja, template : String) : {String, String?}
      # No caching in auto mode

      if Croupier::TaskManager.auto_mode?
        return {_get_source(env, template), nil}
      end
      return {@cache_sources[template] ||= _get_source(env, template), nil}
    end

    def _get_source(env : Crinja, template : String) : String
      source = Croupier::TaskManager.get("#{template}")
      raise "Template #{template} not found" if source.nil?
      # FIXME should really traverse the node tree
      Crinja::Template.new(source).nodes.@children \
        .select(Crinja::AST::TagNode) \
          .select { |node| node.@name == "include" }.each { |node|
        Croupier::TaskManager.tasks["kv://#{template}"].inputs << "kv://#{node.@arguments[0].value}"
      }
      source
    end
  end

  # Load templates from templates/ and put them in the k/v store
  def self.load_templates
    Log.debug { "Scanning Templates" }
    Dir.glob("templates/*.tmpl").each do |template|
      Croupier::Task.new(
        id: "template",
        inputs: [template] + get_deps(template),
        output: "kv://#{template}",
        mergeable: false
      ) do
        Log.debug { "👈 #{template}" }
        # Yes, we re-read it when get_deps already did it.
        # In auto mode the content may have changed though.
        File.read(template)
      end
    end
  end

  # Thread-local environment cache
  class EnvCache
    @@envs = Hash(Fiber, Crinja).new
    @@mutex = Mutex.new

    def self.get(env_factory : Proc(Crinja))
      fiber = Fiber.current
      @@mutex.synchronize do
        @@envs[fiber] ||= env_factory.call
      end
    end
  end

  # Create a new Crinja environment
  private def self.create_env
    env = Crinja.new
    env.loader = StoreLoader.new
    env.cache = Crinja::TemplateCache::InMemory.new

    # Convenience filters
    env.filters["link"] = Crinja.filter() do
      return Crinja::Value.new(%(<a href="#{target["link"]}">#{target["name"]}</a>)) unless target["link"].empty?
      return target["name"]
    end

    # Convert image filename to thumbnail filename
    env.filters["thumb_url"] = Crinja.filter() do
      filename = target.to_s
      ext = File.extname(filename)
      basename = filename.chomp(ext)
      return Crinja::Value.new("#{basename}.thumb#{ext}")
    end

    env
  end

  # Get the thread/fiber-local Crinja environment
  def self.environment
    EnvCache.get(->create_env)
  end
end
