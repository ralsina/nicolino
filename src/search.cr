module Search
  # Patch Lexbor::Node to report if the node is "displayable"
  struct Lexbor::Node
    def displayble?
      visible? && !object? && !is_tag_noindex?
    end
  end

  # Read an input file and extract the relevant stuff
  def self.extract_item(input : String, url : String, i : Int32)
    parser = Lexbor::Parser.new(File.read(input))
    return nil if parser.nodes("main").to_a.empty?
    text = parser.nodes(:_text) \
      .select(&.parents.all?(&.displayble?)) \
        .select(&.parents.any? { |n| n.tag_name == "main" }) \
          .map(&.tag_text).reject(&.blank?) \
            .map(&.strip.gsub(/\s{2,}/, " ")).join(" ")
    {
      "title" => parser.nodes("title").to_a[0].tag_text,
      "text"  => text,
      "url"   => url,
      "id"    => i,
    }
  end

  def self.render
    inputs = Croupier::TaskManager.tasks.keys.select(&.to_s.ends_with?(".html"))
    Croupier::Task.new(
      id: "search",
      output: output = (Path[Config.options.output] / "search.json").to_s,
      inputs: inputs,
      mergeable: false,
      no_save: true,
      proc: Croupier::TaskProc.new {
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
      }
    )
  end
end
