require "benchmark"
require "just_html"
require "lexbor"

# Sample HTML with 200 headers
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

# Benchmark JustHTML query_selector_all
Benchmark.ips do |x|
  jh_doc = JustHTML.parse(html)
  x.report("JustHTML query_selector_all") do
    count = 0
    count = jh_doc.query_selector_all("h1 h2 h3 h4").size
  end

  lb_doc = Lexbor::Parser.new(html)
  x.report("Lexbor nodes") do
    count = 0
    (1..4).each do |i|
      count += lb_doc.nodes("h#{i}").to_a.size
    end
    count
  end
end

# Benchmark JustHTML parse
Benchmark.ips do |x|
  x.report("JustHTML parse") do
    jh_doc = JustHTML.parse(html)
  end

  x.report("Lexbor parse") do
    lb_doc = Lexbor::Parser.new(html)
  end
end
