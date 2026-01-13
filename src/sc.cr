require "shortcodes"
include Shortcodes

module Sc
  # Render shortcode using its template
  def self.render_sc(sc, context : Crinja::Context) : String
    if sc.markdown?
      context["inner"] = Discount.compile(sc.data)[0]
    else
      context["inner"] = sc.data
    end
    args = Hash(String | Int32, String).new
    i = 0
    sc.args.each do |arg|
      if arg.name == ""
        args["#{i}"] = arg.value
        i += 1
      else
        args[arg.name] = arg.value
      end
    end
    context["args"] = args

    if sc.is_inline?
      Crinja.render(sc.data, context)
    else
      template = Templates.environment.get_template("shortcodes/#{sc.name}.tmpl")
      template.render(context)
    end
  rescue ex : Crinja::TemplateNotFoundError
    raise "Missing shortcode template: shortcodes/#{sc.name}.tmpl\n" +
          "Available shortcodes: #{available_shortcodes.join(", ")}"
  rescue ex
    Log.error(exception: ex) { "Can't load shortcode #{sc.name}: #{ex.message}" }
    sc.whole
  end

  # Get list of available shortcodes for error messages
  def self.available_shortcodes : Array(String)
    Dir.glob("shortcodes/*.tmpl").map do |path|
      File.basename(path, ".tmpl")
    end.sort!
  end

  # Load shortcodes from shortcodes/ and put them in the k/v store
  # TODO refactor duplication from Templates.load_templates
  def self.load_shortcodes
    Log.debug { "Scanning shortcodes" }
    Dir.glob("shortcodes/*.tmpl").each do |template|
      Croupier::Task.new(
        id: "shortcode",
        inputs: [template],
        output: "kv://#{template}",
        mergeable: false
      ) do
        Log.debug { "👈 #{template}" }
        File.read(template)
      end
    end
  end
end
