# Helpers to render files/templates

require "lexbor"

module Render
  # Generates pretty HTML properly templated
  def self.apply_template(template, context, lang = nil)
    lang ||= Config.language
    # Use Crinja's value type for flexibility
    ctx = Hash(String, Crinja::Value).new
    context.map { |k, v|
      ctx[k] = Crinja::Value.new(v)
    }
    # Add site config values to context using the specified language
    lang_config = Config[lang]
    ctx["site_title"] = Crinja::Value.new(lang_config.title)
    ctx["site_description"] = Crinja::Value.new(lang_config.description)
    ctx["site_url"] = Crinja::Value.new(lang_config.url)
    ctx["site_footer"] = Crinja::Value.new(lang_config.footer)
    Templates.environment.get_template(template).render(ctx)
  end
end
