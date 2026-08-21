require "./spec_helper"

require "../src/sc"

describe Sc do
  describe ".shortcodes_in" do
    it "returns an empty list for text without shortcodes" do
      Sc.shortcodes_in("plain text, no delimiters").should be_empty
    end

    it "finds inline shortcodes (names ending in .inline)" do
      found = Sc.shortcodes_in("before {{% echo.inline arg %}} after")
      found.size.should eq 1
      found.first.name.should eq "echo.inline"
      found.first.is_inline?.should be_true
    end

    it "finds block shortcodes with bodies" do
      found = Sc.shortcodes_in("{{% note %}}body text{{% /note %}}")
      found.size.should eq 1
      found.first.name.should eq "note"
    end
  end

  describe ".kv_deps_for_file" do
    it "maps non-inline shortcodes to their template kv paths" do
      tmp = Path["/tmp/opencode", "spec-#{Random::Secure.hex(6)}"]
      FileUtils.mkdir_p(tmp)
      path = tmp / "post.md"
      File.write(path, "{{% note %}}body{{% /note %}}")
      Sc.kv_deps_for_file(path.to_s).should eq ["kv://shortcodes/note.tmpl"]
      FileUtils.rm_rf(tmp)
    end

    it "ignores inline shortcodes (they need no template)" do
      tmp = Path["/tmp/opencode", "spec-#{Random::Secure.hex(6)}"]
      FileUtils.mkdir_p(tmp)
      path = tmp / "post.md"
      File.write(path, "{{#echo.inline hi}}")
      Sc.kv_deps_for_file(path.to_s).should be_empty
      FileUtils.rm_rf(tmp)
    end

    it "returns an empty list for missing files" do
      Sc.kv_deps_for_file("/tmp/opencode/does-not-exist.md").should be_empty
    end
  end

  describe ".available_shortcodes" do
    it "lists shortcode template names from the shortcodes directory" do
      tmp = Path["/tmp/opencode", "spec-#{Random::Secure.hex(6)}"]
      FileUtils.mkdir_p(tmp / "shortcodes")
      File.write(tmp / "shortcodes/zeta.tmpl", "")
      File.write(tmp / "shortcodes/alpha.tmpl", "")
      begin
        Dir.cd(tmp) { Sc.available_shortcodes.should eq ["alpha", "zeta"] }
      ensure
        FileUtils.rm_rf(tmp)
      end
    end
  end
end
