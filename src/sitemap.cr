module Sitemap
  HEADER = %(<?xml version="1.0" encoding="UTF-8"?>
<urlset
    xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9
                        http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">)

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
    # TODO: support robot exclusion
    # TODO: support alternates for locations
    start = Time.instant
    inputs = Croupier::TaskManager.tasks.keys.select(&.ends_with?(".html"))
    Log.info { "🗺️ Sitemap: collected #{inputs.size} inputs in #{(Time.instant - start).total_milliseconds}ms" }

    FeatureTask.new(
      feature_name: "sitemap",
      id: "sitemap",
      output: output = (Path[Config.options.output] / "sitemap.xml").to_s,
      inputs: inputs,
      mergeable: false,
      no_save: true
    ) do
      Log.info { "👉 #{output}" }

      # Split into chunks for parallel processing
      chunk_size = 100
      num_chunks = (inputs.size // chunk_size) + 1

      # Channel for collecting XML chunks from fibers
      channels = Channel(String).new

      # Process each chunk in a separate fiber
      num_chunks.times do |chunk_idx|
        spawn do
          begin
            start_idx = chunk_idx * chunk_size
            end_idx = Math.min(start_idx + chunk_size, inputs.size)
            chunk_data = inputs[start_idx...end_idx]

            base = URI.parse(Config.get("site.url").as_s)
            chunk_xml = String.build do |str|
              chunk_data.each do |input|
                next if noindex?(input)
                modtime = File.info(input).modification_time
                input_path = input.sub(/^output\//, "")
                str << %(<url>
                <loc>#{base.resolve(input_path)}</loc>
                <lastmod>#{modtime}</lastmod>
              </url>)
              end
            end
            channels.send(chunk_xml)
          rescue ex
            Log.error { "Error in sitemap chunk: #{ex.message}" }
            channels.send("")
          end
        end
      end

      # Write output
      File.open(output, "w") do |io|
        io << HEADER
        num_chunks.times do
          chunk = channels.receive
          io << chunk unless chunk.empty?
        end
        io << FOOTER
      end

      "" # Return empty string for task output
    end
  end
end
