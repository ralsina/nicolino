require "./spec_helper"

require "../src/utils"

describe Utils do
  around_each do |example|
    tmp = Path["/tmp/opencode", "spec-#{Random::Secure.hex(6)}"]
    FileUtils.mkdir_p(tmp)
    File.write(tmp / "conf.yml", "content: content/\noutput: output/\n")
    Dir.cd(tmp) do
      Config.reload
      begin
        example.run
      ensure
        FileUtils.rm_rf(tmp)
      end
    end
  end

  describe ".slugify" do
    it "downcases and hyphenates" do
      Utils.slugify("Hello World!").should eq "hello-world-"
    end

    it "collapses repeated separators" do
      Utils.slugify("a  --  b").should eq "a-b"
    end
  end

  describe ".titlecase" do
    it "capitalizes words split on spaces, dashes and underscores" do
      Utils.titlecase("hello world-foo_bar").should eq "Hello World Foo Bar"
    end
  end

  describe ".path_to_link" do
    it "strips the output directory prefix" do
      Utils.path_to_link("output/posts/foo.html").should eq "/posts/foo.html"
    end

    it "replaces the extension when asked" do
      Utils.path_to_link("output/posts/foo.html", ".xml").should eq "/posts/foo.xml"
    end

    it "raises for paths outside the output directory" do
      expect_raises(Exception, /must start with/) do
        Utils.path_to_link("elsewhere/foo.html")
      end
    end
  end

  describe ".lang_suffix" do
    it "is empty for the default language" do
      Utils.lang_suffix("en").should eq ""
    end

    it "adds a dotted suffix for other languages" do
      Utils.lang_suffix("es").should eq ".es"
    end
  end

  describe ".output_prefix" do
    it "returns the output directory with a trailing slash" do
      Utils.output_prefix.should eq "output/"
    end
  end

  describe ".content_globs" do
    it "globs markdown and html plus configured pandoc formats" do
      globs = Utils.content_globs(Path["content"])
      globs.should contain "content/**/*.md"
      globs.should contain "content/**/*.html"
    end
  end

  describe ".find_all" do
    it "groups language variants of a post under one base" do
      FileUtils.mkdir_p("content/posts")
      File.write("conf.es.yml", "title: ES\n")
      Config.reload
      File.write("content/posts/story.md", "---\ntitle: Base\n---\n\nBase\n")
      File.write("content/posts/story.es.md", "---\ntitle: Base ES\n---\n\nES\n")

      all_sources = Utils.find_all("content/posts", "md")
      all_sources.size.should eq 1

      sources = all_sources[Path["content/posts/story"]]
      sources["en"].should eq "content/posts/story.md"
      sources["es"].should eq "content/posts/story.es.md"
    end

    it "falls back to the default-language file for missing translations" do
      FileUtils.mkdir_p("content/posts")
      File.write("conf.es.yml", "title: ES\n")
      Config.reload
      File.write("content/posts/solo.md", "---\ntitle: Solo\n---\n\nX\n")

      sources = Utils.find_all("content/posts", "md")[Path["content/posts/solo"]]
      sources["en"].should eq "content/posts/solo.md"
      sources["es"].should eq "content/posts/solo.md"
    end
  end

  describe ".text_excerpt" do
    it "strips tags and collapses whitespace" do
      Utils.text_excerpt("<p>Hello   <b>world</b></p>\n\n<p>again</p>").should eq "Hello world again"
    end

    it "returns empty string for empty input" do
      Utils.text_excerpt("").should eq ""
      Utils.text_excerpt("   ").should eq ""
    end

    it "truncates long text at a word boundary with an ellipsis" do
      excerpt = Utils.text_excerpt("word " * 100, limit: 50)
      excerpt.size.should be <= 51
      excerpt.should end_with "…"
      excerpt.should_not end_with " …"
    end

    it "keeps short text intact" do
      Utils.text_excerpt("short and sweet", limit: 50).should eq "short and sweet"
    end
  end
end
