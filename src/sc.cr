require "shortcodes"
include Shortcodes

module Sc
  # Render shortcode using its template
  def self.render_sc(sc, context : Crinja::Context)
    if sc.markdown?
      context["inner"] = Discount.compile(sc.data)[0]
    else
      context["inner"] = sc.data
    end
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
    Log.info { "Scanning shortcodes" }
    Dir.glob("shortcodes/*.tmpl").each do |template|
      Croupier::Task.new(
        id: "shortcode",
        inputs: [template],
        output: "kv://#{template}",
        mergeable: false,
        proc: Croupier::TaskProc.new {
          Log.info { "👈 #{template}" }
          File.read(template)
        })
    end
  end
end
