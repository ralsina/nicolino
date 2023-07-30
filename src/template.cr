require "crinja"

module Templates
  extend self

  def self.get_deps(template)
    source = File.read(template)
    Croupier::TaskManager.set("#{template}", source)
    deps = [] of String
    # FIXME should really traverse the node tree
    Crinja::Template.new(source).nodes.@children \
      .select(Crinja::AST::TagNode) \
        .select { |n| n.@name == "include" }.each { |n|
      deps << "kv://#{n.@arguments[0].value}"
    }
    deps
  end

  class StoreLoader < Crinja::Loader
    def get_source(env : Crinja, template : String) : {String, String?}
      source = Croupier::TaskManager.get("#{template}")
      raise "Template #{template} not found" if source.nil?
      # FIXME should really traverse the node tree
      Crinja::Template.new(source).nodes.@children \
        .select(Crinja::AST::TagNode) \
          .select { |n| n.@name == "include" }.each { |n|
        Croupier::TaskManager.tasks["kv://#{template}"].inputs << "kv://#{n.@arguments[0].value}"
      }
      {source, nil}
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
          Log.info { "<< #{template}" }
          # Yes, we re-read it when get_deps already did it.
          # This is important for auto mode, tho.
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
