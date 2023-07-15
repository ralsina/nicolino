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
end
