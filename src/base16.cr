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
      light_scheme = Config.get("site.light_scheme").as_s
      dark_scheme = Config.get("site.dark_scheme").as_s

      color_context = {
        "light" => Sixteen.light_variant(light_scheme).context("_"),
        "dark"  => Sixteen.dark_variant(dark_scheme).context("_"),
      }
      Templates.environment.get_template("templates/base16.tmpl").render(
        color_context)
    end
  end
end
