module Search
  # Read an input file and extract the relevant stuff
  def self.extract_item(input : String, url : String, i : Int32)
    entry = extract(File.read(input))
    return unless entry
    title, text = entry
    {
      "title" => title,
      "text"  => text,
      "url"   => url,
      "id"    => i,
    }
  end

  # Title and index text of a rendered page, or nil if it has no <main>
  def self.extract(html : String) : {String, String}?
    parser = Lexbor::Parser.new(html)
    return if parser.nodes(:main).empty?
    text = String.build do |io|
      append_text(parser.document!, false, io)
    end
    {parser.nodes(:title).first.tag_text, text}
  ensure
    # The document's memory lives outside the GC heap, so the GC
    # doesn't know to collect it soon: free it now, or every page's
    # tree stays alive until finalizers catch up
    parser.try &.free
  end

  # Index text: text nodes inside a <main> whose ancestors are all
  # visible, not embedded objects and not <noindex>. One walk that
  # skips excluded subtrees, instead of checking every text node's
  # ancestors. Pieces are stripped, inner whitespace runs collapsed,
  # and joined with single spaces.
  private def self.append_text(node : Lexbor::Node, in_main : Bool, io : IO) : Nil
    node.children do |child|
      if child.is_text?
        next unless in_main
        piece = child.tag_text
        next if piece.blank?
        io << ' ' unless io.bytesize == 0
        io << piece.strip.gsub(/\s{2,}/, " ")
      elsif child.visible? && !child.object? && !child.is_tag_noindex?
        append_text(child, in_main || child.is_tag_main?, io)
      end
    end
  end

  def self.enable(is_enabled : Bool)
    return unless is_enabled

    Log.info { "🔍 Building search index..." }
    render
    Log.info { "✓ Search index queued" }
  end

  def self.render
    start = Time.instant
    # Sorted for deterministic output, like the sitemap
    inputs = Croupier::TaskManager.tasks.keys.select(&.to_s.ends_with?(".html")).sort!
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
