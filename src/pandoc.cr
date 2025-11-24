require "./markdown"

module Pandoc
  # A file written in markdown
  class File < Markdown::File
    def html(lang = nil)
      lang ||= Locale.language
      # FIXME: Figure out how to extract TOC
      ext = Path[source].extension
      format = Config.options.formats[ext]
      @html[lang], @toc[lang] = compile(
        replace_shortcodes(lang),
        metadata(lang).fetch("toc", nil) != nil,
        format: format)
      @html[lang] = HtmlFilters.downgrade_headers(html(lang))
      @html[lang] = HtmlFilters.make_links_relative(html(lang), link)
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
