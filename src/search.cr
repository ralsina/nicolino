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
    render
  end

  def self.render
    start = Time.monotonic
    inputs = Croupier::TaskManager.tasks.keys.select(&.to_s.ends_with?(".html"))
    Log.info { "🔍 Search: collected #{inputs.size} inputs in #{(Time.monotonic - start).total_milliseconds}ms" }
    Croupier::Task.new(
      id: "search",
      output: output = (Path[Config.options.output] / "search.json").to_s,
      inputs: inputs,
      mergeable: false,
      no_save: true
    ) do
      Log.info { "👉 #{output}" }
      File.open(output, "w") do |io|
        data = Array(Hash(String, String | Int32)).new
        inputs.each_with_index do |input, i|
          item = extract_item(
            input,
            input.sub(/^output\//, "/"),
            i
          )
          data << item unless item.nil?
        end
        data.to_json(io)
      end
    end
  end
end
