# Helpers to render files/templates

require "lexbor"

module Render
  # Generates pretty HTML properly templated
  def self.apply_template(template, context)
    # Add all config keys to context without clobbering
    Config.get("site").as_h.map { |k, v|
      context["site_#{k}"] = v.as_s
    }
    Templates::Env.get_template(template).render(context)
  end
end
