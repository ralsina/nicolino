require "shortcodes"
include Shortcodes

module Sc
  # FIXME: pass more context
  def self.replace(text)
    parsed = parse(text)
    parsed.errors.each do |e|
      p! e # TODO: show actual error
    end
    # Starting at the end of text, go backwards
    # replacing each shortcode with its output
    parsed.shortcodes.reverse_each do |sc|
      text = text[0, sc.position] +
             render_sc(sc, Hash(String, String).new) +
             text[sc.position + sc.len, text.size]
    end
    text
  end

  # Render shortcode using its template
  def self.render_sc(sc, context)
    # FIXME: dummy
    "[#{sc.name}]"
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
