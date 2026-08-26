require "log"
require "tartrazine"

# Server-side syntax highlighting for markdown code blocks.
#
# Discount compiles fenced code blocks to the very regular
# <pre><code class="language">...escaped source...</code></pre>
# shape, so highlighting happens as a string splice on the compiled
# HTML (before any Lexbor pass): the code content is unescaped,
# run through tartrazine, and the block is replaced by the formatted
# markup. Highlighted code uses CSS classes prefixed "tz-" (no
# inline styles), so the generated css/syntax.css can swap palettes
# for the dark/light scheme toggle with no client-side JavaScript.
#
# The syntax themes are derived from the site's base16 color_scheme
# (dark + light variants) unless conf.yml sets syntax_theme to an
# explicit tartrazine theme name.
module Highlight
  # Lexers are expensive to load: memoize per language name. A nil
  # entry marks languages with no lexer, so they short-circuit after
  # the first lookup
  @@lexers = Hash(String, Tartrazine::BaseLexer?).new
  @@lexers_mutex = Mutex.new

  # Regex for Discount's fenced-code output. The content is
  # HTML-escaped, so "</code>" can never occur inside it
  CODE_BLOCK = /<pre><code class="([a-zA-Z0-9+#._-]+)">(.*?)<\/code><\/pre>/m

  # Whether server-side highlighting is active for this build
  def self.enabled? : Bool
    Config.syntax_highlighter == "tartrazine"
  end

  # Highlight every fenced code block in *html*. Blocks whose
  # language has no lexer are returned untouched (logged at debug).
  def self.html(html : String) : String
    return html unless enabled?
    html.gsub(CODE_BLOCK) do |match|
      language = $1
      source = HTML.unescape($2)

      lexer = lexer_for(language)
      next match if lexer.nil?

      highlighted = formatter.format(source, lexer)
      %(<pre class="highlight">#{highlighted}</pre>)
    end
  end

  # The dark and light syntax themes for this site: derived from the
  # base16 color_scheme, or the explicit syntax_theme override
  def self.themes : {Tartrazine::Theme, Tartrazine::Theme}
    explicit = Config.syntax_theme
    if explicit.empty?
      scheme = Config.color_scheme
      {Tartrazine.theme(scheme, "dark"), Tartrazine.theme(scheme, "light")}
    else
      theme = Tartrazine.theme(explicit)
      {theme, theme}
    end
  end

  # The stylesheet for highlighted code: the dark theme scoped to
  # [data-theme=dark], the light theme to everything else (or plain
  # when a single explicit syntax_theme is configured). The
  # Background rule's background-color is dropped so themes keep
  # their own code-block backgrounds and only token colors apply.
  def self.css : String
    dark_theme, light_theme = themes
    dark_defs = strip_background(style_defs_for(dark_theme))
    return dark_defs if Config.syntax_theme.empty? == false

    light_defs = strip_background(style_defs_for(light_theme))
    dark_indented = dark_defs.split('\n').map { |line| "  #{line}" }.join('\n')
    light_indented = light_defs.split('\n').map { |line| "  #{line}" }.join('\n')
    <<-CSS
      [data-theme="dark"] {
      #{dark_indented}
      }

      :root:not([data-theme="dark"]),
      [data-theme="light"] {
      #{light_indented}
      }
      CSS
  end

  # Queue the css/syntax.css task (called from the build pipeline)
  def self.render_css : Nil
    output_path = (Path[Config.options.output] / "css" / "syntax.css").to_s
    FeatureTask.new(
      feature_name: "syntax",
      id: "syntax-css",
      output: output_path,
      inputs: [Config.config_path],
      no_save: true,
      mergeable: false
    ) do
      Log.info { "👉 #{output_path}" }
      Dir.mkdir_p(File.dirname(output_path))
      File.write(output_path, css)
      output_path
    end
  end

  # The singleton HTML formatter: class-based output (no inline
  # styles) so syntax.css controls the palette per color scheme
  def self.formatter : Tartrazine::Html
    @@formatter ||= Tartrazine::Html.new(
      theme: Tartrazine.theme("default-dark"),
      class_prefix: "tz-",
      standalone: false,
      surrounding_pre: false
    )
  end

  def self.lexer_for(language : String) : Tartrazine::BaseLexer?
    cached = @@lexers_mutex.synchronize { @@lexers[language]? }
    return cached if cached

    @@lexers_mutex.synchronize do
      @@lexers[language] ||= begin
        Tartrazine.lexer(name: language)
      rescue ex : Exception
        # Unknown or unsupported language: leave such blocks alone
        Log.debug { "No tartrazine lexer for #{language.inspect}: #{ex.message}" }
        nil
      end
    end
  end

  private def self.style_defs_for(theme : Tartrazine::Theme) : String
    Tartrazine::Html.new(
      theme: theme,
      class_prefix: "tz-",
      standalone: false,
      surrounding_pre: false
    ).style_defs
  end

  # Remove the background-color declaration from the Background
  # rule (".tz-b"): code-block backgrounds belong to the theme
  private def self.strip_background(defs : String) : String
    defs.gsub(/\.tz-b\s*\{[^}]*background-color:[^;]*;\s*/m, ".tz-b {")
  end
end
