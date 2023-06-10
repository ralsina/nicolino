module Render
  # Writes html, templated properly with config, into path
  def self.write(html, page_template, path, config)
    rendered_page = Crustache.render(page_template,
      config.merge({
        "content" => html,
      }))
    Dir.mkdir_p(File.dirname path)
    File.open(path, "w") do |io|
      io.puts rendered_page
    end
  end
end
