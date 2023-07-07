require "crinja"

module Templates
  extend self

  class StoreLoader < Crinja::Loader
    def get_source(env : Crinja, template : String) : {String, String?}
      source = Croupier::TaskManager.get("#{template}")
      raise "Template #{template} not found" if source.nil?
      {source, nil}
    end
  end

  Env = Crinja.new
  Env.loader = StoreLoader.new

  def self.load_templates
    # Load templates from templates/ and put them in the k/v store
    Dir.glob("templates/*.tmpl").each do |template|
      Croupier::Task.new(
        inputs: [template],
        output: "kv://#{template}",
        proc: Croupier::TaskProc.new {
          Log.info { "<< #{template}" }
          File.read(template)
        })
    end
  end
end
