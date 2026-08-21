module Search
  # Read an input file and extract the relevant stuff
  def self.extract_item(input : String, url : String, i : Int32)
    parser = Lexbor::Parser.new(File.read(input))
    return if parser.nodes("main").to_a.empty?
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
    output = (Path[Config.options.output] / "search.json").to_s
    FeatureTask.new(
      feature_name: "search",
      id: "search",
      output: output,
      inputs: inputs,
      mergeable: false,
      no_save: true
    ) do
      Log.info { "👉 #{output}" }

      # Split into chunks for parallel processing
      chunks = Utils.parallel_chunks(inputs) do |chunk_data, start_idx|
        results = Array(Hash(String, String | Int32)).new
        chunk_data.each_with_index do |input, i|
          item = extract_item(
            input,
            Utils.path_to_link(input),
            start_idx + i
          )
          results << item unless item.nil?
        end
        results
      end

      # Write results to file incrementally, chunk by chunk,
      # avoiding a flattened copy of all items and one big JSON buffer
      File.open(output, "w") do |io|
        io << "["
        first_item = true
        chunks.each do |chunk_results|
          chunk_results.each do |item|
            io << "," unless first_item
            first_item = false
            item.to_json(io)
          end
        end
        io << "]"
      end

      "" # Return empty string for task output
    end
  end
end
