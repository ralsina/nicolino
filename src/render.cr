# Helpers to render files/templates

require "lexbor"

module Render
  # Generates pretty HTML properly templated
  def self.apply_template(html, template, title = nil)
    title = title ? title : Config.config["title"].to_s
    context = Markdown::ValueType.new
    context.merge(Config.config)
    context["title"] = title
    context["content"] = html
    output = Templates::Env.get_template(template).render(context)
    output = Lexbor::Parser.new(output).to_pretty_html \
      if Config.options.pretty_html?
    output
  end
end
