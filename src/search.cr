module Search
  # Read an input file and extract the relevant stuff
  def self.extract_item(input : String, url : String, i : Int32)
    parser = Lexbor::Parser.new(File.read(input))
    return nil if parser.nodes("main").to_a.empty?
    text = parser.nodes(:_text) \
      .select(&.parents.all? { |node| node.visible? && !node.object? && !node.is_tag_noindex? }) \
        .select(&.parents.any? { |node| node.tag_name == "main" }) \
          .map(&.tag_text).reject(&.blank?) \
            .map(&.strip.gsub(/\s{2,}/, " ")).join(" ")
    {
      "title" => parser.nodes("title").to_a[0].tag_text,
      "text"  => text,
      "url"   => url,
      "id"    => i,
    }
  end

  def self.enable(is_enabled : Bool)
    return unless is_enabled

    Log.info { "🔍 Building search index..." }
    render
    Log.info { "✓ Search index queued" }
  end

  def self.render
    start = Time.instant
    inputs = Croupier::TaskManager.tasks.keys.select(&.to_s.ends_with?(".html"))
    Log.info { "🔍 Search: collected #{inputs.size} inputs in #{(Time.instant - start).total_milliseconds}ms" }
    FeatureTask.new(
      feature_name: "search",
      id: "search",
      output: output = (Path[Config.options.output] / "search.json").to_s,
      inputs: inputs,
      mergeable: false,
      no_save: true
    ) do
      Log.info { "👉 #{output}" }

      # Split into chunks for parallel processing
      chunk_size = 100
      num_chunks = (inputs.size // chunk_size) + 1

      # Channel for collecting results from fibers
      channels = Channel(Array(Hash(String, String | Int32)) | Exception).new

      # Process each chunk in a separate fiber
      num_chunks.times do |chunk_idx|
        spawn do
          begin
            start_idx = chunk_idx * chunk_size
            end_idx = Math.min(start_idx + chunk_size, inputs.size)
            chunk_data = inputs[start_idx...end_idx]

            results = Array(Hash(String, String | Int32)).new
            chunk_data.each_with_index do |input, i|
              item = extract_item(
                input,
                input.sub(/^output\//, "/"),
                start_idx + i
              )
              results << item unless item.nil?
            end
            channels.send(results)
          rescue ex
            channels.send(ex)
          end
        end
      end

      # Collect all results and write to file
      File.open(output, "w") do |io|
        all_data = Array(Hash(String, String | Int32)).new

        num_chunks.times do
          result = channels.receive
          case result
          when Array
            all_data.concat(result)
          when Exception
            Log.error { "Error in search chunk: #{result.message}" }
          end
        end

        all_data.to_json(io)
      end

      "" # Return empty string for task output
    end
  end
end
