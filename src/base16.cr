require "sixteen"
require "./theme"

module Base16
  extend self

  # Enable base16 feature if enabled
  def self.enable(is_enabled : Bool)
    return unless is_enabled
    render_base16
  end

  def self.render_base16
    base16_template = Theme.template_path("base16.tmpl")
    FeatureTask.new(
      feature_name: "base16",
      id: "base16",
      output: (Path[Config.options.output] / "css" / "color_scheme.css").to_s,
      inputs: ["conf.yml"] + Templates.get_deps(base16_template),
      mergeable: false
    ) do
      scheme = Config.get("site.color_scheme").as_s

      # Always use dark_variant and light_variant to ensure proper variant resolution
      # This handles auto-generation when variants don't exist
      dark_theme = Sixteen.dark_variant(scheme)
      light_theme = Sixteen.light_variant(scheme)

      color_context = {
        "light" => light_theme.context("_"),
        "dark"  => dark_theme.context("_"),
      }

      Templates.environment.get_template(base16_template).render(
        color_context)
    end
  end
end
