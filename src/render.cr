# Helpers to render files/templates

require "lexbor"

module Render
  # Generates pretty HTML properly templated
  def self.apply_template(template, context)
    # Add all config keys to context without clobbering
    Config.config.keys.each { |k|
      next if k == "options"
      next if context.has_key? k
      context[k.as_s] = Config.config[k].as_s
    }
    output = Templates::Env.get_template(template).render(context)
    output = Lexbor::Parser.new(output).to_pretty_html \
      if Config.options.pretty_html?
    output
  end
end
