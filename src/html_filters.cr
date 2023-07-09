# Functions that take a HTML string and return a HTML string
module HtmlFilters
  # Downgrade all headers by n levels (h1 -> h3 if n=2)
  def self.downgrade_headers(html, n = 2)
    doc = Lexbor::Parser.new(html)
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
    doc.to_html
  end
end
