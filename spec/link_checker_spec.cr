require "./spec_helper"

require "../src/link_checker"

private def glob_existing_files : Set(String)
  existing = Set(String).new
  Dir.glob("output/**/*").each do |path|
    next if File.directory?(path)
    existing << path
  end
  existing
end

describe LinkChecker do
  around_each do |example|
    tmp = Path["/tmp/opencode", "link-checker-spec-#{Random::Secure.hex(6)}"]
    FileUtils.mkdir_p(tmp / "output" / "css")
    FileUtils.mkdir_p(tmp / "output" / "js")
    FileUtils.mkdir_p(tmp / "output" / "posts")
    File.write(tmp / "output" / "index.html", "<html></html>")
    File.write(tmp / "output" / "css" / "theme.css", "body {}")
    File.write(tmp / "output" / "js" / "main.js", "")
    File.write(tmp / "output" / "posts" / "a-post.html", "<html></html>")
    Dir.cd(tmp) do
      example.run
    end
    FileUtils.rm_rf(tmp)
  end

  it "accepts absolute links with a cache-buster query" do
    File.write("output/index.html", %(<link rel="stylesheet" href="/css/theme.css?v=20261003-1">))
    results = LinkChecker.check_file("output/index.html", glob_existing_files)

    results.select(&.ok?).map(&.link).should contain("/css/theme.css?v=20261003-1")
    stripped_target = results.find { |result| result.link == "/css/theme.css?v=20261003-1" }.try(&.target)
    stripped_target.should eq "output/css/theme.css"
  end

  it "accepts relative links with a cache-buster query" do
    File.write("output/posts/a-post.html", %(<link rel="stylesheet" href="../css/theme.css?v=42">))
    results = LinkChecker.check_file("output/posts/a-post.html", glob_existing_files)

    results.select(&.ok?).map(&.link).should contain("../css/theme.css?v=42")
  end

  it "accepts script sources with a version query" do
    File.write("output/index.html", %(<script src="/js/main.js?v=7"></script>))
    results = LinkChecker.check_file("output/index.html", glob_existing_files)

    results.select(&.ok?).map(&.link).should contain("/js/main.js?v=7")
  end

  it "still accepts links carrying only a fragment" do
    File.write("output/index.html", %(<a href="/posts/a-post.html#section">post</a>))
    results = LinkChecker.check_file("output/index.html", glob_existing_files)

    results.select(&.ok?).map(&.link).should contain("/posts/a-post.html#section")
  end

  it "flags missing targets even when cache-busted" do
    File.write("output/index.html", %(<link rel="stylesheet" href="/css/missing.css?v=9">))
    results = LinkChecker.check_file("output/index.html", glob_existing_files)

    results.select(&.broken?).map(&.link).should contain("/css/missing.css?v=9")
  end

  it "flags missing targets without any query" do
    File.write("output/index.html", %(<a href="/nope.html">nowhere</a>))
    results = LinkChecker.check_file("output/index.html", glob_existing_files)

    results.select(&.broken?).map(&.link).should contain("/nope.html")
  end
end
