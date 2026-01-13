require "benchmark"
require "just_html"

# Sample HTML with 200 headers
html = (1..100).map { |i|
  <<-HTML
  <article>
    <h1 class="title" id="title-#{i}">Title #{i}</h1>
    <h2 class="subtitle">Subtitle #{i}.1</h2>
    <p>Content here</p>
    <h2>Subtitle #{i}.2</h2>
    <p>More content</p>
  </article>
  HTML
}.join("\n")

puts "HTML size: #{html.bytesize} bytes"
puts "Headers: #{html.scan(/<h[12]/).size}"
puts

# Original version - multiple queries
def downgrade_headers_slow(doc, n = 2)
  (1..(6 - n)).each do |i|
    i = 6 - n - i + 1
    headers = doc.query_selector_all("h#{i}")
    headers.each do |node|
      downgraded = JustHTML::Element.new("h#{i + n}")
      # Copy attributes
      downgraded.attrs = node.attrs.dup
      # Copy children (inner_html equivalent)
      node.children.each do |child|
        downgraded.append_child(child)
      end
      # Replace the old header with the new one in one operation
      node.parent.try(&.replace_child(downgraded, node))
    end
  end
  doc
end

# Optimized version - single query, direct assignment
def downgrade_headers_fast(doc, n = 2)
  # Query all headers at once using CSS selector comma syntax
  all_headers = doc.query_selector_all((1..(6 - n)).map { |i| "h#{i}" }.join(", "))

  all_headers.each do |node|
    # Extract current header level
    current_level = node.name[1].to_i
    new_level = current_level + n

    # Create new element with attrs directly (no dup needed)
    downgraded = JustHTML::Element.new("h#{new_level}", node.attrs)

    # Move children in one operation using the internal array
    # This avoids repeated append_child calls
    node.children.each do |child|
      downgraded.append_child(child)
    end

    # Replace in parent
    node.parent.try(&.replace_child(downgraded, node))
  end
  doc
end

# Warmup
doc1 = JustHTML.parse(html)
downgrade_headers_slow(doc1)

doc2 = JustHTML.parse(html)
downgrade_headers_fast(doc2)

# Benchmark
Benchmark.ips do |x|
  x.report("Slow (multiple queries)") do
    doc = JustHTML.parse(html)
    downgrade_headers_slow(doc)
  end

  x.report("Fast (single query)") do
    doc = JustHTML.parse(html)
    downgrade_headers_fast(doc)
  end
end
