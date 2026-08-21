require "./spec_helper"

require "../src/markdown"

module PostSite
  extend self

  # Create a temp site with a content/posts directory and Config loaded
  def in_site(&)
    tmp = Path["/tmp/opencode", "spec-#{Random::Secure.hex(6)}"]
    FileUtils.mkdir_p(tmp / "content/posts")
    File.write(tmp / "conf.yml", "content: content/\noutput: output/\n")
    Dir.cd(tmp) do
      Config.reload
      yield tmp
    ensure
      FileUtils.rm_rf(tmp)
    end
  end

  def write_post(name : String, contents : String) : Markdown::File
    path = Path["content/posts", name]
    ::File.write(path, contents)
    Markdown::File.new({"en" => path.to_s}, path)
  end
end

describe Markdown::File do
  it "parses frontmatter metadata and title" do
    PostSite.in_site do
      post = PostSite.write_post("hello.md", <<-MD)
        ---
        title: Hello World
        date: 2024-05-01
        ---

        Some *markdown* text.
        MD

      post.title.should eq "Hello World"
      post.metadata.has_key?("title").should be_true
      post.date.try(&.to_s("%Y-%m-%d")).should eq "2024-05-01"
      post.text.strip.should eq "Some *markdown* text."
    end
  end

  it "treats files without frontmatter as pure content" do
    PostSite.in_site do
      post = PostSite.write_post("plain.md", "# Just a heading\n\nBody.\n")

      post.title.should eq ""
      post.metadata.should be_empty
      post.text.should contain "Just a heading"
    end
  end

  it "renders markdown to HTML" do
    PostSite.in_site do
      post = PostSite.write_post("render.md", "---\ntitle: Rendered\n---\n\nHello **world**\n")
      post.html.should contain "<strong>world</strong>"
    end
  end

  it "downgrades markdown headers in rendered HTML" do
    PostSite.in_site do
      post = PostSite.write_post("headers.md", "---\ntitle: Headers\n---\n\n# Big Title\n")
      post.html.should_not match(/<h1>/)
    end
  end

  it "builds the output path with .html extension" do
    PostSite.in_site do
      post = PostSite.write_post("out.md", "---\ntitle: Out\n---\n\nBody\n")
      post.output.should eq "output/posts/out.md.html"
    end
  end

  it "sorts posts date-descending" do
    PostSite.in_site do
      older = PostSite.write_post("older.md", "---\ntitle: Older\ndate: 2020-01-01\n---\n\nA\n")
      newer = PostSite.write_post("newer.md", "---\ntitle: Newer\ndate: 2024-01-01\n---\n\nB\n")
      (newer <=> older).should eq(-1)
    end
  end

  it "returns nil date when metadata has no date" do
    PostSite.in_site do
      post = PostSite.write_post("nodate.md", "---\ntitle: No Date\n---\n\nX\n")
      post.date.should be_nil
    end
  end

  it "parses taxonomy terms from metadata" do
    PostSite.in_site do
      post = PostSite.write_post("tagged.md", "---\ntitle: Tagged\ntags: alpha, beta\n---\n\nX\n")
      post.taxonomy_terms["tags"].sort.should eq ["alpha", "beta"]
    end
  end
end
