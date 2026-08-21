module Sitemap
  HEADER = <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset
        xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9
                            http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">
    XML

  FOOTER = "</urlset>"

  def self.enable(is_enabled : Bool)
    return unless is_enabled

    Log.info { "🗺️  Building sitemap..." }
    render
    Log.info { "✓ Sitemap queued" }
  end

  def self.noindex?(path)
    File.read(path).includes? %(<meta name="robots" content="noindex">)
  end

  def self.render
    # Pending: support robot exclusion
    # Pending: support alternates for locations
    start = Time.instant
    # Sorted for deterministic output: task registration order follows
    # parallel content reading and is not stable
    inputs = Croupier::TaskManager.tasks.keys.select(&.ends_with?(".html")).sort!
    Log.info { "🗺️ Sitemap: collected #{inputs.size} inputs in #{(Time.instant - start).total_milliseconds}ms" }

    output = (Path[Config.options.output] / "sitemap.xml").to_s
    FeatureTask.new(
      feature_name: "sitemap",
      id: "sitemap",
      output: output,
      inputs: inputs,
      mergeable: false,
      no_save: true
    ) do
      Log.info { "👉 #{output}" }

      # Split into chunks for parallel processing
      chunks = Utils.parallel_chunks(inputs) do |chunk_data, _start_idx|
        base = URI.parse(Config.url)
        String.build do |str|
          chunk_data.each do |input|
            next if noindex?(input)
            modtime = File.info(input).modification_time
            input_path = input.sub(/^#{Regex.escape(Utils.output_prefix)}/, "")
            str << %(<url> # ameba:disable Style/MultilineStringLiteral
              <loc>#{base.resolve(input_path)}</loc>
              <lastmod>#{modtime}</lastmod>
            </url>)
          end
        end
      end

      # Write output incrementally, chunk by chunk, avoiding
      # a joined copy of all chunks in memory
      File.open(output, "w") do |io|
        io << HEADER
        chunks.each do |chunk|
          io << chunk
        end
        io << FOOTER
      end

      "" # Return empty string for task output
    end
  end
end
