# Functions that take a Lexbor document and return a modified version
# To create a Lexbor document, use `Lexbor::Parser.new(html)`
module HtmlFilters
  # Downgrade all headers by n levels (h1 -> h3 if n=2)
  def self.downgrade_headers(doc, n = 2)
    (1..(6 - n)).each do |i|
      i = 6 - n - i + 1
      headers = doc.nodes("h#{i}").to_a
      headers.each do |node|
        downgraded = doc.create_node("h#{i + n}")
        downgraded.inner_html = node.inner_html
        node.insert_before(downgraded)
      end
      headers.each do |node|
        node.remove!
      end
    end
    doc
  end

  # Make all relative links absolute to the site root
  # base is where the file containing the URIs is located
  # relative to the site root
  def self.make_links_absolute(doc, base)
    base_uri = URI.parse(base)
    doc.nodes("a").each do |node|
      next unless node.has_key? "href"
      node["href"] = base_uri.resolve(node["href"]).to_s
    end
    doc.nodes("img").each do |node|
      next unless node.has_key? "src"
      node["src"] = base_uri.resolve(node["src"]).to_s
    end
    doc
  end
end
