module Sitemap
  HEADER = %(<?xml version="1.0" encoding="UTF-8"?>
<urlset
    xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9
                        http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">)

  FOOTER = "</urlset>"

  def self.render
    # TODO: support robot exclusion
    # TODO: support alternates for locations
    inputs = Croupier::TaskManager.tasks.keys
    Croupier::Task.new(
      id: "sitemap",
      output: output = "output/sitemap.xml",
      inputs: inputs,
      mergeable: false,
      no_save: true,
      proc: Croupier::TaskProc.new {
        Log.info { ">> #{output}" }
        File.open(output, "w") do |io|
          io << HEADER
          base = URI.parse(Config.config["canonical_url"].to_s)
          inputs.each do |input|
            next unless input =~ /\.html$/
            modtime = File.info(input).modification_time
            input = input.sub(/^output\//, "")
            io << %(<url>
              <loc>#{base.resolve(input)}</loc>
              <lastmod>#{modtime}</lastmod>
             </url>)
          end
        end
      }
    )
  end
end
