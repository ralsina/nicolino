require "shortcodes"
include Shortcodes

module Sc
  # Render shortcode using its template
  def self.render_sc(sc, context : Crinja::Context)
    context["inner"] = sc.data
    args = Hash(String | Int32, String).new
    i = 0
    sc.args.each do |a|
      if a.name == ""
        args["#{i}"] = a.value
        i += 1
      else
        args[a.name] = a.value
      end
    end
    context["args"] = args

    begin
      template = Templates::Env.get_template("shortcodes/#{sc.name}.tmpl")
    rescue ex
      Log.error { "Can't load shortcode #{sc.name}: #{ex.message}" }
      return sc.whole
    end
    template.render(context)
  end

  # Load shortcodes from shortcodes/ and put them in the k/v store
  # TODO refactor duplication from Templates.load_templates
  def self.load_shortcodes
    Dir.glob("shortcodes/*.tmpl").each do |template|
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
