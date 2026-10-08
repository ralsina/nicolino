require "./spec_helper"

require "lexbor"
require "../src/search"

private def page(main : String, head = "<title>T</title>")
  %(<html><head>#{head}</head><body><nav>menu</nav><main>#{main}</main><footer>foot</footer></body></html>)
end

describe Search do
  describe ".extract" do
    it "returns the title and the text inside <main>" do
      Search.extract(page("<h1>Hello</h1><p>World</p>")).should eq({"T", "Hello World"})
    end

    it "returns nil for a page without <main>" do
      Search.extract("<html><head><title>T</title></head><body><p>x</p></body></html>").should be_nil
    end

    it "skips scripts, styles, embedded objects and <noindex>" do
      html = page(%(<p>a</p><script>var x</script><style>p{}</style><object>o</object><noindex><p>secret</p></noindex><p>b</p>))
      Search.extract(html).should eq({"T", "a b"})
    end

    it "strips pieces, collapses whitespace runs and drops blank text" do
      Search.extract(page("<p>  one   two\n\n three </p>\n   \n<p>four</p>")).should eq({"T", "one two three four"})
    end

    it "includes text from every <main>" do
      html = %(<html><head><title>T</title></head><body><main>a</main><p>out</p><main>b</main></body></html>)
      Search.extract(html).should eq({"T", "a b"})
    end
  end
end
