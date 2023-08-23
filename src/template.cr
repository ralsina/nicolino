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
        .select { |n| n.@name == "include" }.each { |n|
      deps << "kv://#{n.@arguments[0].value}"
    }
    deps
  end

  # A Crinja Loader that is aware of the k/v store
  class StoreLoader < Crinja::Loader
    @cache_sources = {} of String => String

    def get_source(env : Crinja, template : String) : {String, String?}
      source = @cache_sources[template] ||= _get_source(env, template)
      {source, nil}
    end

    def _get_source(env : Crinja, template : String) : String
      source = Croupier::TaskManager.get("#{template}")
      raise "Template #{template} not found" if source.nil?
      # FIXME should really traverse the node tree
      Crinja::Template.new(source).nodes.@children \
        .select(Crinja::AST::TagNode) \
          .select { |n| n.@name == "include" }.each { |n|
        Croupier::TaskManager.tasks["kv://#{template}"].inputs << "kv://#{n.@arguments[0].value}"
      }
      source
    end
  end

  # Load templates from templates/ and put them in the k/v store
  def self.load_templates
    Log.info { "Scanning Templates" }
    Dir.glob("templates/*.tmpl").each do |template|
      Croupier::Task.new(
        id: "template",
        inputs: [template] + get_deps(template),
        output: "kv://#{template}",
        mergeable: false,
        proc: Croupier::TaskProc.new {
          Log.info { "👈 #{template}" }
          # Yes, we re-read it when get_deps already did it.
          # In auto mode the content may have changed though.
          File.read(template)
        })
    end
  end

  Env = Crinja.new
  Env.loader = StoreLoader.new

  # Convenience filters
  Env.filters["link"] = Crinja.filter() do
    return Crinja::Value.new(%(<a href="#{target["link"]}">#{target["name"]}</a>)) unless target["link"].empty?
    return target["name"]
  end
end
