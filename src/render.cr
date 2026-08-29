# Helpers to render files/templates

require "lexbor"
require "./theme"

module Render
  # Generates pretty HTML properly templated
  def self.apply_template(template, context, lang = nil)
    lang ||= Config.language
    # Use Crinja's value type for flexibility
    ctx = Hash(String, Crinja::Value).new
    context.each do |key, value|
      ctx[key] = Crinja::Value.new(value)
    end
    # Add site config values to context using the specified language
    lang_config = Config[lang]
    ctx["site_title"] = Crinja::Value.new(lang_config.title)
    ctx["site_description"] = Crinja::Value.new(lang_config.description)
    ctx["site_url"] = Crinja::Value.new(lang_config.url)
    ctx["site_footer"] = Crinja::Value.new(lang_config.footer)
    ctx["site_nav_items"] = Crinja::Value.new(lang_config.nav_items)
    ctx["lang"] = Crinja::Value.new(lang)
    # Theme parameters from theme.yml, overridden by conf.yml's
    # theme_params (see Theme.params)
    ctx["theme"] = Crinja::Value.new(Theme.params)
    # Canonical URL for the page (used by rel=canonical and OpenGraph):
    # the site URL plus the page's root-relative link, with index.html
    # normalized away (e.g. "/foo/index.html" -> "/foo/")
    if raw_link = ctx["link"]?.try(&.as_s?)
      link = raw_link.sub(/index\.html$/, "")
      base_url = lang_config.url.chomp("/")
      ctx["canonical_url"] = Crinja::Value.new("#{base_url}#{link}")
    end
    # OpenGraph images must be absolute URLs; root-relative preview
    # images are resolved against the site URL
    if image = ctx["preview_image"]?.try(&.as_s?)
      unless image.matches?(/^[a-zA-Z][a-zA-Z0-9+.\-]*:/) || image.empty?
        ctx["preview_image"] = Crinja::Value.new("#{lang_config.url.chomp("/")}#{image}")
      end
    end
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
  def self.page_html(output_path : String, content : String, title : String,
                     breadcrumbs : Array(NamedTuple(name: String, link: String)),
                     lang : String? = nil,
                     language_links : Array(Hash(String, String))? = nil,
                     fix_code_classes : Bool = false) : String
    page_template = Theme.template_path("page.tmpl")
    context = {
      "content"     => content,
      "title"       => title,
      "breadcrumbs" => breadcrumbs,
      "link"        => output_path,
    } of String => String | Array(NamedTuple(name: String, link: String)) | Array(Hash(String, String))?
    context["language_links"] = language_links if language_links
    html = apply_template(page_template, context, lang)
    doc = Lexbor::Parser.new(html)
    # Convert output_path to a link URL for the relativizer.
    # Some callers pass filesystem paths (output/foo.html), others
    # already-converted URLs (/foo/).  Detect and handle both.
    base = if output_path.starts_with?("/")
             output_path
           else
             Utils.path_to_link(output_path)
           end
    doc = HtmlFilters.make_links_relative(doc, base)
    if fix_code_classes
      HtmlFilters.fix_code_classes(doc).to_html
    else
      doc.to_html
    end
  end
end
