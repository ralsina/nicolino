require "shortcodes"
include Shortcodes

module Sc
  # Shortcode renders that failed during the current run (see the
  # rescue in render_sc). The build reports these and exits non-zero
  # so a rendering failure can never silently corrupt a page.
  @@render_failures = [] of NamedTuple(shortcode: String, error: String)

  def self.render_failures
    @@render_failures
  end

  # Clear recorded failures (called at the start of each run)
  def self.reset_failures
    @@render_failures.clear
  end

  # Recursively collect all shortcodes in a text, including
  # shortcodes nested inside other shortcodes' bodies
  def self.shortcodes_in(text) : Array(Shortcodes::Shortcode)
    # Fast path: if no shortcode delimiters, skip parsing entirely
    return [] of Shortcodes::Shortcode unless text.includes?("{{")

    sc_list = Shortcodes.parse(text)
    return [] of Shortcodes::Shortcode if sc_list.shortcodes.empty?

    final_list = sc_list.shortcodes
    sc_list.shortcodes.each do |scode|
      if scode.markdown? # Recurse for nested shortcodes
        final_list += shortcodes_in(scode.data)
      end
    end
    Set.new(final_list).to_a
  end

  # kv:// inputs for the shortcode templates a content file needs,
  # so tasks that render it can declare them as dependencies.
  # This does not instantiate a Markdown::File (which would register
  # the file in the global posts hash).
  def self.kv_deps_for_file(path : String) : Array(String)
    return [] of String unless File.exists?(path)
    contents = File.read(path)
    text = if contents.starts_with?("---\n")
             _, _, body = contents.split("---\n", 3)
             body || ""
           else
             contents
           end
    shortcodes_in(text).reject(&.is_inline?).map { |scode| "kv://shortcodes/#{scode.name}.tmpl" }
  end

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
      template_path = "shortcodes/#{sc.name}.tmpl"
      template = Templates.environment.get_template(template_path)
      template.render(context)
    end
  rescue ex : Crinja::TemplateNotFoundError
    raise "Missing shortcode template: shortcodes/#{sc.name}.tmpl\n" +
          "Available shortcodes: #{available_shortcodes.join(", ")}"
  rescue ex
    Log.error(exception: ex) { "Can't load shortcode #{sc.name}: #{ex.message}" }
    # Record the failure so the build can exit non-zero instead of
    # silently emitting the literal shortcode into the output
    @@render_failures << {shortcode: sc.name, error: ex.message || ex.class.to_s}
    sc.whole
  end

  # Get list of available shortcodes for error messages
  # (memoized: it globs the shortcodes directory and is called once
  # per post while computing task dependencies)
  @@available_shortcodes : Array(String)? = nil

  def self.available_shortcodes : Array(String)
    @@available_shortcodes ||= Dir.glob("shortcodes/*.tmpl").map do |path|
      File.basename(path, ".tmpl")
    end.sort!
  end

  # Load shortcodes from shortcodes/ and put them in the k/v store
  # ameba:disable Documentation/DocumentationAdmonition
  # TODO refactor duplication from Templates.load_templates
  def self.load_shortcodes : Int32
    Log.debug { "Scanning shortcodes" }
    # Rescan the shortcodes directory for this run
    @@available_shortcodes = nil
    count = 0
    Dir.glob("shortcodes/*.tmpl").each do |template|
      # Declare include/extends/import dependencies, same as theme
      # templates (no shortcode uses them today, but if one ever does
      # its dependencies are tracked correctly)
      deps = Templates.get_deps(template)
      FeatureTask.new(
        feature_name: "shortcodes",
        id: "shortcode",
        inputs: [template] + deps,
        output: "kv://#{template}",
        mergeable: false
      ) do
        Log.debug { "👈 #{template}" }
        File.read(template)
      end
      count += 1
    end
    count
  end
end
