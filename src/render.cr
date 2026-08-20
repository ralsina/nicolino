# Helpers to render files/templates

require "lexbor"
require "./theme"

module Render
  # Generates pretty HTML properly templated
  def self.apply_template(template, context, lang = nil)
    lang ||= Config.language
    # Use Crinja's value type for flexibility
    ctx = Hash(String, Crinja::Value).new
    context.each do |k, v|
      ctx[k] = Crinja::Value.new(v)
    end
    # Add site config values to context using the specified language
    lang_config = Config[lang]
    ctx["site_title"] = Crinja::Value.new(lang_config.title)
    ctx["site_description"] = Crinja::Value.new(lang_config.description)
    ctx["site_url"] = Crinja::Value.new(lang_config.url)
    ctx["site_footer"] = Crinja::Value.new(lang_config.footer)
    ctx["site_nav_items"] = Crinja::Value.new(lang_config.nav_items)
    tmpl = Templates.get_template(template, lang)
    TemplatePreprocessor.render_with(Templates.environment, tmpl, ctx)
  end

  # Standard "Home / Section" breadcrumbs
  def self.section_breadcrumbs(section_name : String, section_link : String) : Array(NamedTuple(name: String, link: String))
    [{name: "Home", link: "/"}, {name: section_name, link: section_link}] of NamedTuple(name: String, link: String)
  end

  # Render title.tmpl (handles breadcrumbs and empty taxonomies)
  def self.title_html(title : String, link : String, breadcrumbs : Array(NamedTuple(name: String, link: String))) : String
    title_template = Theme.template_path("title.tmpl")
    Templates.environment.get_template(title_template).render({
      "title"       => title,
      "link"        => link,
      "breadcrumbs" => breadcrumbs,
      "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
    })
  end

  # Wrap content in page.tmpl and apply HTML filters (relative links)
  def self.page_html(output_path : String, content : String, title : String, breadcrumbs : Array(NamedTuple(name: String, link: String)), lang : String? = nil, fix_code_classes : Bool = false) : String
    page_template = Theme.template_path("page.tmpl")
    html = apply_template(page_template, {
      "content"     => content,
      "title"       => title,
      "breadcrumbs" => breadcrumbs,
    }, lang)
    doc = Lexbor::Parser.new(html)
    doc = HtmlFilters.make_links_relative(doc, output_path)
    if fix_code_classes
      HtmlFilters.fix_code_classes(doc).to_html
    else
      doc.to_html
    end
  end
end
