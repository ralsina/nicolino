# Helpers to render files/templates

require "lexbor"

module Render
  # Generates pretty HTML properly templated
  def self.apply_template(template, context)
    # Use Crinja's value type for flexibility
    ctx = Hash(String, Crinja::Value).new
    context.map { |k, v|
      ctx[k] = Crinja::Value.new(v)
    }
    # Add all config keys to context without clobbering
    Config.get("site").as_h.map { |k, v|
      ctx["site_#{k}"] = Crinja::Value.new((v.as_a?.try &.map(&.as_s)) || v.as_s?)
    }
    Templates.environment.get_template(template).render(ctx)
  end
end
