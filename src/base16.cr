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
    output_path = (Path[Config.options.output] / "css" / "style.css").to_s
    FeatureTask.new(
      feature_name: "base16",
      id: "base16",
      output: output_path,
      inputs: [Config.config_path, "kv://#{base16_template}"] + Templates.get_deps(base16_template) + LuaFilters.dependency_paths,
      no_save: true,
      mergeable: false
    ) do
      Log.info { "base16 task running..." }
      # Explicit dark_scheme/light_scheme overrides win; otherwise
      # both variants are derived from color_scheme (auto-generating
      # a variant when the family has no hand-made one)
      dark_theme = if Config.dark_scheme.empty?
                     Sixteen.dark_variant(Config.color_scheme)
                   else
                     Sixteen.theme(Config.dark_scheme)
                   end
      light_theme = if Config.light_scheme.empty?
                      Sixteen.light_variant(Config.color_scheme)
                    else
                      Sixteen.theme(Config.light_scheme)
                    end

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
        "font_emoji"       => font_stacks["emoji"],
      }

      content = Templates.environment.get_template(base16_template).render(context)

      # Write the output file
      Dir.mkdir_p(File.dirname(output_path))
      File.write(output_path, content)

      # Log the output file
      Log.info { "👉 #{output_path}" }

      # Return the path so croupier knows we wrote it
      output_path
    end
  end

  private def self.build_font_stacks(fonts : Array(Config::Font)) : Hash(String, String)
    stacks = {
      "sans"    => "\"Inter\", system-ui, -apple-system, \"Segoe UI\", Roboto, sans-serif",
      "mono"    => "'Fira Code', 'SF Mono', Consolas, monospace",
      "display" => "\"Inter\", system-ui, -apple-system, \"Segoe UI\", Roboto, sans-serif",
      "heading" => "\"Inter\", system-ui, -apple-system, \"Segoe UI\", Roboto, sans-serif",
      "emoji"   => "\"Apple Color Emoji\", \"Segoe UI Emoji\", \"Segoe UI Symbol\", \"Noto Color Emoji\", sans-serif",
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
      when "emoji"
        # Check if this is a monochrome emoji font (doesn't contain "Color" in the name)
        if font.family.includes?("Color")
          # Color emoji font - include color emoji fallbacks
          stacks["emoji"] = "\"#{font.family}\", \"Apple Color Emoji\", " \
                            "\"Segoe UI Emoji\", \"Segoe UI Symbol\", \"Noto Color Emoji\", sans-serif"
        else
          # Monochrome emoji font - use sans-serif fallback instead of color emoji fonts
          stacks["emoji"] = "\"#{font.family}\", sans-serif"
        end
      end
    end

    stacks
  end
end
