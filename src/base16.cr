require "sixteen"
require "./theme"

module Base16
  extend self

  # Enable base16 feature if enabled
  def self.enable(is_enabled : Bool)
    return unless is_enabled
    Log.info { "🎨 Generating color scheme and fonts..." }
    render_base16
    Log.info { "✓ Color scheme and fonts queued" }
  end

  def self.render_base16
    base16_template = Theme.template_path("base16.tmpl")
    FeatureTask.new(
      feature_name: "base16",
      id: "base16",
      output: (Path[Config.options.output] / "css" / "style.css").to_s,
      inputs: [Config.config_path] + Templates.get_deps(base16_template),
      mergeable: false
    ) do
      scheme = Config.get("site.color_scheme").as_s

      # Always use dark_variant and light_variant to ensure proper variant resolution
      # This handles auto-generation when variants don't exist
      dark_theme = Sixteen.dark_variant(scheme)
      light_theme = Sixteen.light_variant(scheme)

      # Process fonts configuration
      fonts = Config.fonts
      google_fonts = fonts.select(&.source.==("google"))
      google_fonts_url = google_fonts.map do |font|
        "family=#{font.family.tr(" ", "+")}:wght@#{font.weights.join(";")}"
      end.join("&")

      # Build font stacks for each role
      font_stacks = build_font_stacks(fonts)

      context = {
        "light"            => light_theme.context("_"),
        "dark"             => dark_theme.context("_"),
        "google_fonts_url" => google_fonts_url,
        "font_sans"        => font_stacks["sans"],
        "font_mono"        => font_stacks["mono"],
        "font_display"     => font_stacks["display"],
        "font_heading"     => font_stacks["heading"],
      }

      Templates.environment.get_template(base16_template).render(context)
    end
  end

  private def self.build_font_stacks(fonts : Array(Config::Font)) : Hash(String, String)
    stacks = {
      "sans"    => "\"Inter\", system-ui, -apple-system, \"Segoe UI\", Roboto, sans-serif",
      "mono"    => "'Fira Code', 'SF Mono', Consolas, monospace",
      "display" => "\"Inter\", system-ui, -apple-system, \"Segoe UI\", Roboto, sans-serif",
      "heading" => "\"Inter\", system-ui, -apple-system, \"Segoe UI\", Roboto, sans-serif",
    }

    fonts.each do |font|
      case font.role
      when "sans-serif"
        stacks["sans"] = "\"#{font.family}\", system-ui, -apple-system, \"Segoe UI\", Roboto, sans-serif"
        stacks["heading"] = stacks["sans"] if stacks["heading"] == stacks["sans"]
      when "monospace"
        stacks["mono"] = "\"#{font.family}\", 'Fira Code', 'SF Mono', Consolas, monospace"
      when "display"
        stacks["display"] = "\"#{font.family}\", sans-serif"
        stacks["heading"] = "\"#{font.family}\", sans-serif"
      end
    end

    stacks
  end
end
