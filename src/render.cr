# Helpers to render files/templates

require "lexbor"

module Render
  # Generates pretty HTML properly templated
  def self.apply_template(html, template)
    # TODO: use a copy of config
    output = Templates::Env.get_template(template).render(
      Config.config.merge({
        "content" => html,
      }))
    output = Lexbor::Parser.new(output).to_pretty_html \
      if Config.options.pretty_html?
    output
  end
end
