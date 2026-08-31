require "./spec_helper"

require "lexbor"
require "../src/html_filters"

def parse(html : String)
  Lexbor::Parser.new(html)
end

describe HtmlFilters do
  describe ".downgrade_headers" do
    it "shifts the highest header level to n" do
      doc = parse("<h3>Title</h3><h4>Sub</h4>")
      result = HtmlFilters.downgrade_headers(doc, 2).to_html
      result.should contain "<h2>"
      result.should contain "<h3>"
      result.should_not contain "<h4>"
    end

    it "downgrades h1 when n is 2" do
      doc = parse("<h1>Big</h1><h2>Small</h2>")
      result = HtmlFilters.downgrade_headers(doc, 2).to_html
      result.should contain "<h2>Big</h2>"
      result.should contain "<h3>Small</h3>"
    end

    it "leaves documents alone when the highest level is already n" do
      html = "<h2>Fine</h2>"
      HtmlFilters.downgrade_headers(parse(html), 2).to_html.should contain "<h2>Fine</h2>"
    end

    it "never creates headings above level 6" do
      doc = parse("<h5>A</h5><h6>B</h6>")
      result = HtmlFilters.downgrade_headers(doc, 2).to_html
      result.should_not match(/<h[7-9]/)
    end
  end

  describe ".remove_empty_paragraphs" do
    it "removes empty and whitespace-only paragraphs" do
      doc = parse("<p></p><p>   </p><p>kept</p>")
      result = HtmlFilters.remove_empty_paragraphs(doc).to_html
      result.should contain "<p>kept</p>"
      result.should_not contain "<p></p>"
    end

    it "keeps paragraphs that hold only an image" do
      doc = parse(%(<p>text</p><p><img src="/images/a.png" alt="a"></p><p></p>))
      result = HtmlFilters.remove_empty_paragraphs(doc).to_html
      result.should contain %(<img src="/images/a.png" alt="a">)
      result.should_not contain "<p></p>"
    end
  end

  describe ".fix_code_classes" do
    it "adds a language- class to code blocks" do
      doc = parse(%(<pre><code class="crystal">x = 1</code></pre>))
      result = HtmlFilters.fix_code_classes(doc).to_html
      result.should contain %(class="crystal language-crystal")
      result.should contain %(data-lang="crystal")
    end

    it "leaves code blocks that already have a language- class" do
      html = %(<pre><code class="language-crystal">x = 1</code></pre>)
      result = HtmlFilters.fix_code_classes(parse(html)).to_html
      result.should contain %(class="language-crystal")
    end

    it "ignores code blocks without a class" do
      html = %(<pre><code>x = 1</code></pre>)
      result = HtmlFilters.fix_code_classes(parse(html)).to_html
      result.should_not contain "language-"
    end
  end

  describe ".make_links_relative" do
    it "normalizes redundant path segments in hrefs" do
      doc = parse(%(<a href="./other.html">x</a>))
      result = HtmlFilters.make_links_relative(doc, "/posts/sub/page.html").to_html
      result.should contain %(href="other.html")
    end

    it "keeps links to the same directory unchanged" do
      doc = parse(%(<a href="other.html">x</a>))
      result = HtmlFilters.make_links_relative(doc, "/posts/sub/page.html").to_html
      result.should contain %(href="other.html")
    end

    it "leaves absolute URLs, root-relative and fragment links alone" do
      html = %(<a href="https://example.com/x">a</a><a href="/root">b</a><a href="#anchor">c</a>)
      result = HtmlFilters.make_links_relative(parse(html), "posts/page.html").to_html
      result.should contain %(href="https://example.com/x")
      result.should contain %(href="../root")
      result.should contain %(href="#anchor")
    end

    it "rewrites relative img src values" do
      doc = parse(%(<img src="../../pic.jpg">))
      result = HtmlFilters.make_links_relative(doc, "/posts/page.html").to_html
      result.should contain %(src="../pic.jpg")
    end

    it "rewrites links to markdown sources into rendered pages" do
      doc = parse(%(<a href="directory-layout.md">x</a>))
      result = HtmlFilters.make_links_relative(doc, "/books/user-guide/page.html").to_html
      result.should contain %(href="directory-layout.html")
    end

    it "preserves anchors when rewriting markdown links" do
      doc = parse(%(<a href="features.md#section-2">x</a>))
      result = HtmlFilters.make_links_relative(doc, "/books/user-guide/page.html").to_html
      result.should contain %(href="features.html#section-2")
    end

    it "rewrites nested and language-suffixed markdown links" do
      doc = parse(%(<a href="../cli/import.md">a</a><a href="intro.es.md">b</a>))
      result = HtmlFilters.make_links_relative(doc, "/books/user-guide/page.html").to_html
      result.should contain %(href="../cli/import.html")
      result.should contain %(href="intro.es.html")
    end

    it "leaves external .md URLs and non-markdown links alone" do
      html = %(<a href="https://example.com/raw.md">a</a><a href="/x.md">b</a><a href="y.txt">c</a>)
      result = HtmlFilters.make_links_relative(parse(html), "/books/user-guide/page.html").to_html
      result.should contain %(href="https://example.com/raw.md")
      result.should contain %(href="../../x.md")
      result.should contain %(href="y.txt")
    end
  end

  describe ".string_rewrite_safe?" do
    it "is true for plain html" do
      HtmlFilters.string_rewrite_safe?(%(<a href="x.html">x</a>)).should be_true
    end

    it "is false when hrefs appear inside scripts or comments" do
      HtmlFilters.string_rewrite_safe?(%(<script>var h = "href='x'";</script>)).should be_false
      HtmlFilters.string_rewrite_safe?(%(<!-- href="x" -->)).should be_false
    end

    it "is false for uppercase attribute spellings" do
      HtmlFilters.string_rewrite_safe?(%(<A HREF="x.html">x</A>)).should be_false
    end
  end

  describe ".relativize_links_in_string" do
    it "normalizes redundant path segments without parsing the document" do
      result = HtmlFilters.relativize_links_in_string(
        %(<a href="./other.html">x</a>), "/posts/sub/page.html"
      )
      result.should contain %(href="other.html")
    end

    it "keeps absolute URLs unchanged" do
      html = %(<a href="https://example.com/">x</a>)
      HtmlFilters.relativize_links_in_string(html, "page.html").should eq html
    end

    it "rewrites markdown links exactly like the DOM pass" do
      result = HtmlFilters.relativize_links_in_string(
        %(<a href="directory-layout.md">x</a><a href="features.md#anchor">y</a>),
        "/books/user-guide/page.html"
      )
      result.should contain %(href="directory-layout.html")
      result.should contain %(href="features.html#anchor")
    end
  end

  describe ".make_links_absolute" do
    it "makes page-relative and ../ links absolute" do
      doc = parse(%(<a href="other.html">a</a><a href="../../pic.jpg">b</a>))
      result = HtmlFilters.make_links_absolute(doc, "https://example.com/blog/posts/foo/index.html").to_html
      result.should contain %(href="https://example.com/blog/posts/foo/other.html")
      result.should contain %(href="https://example.com/blog/pic.jpg")
    end

    it "makes root-relative links absolute" do
      doc = parse(%(<img src="/images/a.png">))
      result = HtmlFilters.make_links_absolute(doc, "https://example.com/posts/page.html").to_html
      result.should contain %(src="https://example.com/images/a.png")
    end

    it "leaves absolute URLs and anchors alone" do
      html = %(<a href="https://other.com/x">a</a><a href="#anchor">b</a>)
      result = HtmlFilters.make_links_absolute(parse(html), "https://example.com/p.html").to_html
      result.should contain %(href="https://other.com/x")
      result.should contain %(href="#anchor")
    end

    it "leaves canonical links alone" do
      html = %(<link rel="canonical" href="/posts/page/">)
      result = HtmlFilters.make_links_absolute(parse(html), "https://example.com/posts/page.html").to_html
      result.should contain %(href="/posts/page/")
    end

    it "is idempotent" do
      html = %(<a href="other.html">x</a><img src="../pic.jpg">)
      once = HtmlFilters.make_links_absolute(parse(html), "https://example.com/posts/page.html").to_html
      twice = HtmlFilters.make_links_absolute(parse(once), "https://example.com/posts/page.html").to_html
      twice.should eq once
    end
  end

  describe ".absolutize_links_in_string" do
    it "rewrites relative links without parsing the document" do
      result = HtmlFilters.absolutize_links_in_string(
        %(<a href="other.html">x</a><img src="../../pic.jpg">),
        "https://example.com/blog/posts/foo/index.html"
      )
      result.should contain %(href="https://example.com/blog/posts/foo/other.html")
      result.should contain %(src="https://example.com/blog/pic.jpg")
    end

    it "rewrites root-relative links" do
      result = HtmlFilters.absolutize_links_in_string(
        %(<img src="/images/a.png">), "https://example.com/posts/page.html"
      )
      result.should contain %(src="https://example.com/images/a.png")
    end

    it "leaves absolute URLs, protocol-relative URLs and anchors unchanged" do
      html = %(<a href="https://other.com/x">a</a><a href="//cdn.com/y">b</a><a href="#anchor">c</a>)
      HtmlFilters.absolutize_links_in_string(html, "https://example.com/p.html").should eq html
    end

    it "converts .md links to .html like the page pass does" do
      result = HtmlFilters.absolutize_links_in_string(
        %(<a href="other.md">x</a>), "https://example.com/posts/page.html"
      )
      result.should contain %(href="https://example.com/posts/other.html")
    end

    it "is idempotent" do
      html = %(<a href="other.html">x</a><img src="/img.png">)
      once = HtmlFilters.absolutize_links_in_string(html, "https://example.com/posts/page.html")
      HtmlFilters.absolutize_links_in_string(once, "https://example.com/posts/page.html").should eq once
    end
  end

  describe ".md_link_to_html" do
    it "swaps the extension and keeps anchors" do
      HtmlFilters.md_link_to_html("foo.md").should eq "foo.html"
      HtmlFilters.md_link_to_html("foo.md#bar").should eq "foo.html#bar"
      HtmlFilters.md_link_to_html("../dir/foo.es.md").should eq "../dir/foo.es.html"
    end

    it "leaves everything that is not a .md link untouched" do
      HtmlFilters.md_link_to_html("foo.html").should eq "foo.html"
      HtmlFilters.md_link_to_html("https://example.com/x.md").should eq "https://example.com/x.md"
      HtmlFilters.md_link_to_html("notes.txt").should eq "notes.txt"
    end
  end
end
