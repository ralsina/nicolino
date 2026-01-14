require "sixteen"

module Base16
  extend self

  def self.render_base16
    Croupier::Task.new(
      id: "base16",
      output: (Path[Config.options.output] / "css" / "color_scheme.css").to_s,
      inputs: ["conf.yml"] + Templates.get_deps("templates/base16.tmpl"),
      mergeable: false
    ) do
      # Try color_scheme first, fall back to dark_scheme/light_scheme for backwards compatibility
      scheme = if Config.get("site").as_h.has_key?("color_scheme")
                 Config.get("site.color_scheme").as_s
               else
                 # For backwards compatibility, use dark_scheme as the base
                 Config.get("site.dark_scheme").as_s
               end

      # Try to use it directly as a theme name first
      # If that fails, use it as a family base name with dark_variant/light_variant
      begin
        dark_theme = Sixteen.theme(scheme)
        # For light theme, we need to find the light variant of this family
        # Try to find it by replacing -dark with -light or using find_variant
        light_scheme = scheme.gsub(/-dark$/, "-light")
        light_theme = begin
          Sixteen.theme(light_scheme)
        rescue
          # If that doesn't work, use the light_variant method
          Sixteen.light_variant(scheme)
        end
      rescue
        # Not a valid theme name, treat it as a family base name
        dark_theme = Sixteen.dark_variant(scheme)
        light_theme = Sixteen.light_variant(scheme)
      end

      color_context = {
        "light" => light_theme.context("_"),
        "dark"  => dark_theme.context("_"),
      }

      # Also store the theme slugs for highlight.js
      # This makes site_dark_scheme and site_light_scheme available
      # for backwards compatibility with templates
      Config.config.set_default("site.dark_scheme", dark_theme.slug)
      Config.config.set_default("site.light_scheme", light_theme.slug)

      Templates.environment.get_template("templates/base16.tmpl").render(
        color_context)
    end
  end
end
