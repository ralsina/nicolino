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
      color_context = {
        "light" => Sixteen.theme(Config.get("site.light_scheme").as_s).context("_"),
        "dark"  => Sixteen.theme(Config.get("site.dark_scheme").as_s).context("_"),
      }
      Templates::Env.get_template("templates/base16.tmpl").render(
        color_context)
    end
  end
end
