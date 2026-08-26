require "./spec_helper"

require "../src/config"
require "../src/highlight"

describe Highlight do
  describe ".html" do
    it "highlights a fenced code block with a known language" do
      html = %(<pre><code class="crystal">def foo\n  1 # c\nend\n</code></pre>)
      result = Highlight.html(html)
      result.should contain %(<pre class="highlight"><code class="tz-b")
      result.should contain %(<span class="tz-nk">def</span>)
      result.should contain "foo"
    end

    it "leaves blocks with unknown languages untouched" do
      html = %(<pre><code class="nosuchlang123">x &lt; y\n</code></pre>)
      result = Highlight.html(html)
      result.should eq(html)
    end

    it "unescapes the source before highlighting" do
      html = %(<pre><code class="crystal">a &lt; b &amp;&amp; c &gt; d\n</code></pre>)
      result = Highlight.html(html)
      result.should_not contain "&amp;amp;"
    end

    it "returns the input unchanged when disabled" do
      html = %(<pre><code class="crystal">x\n</code></pre>)
      Highlight.html(html).should contain "tz-"
    end
  end

  describe ".css" do
    it "emits dark and light scoped rules" do
      css = Highlight.css
      css.should contain "[data-theme=\"dark\"]"
      css.should contain "[data-theme=\"light\"]"
      css.should contain ".tz-"
    end

    it "drops the background-color from the Background rule" do
      css = Highlight.css
      css.should_not match(/\.tz-b[^}]*background-color/)
    end
  end
end
