require "./spec_helper"

require "../src/lifecycle"
require "../src/markdown"

module LifecycleSite
  extend self

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

  def post(front_matter : String) : Markdown::File
    path = Path["content/posts", "x.md"]
    ::File.write(path, "---\ntitle: X\n#{front_matter}---\n\nbody")
    Markdown::File.new({"en" => path.to_s}, path)
  end
end

describe Lifecycle do
  around_each do |example|
    Lifecycle.include_drafts = false
    Lifecycle.include_future = false
    example.run
    Lifecycle.include_drafts = false
    Lifecycle.include_future = false
  end

  describe ".excluded?" do
    it "excludes drafts" do
      LifecycleSite.in_site do
        Lifecycle.excluded?(LifecycleSite.post("draft: true\n")).should eq "it's a draft"
      end
    end

    it "accepts truthy draft variants" do
      LifecycleSite.in_site do
        ["yes", "on", "1", "TRUE"].each do |value|
          excluded = Lifecycle.excluded?(LifecycleSite.post("draft: #{value}\n"))
          excluded.should eq "it's a draft"
        end
      end
    end

    it "keeps drafts when include_drafts is set" do
      Lifecycle.include_drafts = true
      LifecycleSite.in_site do
        Lifecycle.excluded?(LifecycleSite.post("draft: true\n")).should be_nil
      end
    end

    it "keeps regular posts" do
      LifecycleSite.in_site do
        Lifecycle.excluded?(LifecycleSite.post("")).should be_nil
      end
    end

    it "excludes future posts" do
      future = (Time.local + 10.days).to_s("%Y-%m-%d")
      LifecycleSite.in_site do
        Lifecycle.excluded?(LifecycleSite.post("date: #{future}\n"))
          .should eq "its date is in the future"
      end
    end

    it "keeps future posts when include_future is set" do
      Lifecycle.include_future = true
      future = (Time.local + 10.days).to_s("%Y-%m-%d")
      LifecycleSite.in_site do
        Lifecycle.excluded?(LifecycleSite.post("date: #{future}\n")).should be_nil
      end
    end

    it "keeps past posts" do
      past = (Time.local - 10.days).to_s("%Y-%m-%d")
      LifecycleSite.in_site do
        Lifecycle.excluded?(LifecycleSite.post("date: #{past}\n")).should be_nil
      end
    end

    it "excludes expired posts" do
      LifecycleSite.in_site do
        case reason = Lifecycle.excluded?(LifecycleSite.post("expires: 2020-01-01\n"))
        when String then reason.should contain "expired"
        else             fail("expected the post to be reported as expired")
        end
      end
    end

    it "keeps posts whose expiration is ahead" do
      LifecycleSite.in_site do
        Lifecycle.excluded?(LifecycleSite.post("expires: 2099-01-01\n")).should be_nil
      end
    end

    it "handles unparsable expiration dates gracefully" do
      LifecycleSite.in_site do
        Lifecycle.excluded?(LifecycleSite.post("expires: \n")).should be_nil
      end
    end
  end

  describe ".apply" do
    it "filters excluded posts out" do
      LifecycleSite.in_site do
        keep = LifecycleSite.post("date: 2024-01-01\n")
        draft = LifecycleSite.post("draft: true\n")
        Lifecycle.apply([keep, draft]).should eq [keep]
      end
    end
  end
end
