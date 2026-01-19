require "./markdown"
require "lexbor"

module Pandoc
  # Enable pandoc feature and check if installed
  def self.enable(is_enabled : Bool)
    return unless is_enabled

    return unless Process.find_executable("pandoc").nil?
    Log.error { "The 'pandoc' feature is enabled but pandoc is not installed or not in PATH" }
    Log.error { "Please install pandoc or disable the 'pandoc' feature in conf.yml" }
    exit 1
  end

  # A file written in markdown
  class File < Markdown::File
    def html(lang = nil)
      lang ||= Locale.language
      # FIXME: Figure out how to extract TOC
      ext = Path[source].extension
      format = Config.options.formats[ext]
      result, toc_content = compile(
        replace_shortcodes(lang),
        metadata(lang).fetch("toc", nil) != nil,
        format: format)
      doc = Lexbor::Parser.new(result)
      doc = HtmlFilters.downgrade_headers(doc)
      doc = HtmlFilters.make_links_relative(doc, link)
      @html[lang] = HtmlFilters.fix_code_classes(doc).to_html
      @toc[lang] = toc_content
    end

    # Use a memoized compile method because pandoc is so slow
    @cache_compile = {} of {String, Bool, String} => Array(String)

    def compile(input, toc = false, format = "rst")
      @cache_compile[{input, toc, format}] ||= _compile(input, toc, format)
    end

    def _compile(input, toc = false, format = "rst")
      input = IO::Memory.new(input)
      output = IO::Memory.new
      Process.run("pandoc",
        args: ["-f", format, "-t", "html"],
        input: input,
        output: output)
      [output.to_s, ""]
    end
  end

  # Parse all pandoc posts in a path and build Pandoc::File
  # objects out of them
  def self.read_all(path)
    Log.debug { "Reading pandoc files from #{path}" }
    posts = [] of File
    Config.options.formats.keys.each do |ext|
      all_sources = Utils.find_all(path, ext[1..])
      all_sources.map do |base, sources|
        begin
          next if File.posts.keys.includes? base.to_s
          next if Utils.should_skip_file?(base)

          posts << File.new(sources, base)
        rescue ex
          Log.error { "Error parsing #{base}: #{ex.message}" }
          Log.debug { ex }
          raise ex
        end
      end
    end
    posts
  end
end
