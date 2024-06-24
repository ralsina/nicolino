require "crinja"
require "./wren.cr"

module Templates
  extend self
  include Vm

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
    # TODO: traverse tree and find mentions of wren filters,
    # add as dependencies
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
    self.load_filters
    Dir.glob("templates/*.tmpl").each do |template|
      Croupier::Task.new(
        id: "template",
        inputs: [template] + get_deps(template),
        output: "kv://#{template}",
        mergeable: false,
        proc: Croupier::TaskProc.new {
          Log.debug { "👈 #{template}" }
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

  WrenVM = VM.new "vm"

  def self.load_filters
    # Filters defined in Wren in template_extensions/filters/*.wren
    Dir.glob("template_extensions/filters/*.wren").each do |f|
      filter_name = Path[f].stem
      if !Env.filters.has_key? filter_name
        filter_code = File.read(f)
        WrenVM.interpret filter_name, filter_code

        Env.filters[filter_name] = Crinja.filter() do
          r = WrenVM.call(filter_name, "filter", "call", WrenVM.parse_args(arguments)).to_s
          Crinja::Value.new(r)
        end
      end
    end
  end
end
