require "./markdown"
require "./toc"
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
      ext = Path[source].extension
      format = Config.options.pandoc_formats[ext]
      result = compile(replace_shortcodes(lang), format)
      doc = Lexbor::Parser.new(result)
      doc = HtmlFilters.downgrade_headers(doc)
      doc = HtmlFilters.remove_empty_paragraphs(doc)
      doc = HtmlFilters.make_links_relative(doc, link)
      html_with_classes = HtmlFilters.fix_code_classes(doc).to_html

      # Extract TOC and add anchors to headings
      @html[lang], @toc[lang] = Toc.extract_and_annotate(html_with_classes)
      @html[lang]
    end

    # Use a memoized compile method because pandoc is so slow
    @cache_compile = {} of {String, String} => String

    def compile(input, format = "rst")
      @cache_compile[{input, format}] ||= _compile(input, format)
    end

    def _compile(input, format = "rst")
      # Check if this is a raw HTML reStructuredText file
      # These files start with ".. raw:: html" after the front matter
      stripped = input.strip
      if stripped.starts_with?(".. raw:: html")
        extract_raw_html(input)
      else
        compile_with_pandoc(input, format)
      end
    end

    # Extract HTML from reStructuredText raw::html directive
    private def extract_raw_html(input)
      lines = input.lines
      html_lines = [] of String
      in_html = false
      started_collecting = false

      lines.each do |line|
        if line.strip == ".. raw:: html"
          in_html = true
          next
        end

        next unless in_html

        # Skip blank lines before HTML starts
        next if line.strip.empty? && !started_collecting

        # Stop if we hit a deindent (end of raw block)
        if started_collecting && !line.starts_with?(" ") && !line.strip.empty?
          break
        end

        started_collecting = true
        # Remove the indentation (4 spaces is standard for rst directives)
        if line.starts_with?("    ")
          html_lines << line[4..]
        else
          html_lines << line
        end
      end

      html_lines.join("\n")
    end

    # Compile using pandoc for normal rst files
    private def compile_with_pandoc(input, format)
      input_io = IO::Memory.new(input)
      output = IO::Memory.new
      Process.run("pandoc",
        args: ["-f", format, "-t", "html"],
        input: input_io,
        output: output)
      output.to_s
    end
  end

  # Parse all pandoc posts in a path and build Pandoc::File
  # objects out of them
  def self.read_all(path)
    Log.debug { "Reading pandoc files from #{path}" }
    posts = [] of File
    Config.options.pandoc_formats.keys.each do |ext|
      all_sources = Utils.find_all(path, ext[1..])
      all_sources.map do |base, sources|
        begin
          next if Markdown.posts.keys.includes? base.to_s
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
