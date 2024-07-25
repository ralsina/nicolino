# Helpers to render files/templates

require "lexbor"

module Render
  # Generates pretty HTML properly templated
  def self.apply_template(template, context)
    ctx = Hash(String, (Array(String) | String | Nil | Bool | NamedTuple(link: String, title: String))).new
    context.map { |k, v|
      ctx[k] = v
    }
    # Add all config keys to context without clobbering
    Config.get("site").as_h.map { |k, v|
      ctx["site_#{k}"] = (v.as_a?.try &.map(&.as_s)) || v.as_s?
    }
    Templates::Env.get_template(template).render(ctx)
  end
end
