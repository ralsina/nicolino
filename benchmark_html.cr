require "just_html"
require "lexbor"

# Sample HTML with 200 headers (similar to processing 100 posts)
html = (1..100).map { |i|
  <<-HTML
  <article>
    <h1>Title #{i}</h1>
    <h2>Subtitle #{i}.1</h2>
    <p>Content here</p>
    <h2>Subtitle #{i}.2</h2>
    <p>More content</p>
  </article>
  HTML
}.join("\n")

puts "HTML size: #{html.bytesize} bytes"
puts "Headers: #{html.scan(/<h[12]/).size}"
puts

# Warmup
JustHTML.parse(html)
Lexbor::Parser.new(html)

# Benchmark JustHTML
start = Time.monotonic
100.times do
  doc = JustHTML.parse(html)
  (1..4).each do |i|
    headers = doc.query_selector_all("h#{i}")
    headers.each do |node|
      downgraded = JustHTML::Element.new("h#{i + 2}")
      downgraded.attrs = node.attrs.dup
      node.children.each do |child|
        downgraded.append_child(child)
      end
      node.parent.try(&.replace_child(downgraded, node))
    end
  end
end
justhtml_time = Time.monotonic - start
puts "JustHTML (100 iterations): #{justhtml_time.total_seconds}s (#{(justhtml_time.total_milliseconds).round(2)}ms per iteration)"

# Benchmark Lexbor
start = Time.monotonic
100.times do
  doc = Lexbor::Parser.new(html)
  (1..4).each do |i|
    headers = doc.nodes("h#{i}").to_a
    headers.each do |node|
      downgraded = doc.create_node("h#{i + 2}")
      downgraded.inner_html = node.inner_html
      if node.attributes.has_key? "class"
        downgraded["class"] = node.attributes["class"]
      end
      node.insert_before(downgraded)
    end
    headers.each do |node|
      node.remove!
    end
  end
end
lexbor_time = Time.monotonic - start
puts "Lexbor (100 iterations): #{lexbor_time.total_seconds}s (#{(lexbor_time.total_milliseconds).round(2)}ms per iteration)"

puts "\nSpeedup: #{(justhtml_time.total_seconds / lexbor_time.total_seconds).round(2)}x"
