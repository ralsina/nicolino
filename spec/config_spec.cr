require "./spec_helper"

module SpecSite
  extend self

  # Create a temporary directory chdir'ed for the duration of the block,
  # with an optional conf.yml written into it.
  def in_site(conf : String? = nil, &)
    tmp = Path["/tmp/opencode", "spec-#{Random::Secure.hex(6)}"]
    FileUtils.mkdir_p(tmp)
    File.write(tmp / "conf.yml", conf) unless conf.nil?
    begin
      Dir.cd(tmp) do
        # Config keeps global caches; reset them so examples are isolated
        Config.reload if File.exists?(tmp / "conf.yml")
        yield tmp
      end
    ensure
      FileUtils.rm_rf(tmp)
    end
  end
end

describe Config do
  around_each do |example|
    # Isolate each example from the repo's own conf.yml and from
    # state leaked by previous examples.
    SpecSite.in_site { example.run }
  end

  describe ".config" do
    it "raises ConfigError when no configuration file exists" do
      expect_raises(Config::ConfigError, /nicolino init/) do
        Config.config("conf.yml")
      end
    end

    it "loads defaults from an empty configuration" do
      SpecSite.in_site("") do
        Config.config
        Config.title.should eq "Nicolino"
        Config.output.should eq "output/"
        Config.content.should eq "content/"
        Config.language.should eq "en"
        Config.default_lang.should eq "en"
      end
    end

    it "reads values from the configuration file" do
      SpecSite.in_site(<<-YAML) do
        title: My Site
        output: public/
        language: es
        features: [posts]
        YAML
        Config.config
        Config.title.should eq "My Site"
        Config.output.should eq "public/"
        Config.default_lang.should eq "es"
      end
    end

    it "applies default features when none are configured" do
      SpecSite.in_site("") do
        Config.config
        Config.features.should contain "posts"
        Config.features.should contain "sitemap"
      end
    end

    it "keeps explicitly configured features" do
      SpecSite.in_site("features: [assets]\n") do
        Config.config
        Config.features.should eq ["assets"]
      end
    end

    it "provides a default tags taxonomy when none is configured" do
      SpecSite.in_site("") do
        Config.config
        Config.taxonomies.has_key?("tags").should be_true
        Config.taxonomies["tags"].location.should eq "tags/"
      end
    end
  end

  describe ".[]" do
    it "returns the default language config" do
      SpecSite.in_site("title: Hola\nlanguage: es\n") do
        Config.config
        Config["es"].title.should eq "Hola"
      end
    end

    it "falls back to the default language config without override file" do
      SpecSite.in_site("title: Hola\n") do
        Config.config
        Config["fr"].title.should eq "Hola"
      end
    end

    it "merges language overrides from conf.LANG.yml" do
      SpecSite.in_site("title: Hola\n") do
        File.write("conf.fr.yml", "title: Bonjour\n")
        Config.config
        Config["fr"].title.should eq "Bonjour"
        # Non-overridden fields keep the base values
        Config["fr"].description.should eq "A Nicolino Site"
      end
    end
  end

  describe ".languages" do
    it "detects languages from conf.LANG.yml files" do
      SpecSite.in_site("title: Hola\n") do
        File.write("conf.es.yml", "title: Hola ES\n")
        File.write("conf.pt.yml", "title: Olá\n")
        Config.config
        Config.languages.sort.should eq ["en", "es", "pt"].sort
      end
    end
  end

  describe ".reload" do
    it "picks up changes to the configuration file" do
      SpecSite.in_site("title: Before\n") do
        Config.config
        Config.title.should eq "Before"
        File.write("conf.yml", "title: After\n")
        Config.reload
        Config.title.should eq "After"
      end
    end
  end
end
